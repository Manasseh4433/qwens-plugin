# encoding: UTF-8
# SeamMatcher — разметка камней в полосе через x-координаты (без зазоров гарантировано)
# Версия 3: работает с x-позициями, не с индексами узлов

module PolygonalMasonry
  class SeamMatcher
    # CellSpec описывает один камень через x-координаты границ.
    # Индексы top/bot нужны только для доступа к промежуточным узлам кривой.
    CellSpec = Struct.new(:x_left, :x_right,
                          :top_from, :top_to,
                          :bot_from, :bot_to,
                          :kind)

    def initialize(params, rng)
      @params = params
      @rng    = rng
    end

    # top_nodes, bot_nodes — массивы Node (Struct с полями x, y)
    # Возвращает Array[CellSpec] с гарантией:
    #   specs[i].x_right == specs[i+1].x_left  (нет зазоров)
    def match(top_nodes, bot_nodes)
      # ШАГ 1: строим единую сетку x-позиций всех внутренних швов полосы
      # Включаем все x из обоих рядов
      top_xs = top_nodes.map(&:x)
      bot_xs = bot_nodes.map(&:x)
      xmin = [top_xs.first, bot_xs.first].min
      xmax = [top_xs.last,  bot_xs.last ].max

      # Все внутренние x (без крайних — они общие у обоих)
      all_inner = (top_xs[1..-2] + bot_xs[1..-2]).uniq.sort
      all_xs = ([xmin] + all_inner + [xmax]).uniq.sort

      # ШАГ 2: строим атомарные сегменты (один сегмент = один базовый камень)
      atomic = []
      all_xs.each_cons(2) do |x_l, x_r|
        next if (x_r - x_l) < (@params[:min_stone_width] || 0) * 0.3
        ti_l = nearest_idx(top_nodes, x_l)
        ti_r = nearest_idx(top_nodes, x_r)
        bi_l = nearest_idx(bot_nodes, x_l)
        bi_r = nearest_idx(bot_nodes, x_r)
        atomic << CellSpec.new(x_l, x_r, ti_l, ti_r, bi_l, bi_r, :normal)
      end

      return atomic if atomic.empty?

      # ШАГ 3: вероятностное объединение соседних атомарных сегментов
      merge_segments(atomic, top_nodes, bot_nodes)
    end

    private

    # Объединяет соседние сегменты с вероятностью p_merge.
    # ГАРАНТИЯ: x_right одного = x_left следующего (т.к. мы берём x_right
    # из объединённого сегмента напрямую).
    def merge_segments(atomic, top_nodes, bot_nodes)
      result = []
      i = 0
      while i < atomic.size
        spec = atomic[i]
        can_merge = i + 1 < atomic.size
        # Не объединять если результат будет слишком широким
        if can_merge
          next_spec = atomic[i + 1]
          merged_w  = next_spec.x_right - spec.x_left
          max_w = (@params[:stone_width_mean] || 10) * 2.2
          can_merge = merged_w <= max_w
        end

        if can_merge && @rng.rand < (@params[:one_to_two_prob] || 0.20)
          next_spec = atomic[i + 1]
          # Объединяем: x_left от текущего, x_right от следующего
          merged = CellSpec.new(
            spec.x_left,           next_spec.x_right,
            spec.top_from,         next_spec.top_to,
            spec.bot_from,         next_spec.bot_to,
            :normal
          )
          result << merged
          i += 2
        else
          result << spec
          i += 1
        end
      end
      result
    end

    def nearest_idx(nodes, x)
      best_i = 0
      best_d = (nodes[0].x - x).abs
      nodes.each_with_index do |n, idx|
        d = (n.x - x).abs
        if d < best_d; best_d = d; best_i = idx; end
      end
      best_i
    end
  end
end
