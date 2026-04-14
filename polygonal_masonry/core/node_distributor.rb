# encoding: UTF-8
# Распределение вертикальных швов (узлов) по рядам

module PolygonalMasonry
  class NodeDistributor
    Node = Struct.new(:x, :y)

    def initialize(rows, bbox2d, params, rng)
      @rows   = rows
      @bbox   = bbox2d
      @params = params
      @rng    = rng
    end

    # Возвращает Array[Array[Node]] — для каждой кривой массив узлов по x
    def distribute
      @rows.map.with_index do |curve, idx|
        distribute_on_curve(curve, idx)
      end
    end

    private

    def distribute_on_curve(curve, row_idx)
      xmin = @bbox[:xmin]
      xmax = @bbox[:xmax]
      mean = @params[:stone_width_mean]
      jitter = @params[:stone_width_jitter]
      min_w  = @params[:min_stone_width] || mean * 0.35

      nodes = []

      # Крайний левый узел всегда на xmin
      nodes << Node.new(xmin, curve.y_at(xmin))

      # Смещение фазы для разбежки швов в соседних рядах
      # Чётные ряды начинают с xmin, нечётные — со смещением ~полкамня
      phase_offset = row_idx.odd? ? (mean * 0.5 + (@rng.rand - 0.5) * mean * 0.2) : 0.0

      x = xmin + phase_offset
      # Первый шов — после phase_offset, но только если достаточно места
      if x > xmin + min_w && x < xmax - min_w
        nodes << Node.new(x, curve.y_at(x))
      end

      # Основной цикл расстановки швов
      last_x = nodes.last.x
      loop do
        step = mean + (@rng.rand * 2 - 1) * jitter
        step = [min_w, step].max
        next_x = last_x + step

        # Не добавляем узел слишком близко к правому краю — финальный зазор до xmax
        break if next_x >= xmax - min_w * 0.8

        nodes << Node.new(next_x, curve.y_at(next_x))
        last_x = next_x
      end

      # Крайний правый узел всегда на xmax
      nodes << Node.new(xmax, curve.y_at(xmax))

      nodes
    end
  end
end
