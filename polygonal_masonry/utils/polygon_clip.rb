# encoding: UTF-8
# Обрезка полигонов по контуру (Sutherland-Hodgman)

module PolygonalMasonry
  module PolygonClip
    # Проверка: точка слева от ребра (для CCW контура = внутри)
    def self.is_inside(point, edge_start, edge_end)
      # (edge_end - edge_start) x (point - edge_start) >= 0
      cross = (edge_end[0] - edge_start[0]) * (point[1] - edge_start[1]) -
              (edge_end[1] - edge_start[1]) * (point[0] - edge_start[0])
      cross >= -1e-10
    end

    # Пересечение отрезка AB с ребром clip
    def self.intersection(a, b, clip_start, clip_end)
      # Параметрическое пересечение
      da = [a[0] - b[0], a[1] - b[1]]
      db = [clip_end[0] - clip_start[0], clip_end[1] - clip_start[1]]

      denom = da[0] * db[1] - da[1] * db[0]
      return a.dup if denom.abs < 1e-10

      t = ((clip_start[0] - a[0]) * db[1] - (clip_start[1] - a[1]) * db[0]) / denom
      [[a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])]]
    end

    # Sutherland-Hodgman: обрезка subject по clip_boundary
    def self.clip_polygon(subject, clip_boundary)
      return [] if subject.nil? || subject.empty?

      output = subject.dup

      clip_boundary.each_with_index do |cp, i|
        ce = clip_boundary[(i + 1) % clip_boundary.length]
        input = output
        output = []
        break if input.empty?

        input.each_with_index do |s, j|
          e = input[(j + 1) % input.length]
          s_in = is_inside(s, cp, ce)
          e_in = is_inside(e, cp, ce)

          if s_in && e_in
            output << e
          elsif s_in && !e_in
            output += intersection(s, e, cp, ce)
          elsif !s_in && e_in
            output += intersection(s, e, cp, ce)
            output << e
          end
        end
      end

      output
    end

    # Обрезать полилинию по полигону — вернуть сегменты внутри
    def self.clip_polyline(polyline, boundary)
      return [] if polyline.nil? || polyline.length < 2

      segments = []
      current_segment = []

      polyline.each_with_index do |pt, i|
        inside = is_inside(pt, boundary[0], boundary[1])
        # Более надёжная проверка — ray casting
        inside = Geom2D.point_in_polygon?(pt, boundary)

        if inside
          current_segment << pt
        else
          if current_segment.length >= 2
            segments << current_segment
          end
          current_segment = []

          # Проверить пересечение с границей
          if i > 0
            prev = polyline[i - 1]
            boundary.each_cons(2) do |b1, b2|
              inter = Geom2D.segment_intersect(prev, pt, b1, b2)
              if inter
                segments << [inter] if current_segment.empty?
                current_segment = [inter] unless current_segment.length >= 2 && Geom2D.distance(current_segment.last, inter) < 1e-6
              end
            end
          end
        end
      end

      segments << current_segment if current_segment.length >= 2
      segments
    end
  end
end
