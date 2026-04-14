# encoding: UTF-8
# Фильтрация и обрезка полигонов по контуру границы

module PolygonalMasonry
  module PolygonClip
    # Основная функция: проверить и обрезать камень по границе
    # Возвращает полигон или nil если камень полностью снаружи
    def self.clip_polygon(polygon, boundary)
      return nil if polygon.nil? || polygon.empty? || boundary.nil? || boundary.length < 3

      # Проверка: все вершины внутри
      all_inside = polygon.all? { |p| Geom2D.point_in_polygon?(p, boundary) }
      return polygon.dup if all_inside

      # Ни одна вершина внутри — камень полностью снаружи
      any_inside = polygon.any? { |p| Geom2D.point_in_polygon?(p, boundary) }
      return nil unless any_inside

      # Частично внутри: проверяем центроид
      centroid = Geom2D.polygon_centroid(polygon)
      return nil unless Geom2D.point_in_polygon?(centroid, boundary)

      # Центроид внутри — берём весь камень (без обрезки, чтобы избежать артефактов)
      polygon.dup
    end

    # Обрезать полилинию по полигону
    def self.clip_polyline(polyline, boundary)
      return [] if polyline.nil? || polyline.length < 2
      segments = []
      current_segment = []

      polyline.each_with_index do |pt, i|
        if Geom2D.point_in_polygon?(pt, boundary)
          current_segment << pt
        else
          segments << current_segment if current_segment.length >= 2
          current_segment = []
          if i > 0
            prev = polyline[i - 1]
            boundary.each_cons(2) do |b1, b2|
              inter = Geom2D.segment_intersect(prev, pt, b1, b2)
              if inter
                current_segment = [inter] if current_segment.empty? || Geom2D.distance(current_segment.last, inter) > 1e-6
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
