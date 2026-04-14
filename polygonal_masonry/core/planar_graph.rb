# encoding: UTF-8
# Планарный граф рёбер

module PolygonalMasonry
  class PlanarGraph
    attr_reader :edges, :faces

    def initialize
      @edges = []       # [[p1, p2], ...]
      @faces = []       # [[pt, pt, ...], ...]
      @vertex_map = {}  # "x,y" -> [x, y]
      @adjacency = {}   # "x,y" => Set of "x,y"
    end

    # Добавить отрезок
    def add_segment(p1, p2)
      v1 = snap_point(p1)
      v2 = snap_point(p2)
      return if v1 == v2
      return if edge_exists?(v1, v2)

      @edges << [v1, v2]

      @adjacency[vertex_key(v1)] ||= Set.new
      @adjacency[vertex_key(v2)] ||= Set.new
      @adjacency[vertex_key(v1)] << vertex_key(v2)
      @adjacency[vertex_key(v2)] << vertex_key(v1)
    end

    # Добавить полигон (замкнутую ломаную)
    def add_polygon(pts)
      return if pts.length < 3

      (0...pts.length).each do |i|
        add_segment(pts[i], pts[(i + 1) % pts.length])
      end
    end

    # Извлечь грани (камни)
    def extract_faces
      visited_edges = Set.new
      faces = []

      @edges.each do |edge|
        v1, v2 = edge
        k1 = vertex_key(v1)
        k2 = vertex_key(v2)

        # Прямое ребро
        next if visited_edges.include?("#{k1}->#{k2}")

        # Обход левых граней
        face = traverse_face(v1, v2, visited_edges)
        next unless face && face.length >= 3

        area = Geom2D.polygon_area(face)
        next if area.abs < 1e-6  # слишком маленькая

        faces << face
      end

      @faces = faces
    end

    # Отфильтровать внешнюю грань
    def filter_outer_face!
      return if @faces.empty?

      # Наибольшая площадь = внешняя грань
      max_area = -Float::INFINITY
      max_idx = 0

      @faces.each_with_index do |f, i|
        area = Geom2D.polygon_area(f).abs
        if area > max_area
          max_area = area
          max_idx = i
        end
      end

      @faces.delete_at(max_idx)
    end

    private

    EPSILON = 0.0001

    def snap_point(pt)
      key = vertex_key(pt)
      return @vertex_map[key] if @vertex_map[key]

      @vertex_map[key] = pt.dup
      pt
    end

    def vertex_key(pt)
      "#{pt[0].round(6)},#{pt[1].round(6)}"
    end

    def edge_exists?(v1, v2)
      k1 = vertex_key(v1)
      k2 = vertex_key(v2)
      @edges.any? do |e|
        (vertex_key(e[0]) == k1 && vertex_key(e[1]) == k2) ||
        (vertex_key(e[0]) == k2 && vertex_key(e[1]) == k1)
      end
    end

    def traverse_face(start_from, start_to, visited_edges)
      face = []
      current_from = start_from
      current_to = start_to

      max_iter = @edges.length * 2
      iter = 0

      loop do
        iter += 1
        break if iter > max_iter

        kf = vertex_key(current_from)
        kt = vertex_key(current_to)
        edge_str = "#{kf}->#{kt}"

        break if visited_edges.include?(edge_str)
        visited_edges << edge_str

        face << current_to.dup

        # Найти следующий: самое правое ребро из current_to
        next_vertex = find_left_face_edge(current_to, current_from)
        break unless next_vertex

        current_from = current_to
        current_to = next_vertex

        # Замкнулись?
        if vertex_key(current_to) == vertex_key(start_to) && vertex_key(current_from) == vertex_key(start_from)
          break if face.length >= 3
        end
      end

      face.length >= 3 ? face : nil
    end

    def find_left_face_edge(vertex, from_vertex)
      kv = vertex_key(vertex)
      neighbors = @adjacency[kv]
      return nil unless neighbors

      kf = vertex_key(from_vertex)
      best_angle = -Float::INFINITY
      best_neighbor = nil

      neighbors.each do |nk|
        next if nk == kf
        n = @vertex_map[nk]
        angle = angle_between(from_vertex, vertex, n)
        if angle > best_angle
          best_angle = angle
          best_neighbor = n
        end
      end

      best_neighbor
    end

    # Угол поворота от from->vertex к vertex->to (против часовой = положительный)
    def angle_between(from_pt, vertex, to_pt)
      v1 = [from_pt[0] - vertex[0], from_pt[1] - vertex[1]]
      v2 = [to_pt[0] - vertex[0], to_pt[1] - vertex[1]]

      len1 = Math.sqrt(v1[0]**2 + v1[1]**2)
      len2 = Math.sqrt(v2[0]**2 + v2[1]**2)
      return 0 if len1 < 1e-10 || len2 < 1e-10

      cos_a = Geom2D.dot(v1, v2) / (len1 * len2)
      sin_a = Geom2D.cross(v1, v2) / (len1 * len2)

      Math.atan2(sin_a, cos_a)
    end
  end
end
