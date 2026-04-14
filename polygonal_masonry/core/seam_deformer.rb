# encoding: UTF-8
# SeamDeformer — добавляет замковые зубья на вертикальные швы между камнями
# v0.3.2: клиновидный зуб через смещение точек на общей вертикальной границе.
#   Левый камень: точки на правой границе смещаются на +dx (выступ вправо)
#   Правый камень: точки на левой границе смещаются на +dx (паз — тот же выступ)
#   → оба полигона имеют одинаковую изломанную границу → нет зазоров и перекрытий.

module PolygonalMasonry
  class SeamDeformer

    def initialize(params, rng)
      @params = params
      @rng    = rng
    end

    # cells — Array[StoneCell] из одной полосы (band).
    # Возвращает новый Array[StoneCell] — те же или с зубьями.
    def deform_band(cells)
      return cells if cells.size < 2

      key_ratio = @params[:key_stone_ratio] || 0.15
      avg_w     = avg_stone_width(cells)
      # Амплитуда зуба: 10–15% от средней ширины (не более key_tooth_depth)
      max_tooth = [avg_w * 0.12, @params[:key_tooth_depth] || 5.0].min
      min_tooth = @params[:key_tooth_depth_min] || 1.5

      return cells if max_tooth < min_tooth

      result = cells.map { |c| CellBuilder::StoneCell.new(c.points2d.dup, c.kind) }

      (0...result.size - 1).each do |i|
        next if @rng.rand > key_ratio

        left_pts  = result[i].points2d
        right_pts = result[i + 1].points2d

        # Общая вертикальная граница
        lx_max = left_pts.map  { |p| p[0] }.max
        rx_min = right_pts.map { |p| p[0] }.min
        # Допуск: 20% от средней ширины
        tol_x = avg_w * 0.20
        next if (lx_max - rx_min).abs > tol_x

        x_bnd = (lx_max + rx_min) / 2.0

        # Y-диапазон точек вблизи границы
        l_near = left_pts.select  { |p| (p[0] - x_bnd).abs <= tol_x }
        r_near = right_pts.select { |p| (p[0] - x_bnd).abs <= tol_x }
        next if l_near.size < 2 || r_near.size < 2

        ys = (l_near + r_near).map { |p| p[1] }
        y_lo = ys.min; y_hi = ys.max
        h = y_hi - y_lo
        next if h < 2.0

        # Амплитуда (не более h/5 чтобы не создавать острых углов)
        amplitude = [max_tooth, h / 5.0].min
        next if amplitude < min_tooth

        # Направление: ±1, случайно
        dir = @rng.rand < 0.5 ? 1.0 : -1.0
        dx = amplitude * dir

        # КЛЮЧЕВОЕ: оба камня смещают свои точки на x_bnd на ОДИНАКОВОЕ dx
        # Левый смещает правую границу: +dx
        # Правый смещает левую границу: +dx (тот же знак → та же линия)
        new_left  = shift_boundary(left_pts,  x_bnd, tol_x, dx, y_lo, y_hi)
        new_right = shift_boundary(right_pts, x_bnd, tol_x, dx, y_lo, y_hi)

        if valid_polygon?(new_left) && valid_polygon?(new_right)
          result[i].points2d     = new_left
          result[i + 1].points2d = new_right
        end
      end

      result
    end

    private

    def avg_stone_width(cells)
      return 10.0 if cells.empty?
      total = cells.sum do |c|
        xs = c.points2d.map { |p| p[0] }
        xs.max - xs.min
      end
      total / cells.size.to_f
    end

    # Смещает точки вблизи x_boundary на dx, с линейным затуханием к краям [y_lo, y_hi].
    # Обе стороны шва вызывают этот метод с ОДИНАКОВЫМ dx → граница совпадает.
    def shift_boundary(pts, x_boundary, tol_x, dx, y_lo, y_hi)
      y_mid    = (y_lo + y_hi) / 2.0
      half_h   = (y_hi - y_lo) / 2.0
      return pts if half_h < 1e-7

      result = pts.map do |p|
        if (p[0] - x_boundary).abs <= tol_x && p[1].between?(y_lo, y_hi)
          # Линейное затухание: максимум в середине, ноль на краях
          t = 1.0 - ((p[1] - y_mid) / half_h).abs
          t = t.clamp(0.0, 1.0)
          [p[0] + dx * t, p[1]]
        else
          p
        end
      end

      # Убрать соседние дубликаты
      clean = []
      result.each do |p|
        unless clean.last &&
               (clean.last[0] - p[0]).abs < 1e-7 &&
               (clean.last[1] - p[1]).abs < 1e-7
          clean << p
        end
      end

      clean.size >= 3 ? Geom2D.ensure_ccw(clean) : pts
    end

    def valid_polygon?(pts)
      return false if pts.size < 3
      Geom2D.polygon_area(pts).abs > 1e-6
    rescue
      false
    end
  end
end
