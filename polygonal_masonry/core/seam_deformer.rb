# encoding: UTF-8
# Деформация швов: замковые зубья

module PolygonalMasonry
  class SeamDeformer
    def initialize(all_cells_by_band, params, rng)
      @bands = all_cells_by_band  # [band_idx] -> [StoneCell, ...]
      @params = params
      @rng = rng
    end

    def deform_all
      @bands.each_with_index do |cells, band_idx|
        # Найти вертикальные швы между соседними камнями
        (0...cells.length - 1).each do |ci|
          next unless @rng.rand < @params[:key_stone_ratio]
          deform_between_cells(cells[ci], cells[ci + 1])
        end
      end

      @bands.flatten
    end

    private

    def deform_between_cells(cell_a, cell_b)
      # Найти общую границу (приближённо — по координатам)
      # Для MVP: модифицируем "правую" границу A и "левую" B

      # Правая граница A: ищем точку с максимальным x
      right_idx_a = find_rightmost_point_index(cell_a.points2d)
      left_idx_b = find_leftmost_point_index(cell_b.points2d)

      return unless right_idx_a && left_idx_b

      # Найти соседние точки сверху и снизу
      pts_a = cell_a.points2d
      pts_b = cell_b.points2d
      n_a = pts_a.length
      n_b = pts_b.length

      top_a = pts_a[(right_idx_a - 1 + n_a) % n_a]
      bot_a = pts_a[(right_idx_a + 1) % n_a]
      top_b = pts_b[(left_idx_b - 1 + n_b) % n_b]
      bot_b = pts_b[(left_idx_b + 1) % n_b]

      mid_a = pts_a[right_idx_a]
      mid_b = pts_b[left_idx_b]

      # Проверить corridor (расстояние до соседних швов)
      corridor = estimate_corridor(pts_a, right_idx_a)
      amplitude = [@params[:key_tooth_depth], corridor * 0.4].min
      return if amplitude < @params[:key_tooth_depth_min]

      # Направление зуба (случайное — влево или вправо)
      direction = @rng.rand > 0.5 ? 1 : -1

      # Деформировать A: добавить зуб на правой границе
      tooth_a_x = mid_a[0] + amplitude * direction
      tooth_top_a = [lerp_x(top_a[0], tooth_a_x, 0.7), lerp_y(top_a[1], mid_a[1], 0.4)]
      tooth_bot_a = [lerp_x(bot_a[0], tooth_a_x, 0.7), lerp_y(bot_a[1], mid_a[1], 0.4)]

      # Вставить зуб после right_idx_a
      insert_idx_a = (right_idx_a + 1) % n_a
      pts_a.insert(insert_idx_a, tooth_bot_a, [tooth_a_x, mid_a[1]], tooth_top_a)
      cell_a.points2d = pts_a

      # Деформировать B: добавить зуб на левой границе (противоположный)
      tooth_b_x = mid_b[0] - amplitude * direction
      tooth_top_b = [lerp_x(top_b[0], tooth_b_x, 0.7), lerp_y(top_b[1], mid_b[1], 0.4)]
      tooth_bot_b = [lerp_x(bot_b[0], tooth_b_x, 0.7), lerp_y(bot_b[1], mid_b[1], 0.4)]

      insert_idx_b = (left_idx_b + 1) % n_b
      pts_b.insert(insert_idx_b, tooth_bot_b, [tooth_b_x, mid_b[1]], tooth_top_b)
      cell_b.points2d = pts_b
    end

    def find_rightmost_point_index(pts)
      max_x = -Float::INFINITY
      idx = nil
      pts.each_with_index do |p, i|
        if p[0] > max_x
          max_x = p[0]
          idx = i
        end
      end
      idx
    end

    def find_leftmost_point_index(pts)
      min_x = Float::INFINITY
      idx = nil
      pts.each_with_index do |p, i|
        if p[0] < min_x
          min_x = p[0]
          idx = i
        end
      end
      idx
    end

    def estimate_corridor(pts, mid_idx)
      n = pts.length
      prev_pt = pts[(mid_idx - 1 + n) % n]
      next_pt = pts[(mid_idx + 1) % n]
      dist = Geom2D.distance(prev_pt, next_pt)
      [dist * 0.4, 5.0].max
    end

    def lerp_x(a, b, t)
      a + t * (b - a)
    end

    def lerp_y(a, b, t)
      a + t * (b - a)
    end
  end
end
