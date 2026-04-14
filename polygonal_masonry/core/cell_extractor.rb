# encoding: UTF-8
# CellExtractor — извлекает замкнутые ячейки (камни) из PlanarGraph

module PolygonalMasonry
  class CellExtractor
    def initialize(planar_graph)
      @graph = planar_graph
    end

    # Возвращает Array[Array[[x,y]]] — массив замкнутых полигонов
    # Внешняя «бесконечная» грань отбрасывается (наибольшая по модулю площадь или площадь < 0)
    def extract_faces
      @graph.finalize!

      faces = []

      @graph.half_edges.each do |start_he|
        next if start_he.visited
        next if start_he.next_edge.nil?

        face_pts = []
        he = start_he
        max_iter = @graph.half_edges.size + 1
        iter = 0

        loop do
          break if iter > max_iter
          he.visited = true
          face_pts << [he.origin.x, he.origin.y]
          he = he.next_edge
          break if he.nil? || he.equal?(start_he)
          iter += 1
        end

        next if face_pts.size < 3
        faces << face_pts
      end

      # Отбросить внешнюю грань (площадь < 0 в нашей CCW-конвенции, т.е. самая большая по |area|)
      # или грань с наибольшей отрицательной площадью
      if faces.size > 1
        areas  = faces.map { |f| Geom2D.polygon_area(f) }
        # Внешняя грань — с наименьшей (самой отрицательной) площадью
        min_idx = areas.each_with_index.min_by { |a, _| a }[1]
        faces.delete_at(min_idx)
      end

      faces
    end
  end
end
