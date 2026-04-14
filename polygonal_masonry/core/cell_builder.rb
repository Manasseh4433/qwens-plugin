# encoding: UTF-8
# Построение полигонов камней из спецификаций

module PolygonalMasonry
  StoneCell = Struct.new(:points2d, :kind, :band, :top_range, :bottom_range)

  class CellBuilder
    def initialize(rows, row_nodes, params, rng)
      @rows = rows
      @row_nodes = row_nodes
      @params = params
      @rng = rng
    end

    def build_cells(band_idx, cell_specs)
      top_row = @rows[band_idx]
      bot_row = @rows[band_idx + 1]
      top_nodes = @row_nodes[band_idx]
      bot_nodes = @row_nodes[band_idx + 1]

      cell_specs.map do |spec|
        build_cell(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      end.compact
    end

    private

    def build_cell(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      case spec.kind
      when :one_to_one
        build_one_to_one(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      when :one_to_two
        build_one_to_two(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      when :two_to_one
        build_two_to_one(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      else
        nil
      end
    end

    def build_one_to_one(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      ti, tj = spec.top_range.begin, spec.top_range.end
      bi, bj = spec.bottom_range.begin, spec.bottom_range.end

      p_tl = top_row_sample(top_row, top_nodes[ti].x)
      p_tr = top_row_sample(top_row, top_nodes[tj].x)
      p_bl = bot_row_sample(bot_row, bot_nodes[bi].x)
      p_br = bot_row_sample(bot_row, bot_nodes[bj].x)

      return nil unless p_tl && p_tr && p_bl && p_br

      # Боковые изломы
      left_mid  = side_kink(p_tl, p_bl)
      right_mid = side_kink(p_tr, p_br)

      points = [p_tl, p_tr, right_mid, p_br, p_bl, left_mid]

      StoneCell.new(points, :normal, band_idx, spec.top_range, spec.bottom_range)
    end

    def build_one_to_two(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      ti, tj = spec.top_range.begin, spec.top_range.end
      bi, bk = spec.bottom_range.begin, spec.bottom_range.end
      bj = bi + 1

      p_tl = top_row_sample(top_row, top_nodes[ti].x)
      p_tr = top_row_sample(top_row, top_nodes[tj].x)
      p_bl = bot_row_sample(bot_row, bot_nodes[bi].x)
      p_bm = bot_row_sample(bot_row, bot_nodes[bj].x)
      p_br = bot_row_sample(bot_row, bot_nodes[bk].x)

      return nil unless p_tl && p_tr && p_bl && p_bm && p_br

      left_mid  = side_kink(p_tl, p_bl)
      right_mid = side_kink(p_tr, p_br)

      # 7 точек: верх 2, право 2, низ 3
      points = [p_tl, p_tr, right_mid, p_br, p_bm, p_bl, left_mid]

      StoneCell.new(points, :key, band_idx, spec.top_range, spec.bottom_range)
    end

    def build_two_to_one(top_row, bot_row, top_nodes, bot_nodes, spec, band_idx)
      ti, tk = spec.top_range.begin, spec.top_range.end
      tj = ti + 1
      bi, bj = spec.bottom_range.begin, spec.bottom_range.end

      p_tl = top_row_sample(top_row, top_nodes[ti].x)
      p_tm = top_row_sample(top_row, top_nodes[tj].x)
      p_tr = top_row_sample(top_row, top_nodes[tk].x)
      p_bl = bot_row_sample(bot_row, bot_nodes[bi].x)
      p_br = bot_row_sample(bot_row, bot_nodes[bj].x)

      return nil unless p_tl && p_tm && p_tr && p_bl && p_br

      left_mid  = side_kink(p_tl, p_bl)
      right_mid = side_kink(p_tr, p_br)

      # 7 точек: верх 3, право 2, низ 2
      points = [p_tl, p_tm, p_tr, right_mid, p_br, p_bl, left_mid]

      StoneCell.new(points, :key, band_idx, spec.top_range, spec.bottom_range)
    end

    # Найти точку на кривой для заданного x
    def top_row_sample(row, x)
      row.each_cons(2) do |p1, p2|
        if (x >= p1[0] && x <= p2[0]) || (x >= p2[0] && x <= p1[0])
          dx = p2[0] - p1[0]
          return p1 if dx.abs < 1e-10
          t = (x - p1[0]).to_f / dx
          return [x, p1[1] + t * (p2[1] - p1[1])]
        end
      end
      row.find { |p| (p[0] - x).abs < 0.1 }
    end

    def bot_row_sample(row, x)
      top_row_sample(row, x)
    end

    # Боковой излом
    def side_kink(top_pt, bot_pt)
      mid_x = (top_pt[0] + bot_pt[0]) / 2.0
      mid_y = (top_pt[1] + bot_pt[1]) / 2.0
      jitter = @params[:seam_jitter]

      mid_x += (@rng.rand * 2 - 1) * jitter * 0.5
      mid_y += (@rng.rand * 2 - 1) * jitter * 0.3

      [mid_x, mid_y]
    end
  end
end
