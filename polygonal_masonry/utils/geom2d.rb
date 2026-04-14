# encoding: UTF-8
# encoding: UTF-8
# Базовая 2D-геометрия

module PolygonalMasonry
  module Geom2D
    # Линейная интерполяция между двумя точками
    def self.lerp(a, b, t)
      [a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])]
    end

    # Расстояние между двумя точками
    def self.distance(a, b)
      Math.sqrt((b[0] - a[0])**2 + (b[1] - a[1])**2)
    end

    # Пересечение двух отрезков (p1-p2 и p3-p4)
    # Возвращает [x, y] или nil
    def self.segment_intersect(p1, p2, p3, p4)
      denom = (p1[0] - p2[0]) * (p3[1] - p4[1]) - (p1[1] - p2[1]) * (p3[0] - p4[0])
      return nil if denom.abs < 1e-10

      t = ((p1[0] - p3[0]) * (p3[1] - p4[1]) - (p1[1] - p3[1]) * (p3[0] - p4[0])) / denom
      u = -((p1[0] - p2[0]) * (p1[1] - p3[1]) - (p1[1] - p2[1]) * (p1[0] - p3[0])) / denom

      return nil if t < 0 || t > 1 || u < 0 || u > 1

      [p1[0] + t * (p2[0] - p1[0]), p1[1] + t * (p2[1] - p1[1])]
    end

    # Точка внутри полигона? (ray casting)
    def self.point_in_polygon?(pt, polygon)
      x, y = pt
      inside = false
      n = polygon.length

      polygon.each_with_index do |v, i|
        vi = polygon[(i + 1) % polygon.length]
        xi, yi = v
        xj, yj = vi

        if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi).to_f / (yj - yi) + xi)
          inside = !inside
        end
      end
      inside
    end

    # Площадь полигона (Shoelace formula) — знаковая
    def self.polygon_area(pts)
      return 0.0 if pts.length < 3
      area = 0.0
      n = pts.length
      pts.each_with_index do |p, i|
        q = pts[(i + 1) % n]
        area += p[0] * q[1] - q[0] * p[1]
      end
      area / 2.0
    end

    # Центроид полигона
    def self.polygon_centroid(pts)
      return [0, 0] if pts.empty?
      cx = pts.reduce(0.0) { |s, p| s + p[0] } / pts.length
      cy = pts.reduce(0.0) { |s, p| s + p[1] } / pts.length
      [cx, cy]
    end

    # Минимальный внутренний угол полигона (в градусах)
    def self.min_interior_angle(pts)
      return 180.0 if pts.length < 3
      min_angle = 180.0
      n = pts.length
      pts.each_with_index do |p, i|
        prev = pts[(i - 1) % n]
        next_p = pts[(i + 1) % n]

        v1 = [prev[0] - p[0], prev[1] - p[1]]
        v2 = [next_p[0] - p[0], next_p[1] - p[1]]

        len1 = Math.sqrt(v1[0]**2 + v1[1]**2)
        len2 = Math.sqrt(v2[0]**2 + v2[1]**2)
        next if len1 < 1e-10 || len2 < 1e-10

        dot = v1[0] * v2[0] + v1[1] * v2[1]
        cos_a = dot / (len1 * len2)
        cos_a = [[cos_a, -1.0].max, 1.0].min
        angle = Math.acos(cos_a) * 180.0 / Math::PI
        min_angle = angle if angle < min_angle
      end
      min_angle
    end

    # Bounding box для набора точек
    def self.bounding_box(pts)
      xs = pts.map { |p| p[0] }
      ys = pts.map { |p| p[1] }
      { xmin: xs.min, xmax: xs.max, ymin: ys.min, ymax: ys.max }
    end

    # Простой offset полигона inward на расстояние d
    def self.offset_polygon(pts, d)
      return pts if pts.length < 3
      offset = []
      n = pts.length
      pts.each_with_index do |p, i|
        prev = pts[(i - 1) % n]
        next_p = pts[(i + 1) % n]

        # Нормали к рёбрам (внутрь)
        e1 = [p[0] - prev[0], p[1] - prev[1]]
        e2 = [next_p[0] - p[0], next_p[1] - p[1]]
        len1 = Math.sqrt(e1[0]**2 + e1[1]**2)
        len2 = Math.sqrt(e2[0]**2 + e2[1]**2)
        next if len1 < 1e-10 || len2 < 1e-10

        # Внутренняя нормаль к e1
        n1 = [-e1[1] / len1, e1[0] / len1]
        n2 = [-e2[1] / len2, e2[0] / len2]

        # Проверяем направление — должно быть внутрь (к центроиду)
        centroid = polygon_centroid(pts)
        to_centroid = [centroid[0] - p[0], centroid[1] - p[1]]
        n1.reverse! if n1[0] * to_centroid[0] + n1[1] * to_centroid[1] < 0
        n2.reverse! if n2[0] * to_centroid[0] + n2[1] * to_centroid[1] < 0

        # Смещаем вершину
        shift_x = (n1[0] + n2[0]) * d / 2.0
        shift_y = (n1[1] + n2[1]) * d / 2.0
        offset << [p[0] + shift_x, p[1] + shift_y]
      end
      offset.length >= 3 ? offset : pts
    end

    # Полилиния: найти y при заданном x (интерполяция)
    def self.polyline_y_at_x(segments, x)
      return nil if segments.nil? || segments.empty?
      segments.each_cons(2) do |p1, p2|
        if (x >= p1[0] && x <= p2[0]) || (x >= p2[0] && x <= p1[0])
          dx = p2[0] - p1[0]
          return p1[1] if dx.abs < 1e-10
          t = (x - p1[0]).to_f / dx
          return p1[1] + t * (p2[1] - p1[1])
        end
      end
      nil
    end

    # Пересечение отрезка с рёбрами полигона — все точки
    def self.segment_polygon_intersections(p1, p2, boundary)
      intersections = []
      boundary.each_cons(2) do |e1, e2|
        pt = segment_intersect(p1, p2, e1, e2)
        intersections << pt if pt
      end
      # Замыкающее ребро
      pt = segment_intersect(p1, p2, boundary.last, boundary.first)
      intersections << pt if pt
      intersections
    end

    # Скалярное произведение 2D
    def self.dot(a, b)
      a[0] * b[0] + a[1] * b[1]
    end

    # Векторное произведение (z-компонента)
    def self.cross(a, b)
      a[0] * b[1] - a[1] * b[0]
    end
  end
end
