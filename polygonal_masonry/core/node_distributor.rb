# encoding: UTF-8
# Расстановка узлов на кривых рядов

module PolygonalMasonry
  Node = Struct.new(:x, :y)

  class NodeDistributor
    def initialize(rows, bbox, params, rng)
      @rows = rows
      @bbox = bbox
      @params = params
      @rng = rng
    end

    def distribute
      # [row_idx] -> [Node, ...]
      all_nodes = []

      @rows.each_with_index do |row_samples, idx|
        # Фаза сдвига: чередование рядов для перевязки
        phase_shift = (idx % 2) * @params[:stone_width_mean] * 0.5

        nodes = distribute_on_row(row_samples, phase_shift)
        all_nodes << nodes
      end

      all_nodes
    end

    private

    def distribute_on_row(samples, phase_shift)
      nodes = []
      xmin = @bbox[:xmin]
      xmax = @bbox[:xmax]

      x = xmin
      started = false

      while x < xmax - @params[:min_edge]
        # Ширина камня с джиттером
        jitter = (@rng.rand * 2 - 1) * @params[:stone_width_jitter]
        width = @params[:stone_width_mean] + jitter
        width = [@params[:min_edge], width].max

        x += width + phase_shift * 0.01  # малый дополнительный сдвиг

        break if x > xmax

        # Найти y на кривой для данного x
        y = interpolate_y(samples, x)
        next unless y

        nodes << Node.new(x, y)
      end

      # Всегда добавляем конечную точку
      unless nodes.any? { |n| (n.x - xmax).abs < @params[:min_edge] }
        last_y = interpolate_y(samples, xmax)
        nodes << Node.new(xmax, last_y || @bbox[:ymin])
      end

      nodes
    end

    def interpolate_y(samples, x)
      return nil if samples.empty?
      samples.each_cons(2) do |p1, p2|
        if (x >= p1[0] && x <= p2[0]) || (x >= p2[0] && x <= p1[0])
          dx = p2[0] - p1[0]
          return p1[1] if dx.abs < 1e-10
          t = (x - p1[0]).to_f / dx
          return p1[1] + t * (p2[1] - p1[1])
        end
      end
      nil
    end
  end
end
