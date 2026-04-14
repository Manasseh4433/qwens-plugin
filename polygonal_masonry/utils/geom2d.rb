# encoding: UTF-8
# Утилиты 2D-геометрии для плагина «Рядная полигональная кладка»

module PolygonalMasonry
  module Geom2D
    EPSILON = 1.0e-8

    # Линейная интерполяция двух точек [x,y]
    def self.lerp(a, b, t)
      [(1-t)*a[0] + t*b[0], (1-t)*a[1] + t*b[1]]
    end

    # Длина вектора между двумя точками
    def self.dist(a, b)
      Math.sqrt((b[0]-a[0])**2 + (b[1]-a[1])**2)
    end

    # Знаковая площадь полигона (Shoelace). Положительная = CCW.
    def self.polygon_area(pts)
      n = pts.size
      area = 0.0
      n.times do |i|
        j = (i+1) % n
        area += pts[i][0] * pts[j][1]
        area -= pts[j][0] * pts[i][1]
      end
      area / 2.0
    end

    # Центроид полигона
    def self.polygon_centroid(pts)
      area = polygon_area(pts)
      return pts[0].dup if area.abs < EPSILON
      cx = cy = 0.0
      n = pts.size
      n.times do |i|
        j = (i+1) % n
        cross = pts[i][0]*pts[j][1] - pts[j][0]*pts[i][1]
        cx += (pts[i][0]+pts[j][0]) * cross
        cy += (pts[i][1]+pts[j][1]) * cross
      end
      factor = 1.0 / (6.0 * area)
      [cx * factor, cy * factor]
    end

    # Проверка: точка внутри полигона (ray-casting)
    def self.point_in_polygon?(pt, polygon)
      x, y = pt
      inside = false
      n = polygon.size
      j = n - 1
      n.times do |i|
        xi, yi = polygon[i]
        xj, yj = polygon[j]
        if ((yi > y) != (yj > y)) && (x < (xj-xi)*(y-yi)/(yj-yi) + xi)
          inside = !inside
        end
        j = i
      end
      inside
    end

    # Пересечение двух отрезков. Возвращает [x,y] или nil.
    def self.segment_intersect(p1, p2, p3, p4)
      dx1 = p2[0]-p1[0]; dy1 = p2[1]-p1[1]
      dx2 = p4[0]-p3[0]; dy2 = p4[1]-p3[1]
      denom = dx1*dy2 - dy1*dx2
      return nil if denom.abs < EPSILON
      dx3 = p3[0]-p1[0]; dy3 = p3[1]-p1[1]
      t = (dx3*dy2 - dy3*dx2) / denom
      u = (dx3*dy1 - dy3*dx1) / denom
      return nil unless t >= -EPSILON && t <= 1+EPSILON && u >= -EPSILON && u <= 1+EPSILON
      [p1[0] + t*dx1, p1[1] + t*dy1]
    end

    # Минимальный внутренний угол полигона в градусах
    def self.min_interior_angle_deg(pts)
      n = pts.size
      min_ang = 360.0
      n.times do |i|
        a = pts[(i-1+n)%n]
        b = pts[i]
        c = pts[(i+1)%n]
        v1 = [a[0]-b[0], a[1]-b[1]]
        v2 = [c[0]-b[0], c[1]-b[1]]
        len1 = Math.sqrt(v1[0]**2+v1[1]**2)
        len2 = Math.sqrt(v2[0]**2+v2[1]**2)
        next if len1 < EPSILON || len2 < EPSILON
        cos_a = (v1[0]*v2[0]+v1[1]*v2[1]) / (len1*len2)
        cos_a = [[-1.0, cos_a].max, 1.0].min
        angle = Math.acos(cos_a) * 180.0 / Math::PI
        min_ang = angle if angle < min_ang
      end
      min_ang
    end

    # Интерполяция y по x на ломаной (массив [[x,y],...], монотонной по x)
    def self.polyline_y_at_x(segments, x)
      return segments.first[1] if x <= segments.first[0]
      return segments.last[1]  if x >= segments.last[0]
      segments.each_cons(2) do |a, b|
        if x >= a[0] && x <= b[0]
          t = (x - a[0]) / (b[0] - a[0])
          return a[1] + t*(b[1]-a[1])
        end
      end
      segments.last[1]
    end

    # Убедиться, что полигон идёт по часовой стрелке (CW, для SketchUp нормаль вниз)
    def self.ensure_cw(pts)
      polygon_area(pts) > 0 ? pts.reverse : pts
    end

    # Убедиться, что полигон идёт против часовой стрелки (CCW)
    def self.ensure_ccw(pts)
      polygon_area(pts) < 0 ? pts.reverse : pts
    end

    # Bounding box полигона → {xmin, xmax, ymin, ymax}
    def self.bbox(pts)
      xs = pts.map { |p| p[0] }
      ys = pts.map { |p| p[1] }
      { xmin: xs.min, xmax: xs.max, ymin: ys.min, ymax: ys.max }
    end

    # Простой inset полигона на расстояние d (d < 0 = offset внутрь).
    # Работает для выпуклых и большинства невыпуклых полигонов.
    # Возвращает новый массив точек или nil при ошибке.
    def self.offset_polygon(pts, d)
      n = pts.size
      return nil if n < 3

      result = []
      n.times do |i|
        prev_pt = pts[(i - 1 + n) % n]
        curr_pt = pts[i]
        next_pt = pts[(i + 1) % n]

        # Нормали к двум смежным рёбрам (вовнутрь для CCW-полигона)
        e1x = curr_pt[0] - prev_pt[0]; e1y = curr_pt[1] - prev_pt[1]
        e2x = next_pt[0] - curr_pt[0]; e2y = next_pt[1] - curr_pt[1]
        len1 = Math.sqrt(e1x**2 + e1y**2)
        len2 = Math.sqrt(e2x**2 + e2y**2)
        return nil if len1 < EPSILON || len2 < EPSILON

        # Нормали (повёрнутые на 90° влево = внутрь для CCW)
        n1x = -e1y / len1; n1y = e1x / len1
        n2x = -e2y / len2; n2y = e2x / len2

        # Биссектриса
        bx = n1x + n2x; by = n1y + n2y
        blen = Math.sqrt(bx**2 + by**2)

        if blen < EPSILON
          # Рёбра параллельны — смещаем просто по нормали
          result << [curr_pt[0] + d * n1x, curr_pt[1] + d * n1y]
        else
          # Коэффициент удлинения биссектрисы
          cos_half = (n1x * bx + n1y * by) / blen
          return nil if cos_half.abs < EPSILON
          factor = d / cos_half
          result << [curr_pt[0] + factor * bx / blen,
                     curr_pt[1] + factor * by / blen]
        end
      end

      # Проверить что inset не вывернул полигон
      orig_area   = polygon_area(pts).abs
      result_area = polygon_area(result).abs
      return nil if result_area < orig_area * 0.01  # слишком маленький

      result
    end
  end
end
