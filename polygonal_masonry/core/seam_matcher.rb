# encoding: UTF-8
# Монотонное сопоставление узлов соседних рядов

module PolygonalMasonry
  # CellSpec описывает камень: диапазон top-узлов и bottom-узлов
  CellSpec = Struct.new(:top_range, :bottom_range, :kind)

  class SeamMatcher
    def initialize(row_nodes, params, rng)
      @row_nodes = row_nodes  # [row_idx] -> [Node, ...]
      @params = params
      @rng = rng
    end

    def match_all
      # [band_idx] -> [CellSpec, ...]
      bands = []

      (0...(@row_nodes.length - 1)).each do |k|
        top_nodes = @row_nodes[k]
        bot_nodes = @row_nodes[k + 1]

        specs = match_band(top_nodes, bot_nodes)
        bands << specs
      end

      bands
    end

    private

    def match_band(top_nodes, bot_nodes)
      cells = []
      ti = 0  # индекс в top
      bi = 0  # индекс в bottom

      while ti < top_nodes.length - 1 && bi < bot_nodes.length - 1
        top_right = top_nodes[ti + 1].x
        bot_right = bot_nodes[bi + 1].x
        top_left = top_nodes[ti].x
        bot_left = bot_nodes[bi].x

        top_span = top_right - top_left
        bot_span = bot_right - bot_left

        # Выбор режима
        roll = @rng.rand
        if roll < @params[:one_to_one_prob]
          # one_to_one: 1 top интервал <-> 1 bot интервал
          cells << CellSpec.new(ti..(ti+1), bi..(bi+1), :one_to_one)
          ti += 1
          bi += 1
        elsif roll < @params[:one_to_one_prob] + @params[:one_to_two_prob]
          # one_to_two: 1 top -> 2 bot (top шире)
          if bi + 2 < bot_nodes.length
            cells << CellSpec.new(ti..(ti+1), bi..(bi+2), :one_to_two)
            ti += 1
            bi += 2
          else
            cells << CellSpec.new(ti..(ti+1), bi..(bi+1), :one_to_one)
            ti += 1
            bi += 1
          end
        else
          # two_to_one: 2 top -> 1 bot
          if ti + 2 < top_nodes.length
            cells << CellSpec.new(ti..(ti+2), bi..(bi+1), :two_to_one)
            ti += 2
            bi += 1
          else
            cells << CellSpec.new(ti..(ti+1), bi..(bi+1), :one_to_one)
            ti += 1
            bi += 1
          end
        end
      end

      # Добить оставшиеся
      while ti < top_nodes.length - 1
        cells << CellSpec.new(ti..(ti+1), [bi, bot_nodes.length-2].clamp(0, bot_nodes.length-2)..(bot_nodes.length-1), :one_to_one)
        ti += 1
      end
      while bi < bot_nodes.length - 1
        cells << CellSpec.new([ti, top_nodes.length-2].clamp(0, top_nodes.length-2)..(top_nodes.length-1), bi..(bi+1), :one_to_one)
        bi += 1
      end

      cells
    end
  end
end
