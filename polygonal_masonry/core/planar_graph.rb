# encoding: UTF-8
# PlanarGraph — планарный граф рёбер с HalfEdge-структурой

module PolygonalMasonry
  class PlanarGraph
    EPSILON = 1.0e-7

    Vertex   = Struct.new(:x, :y, :out_edges)   # out_edges: Array[HalfEdge]
    HalfEdge = Struct.new(:origin, :twin, :next_edge, :prev_edge, :visited)

    attr_reader :vertices, :half_edges

    def initialize
      @vertices   = []   # Array[Vertex]
      @half_edges = []   # Array[HalfEdge]
      @vert_map   = {}   # "[x_rounded,y_rounded]" => Vertex
    end

    # Добавить отрезок (разбивает при пересечении с существующими)
    def add_segment(p1, p2)
      return if points_equal?(p1, p2)
      v1 = find_or_create_vertex(p1)
      v2 = find_or_create_vertex(p2)
      return if v1.equal?(v2)
      add_half_edge_pair(v1, v2)
    end

    # Добавить ломаную
    def add_polyline(pts)
      pts.each_cons(2) { |a, b| add_segment(a, b) }
    end

    # Добавить ломаную, обрезав по выпуклому полигону boundary (CCW)
    def add_polyline_clipped(pts, boundary)
      pts.each_cons(2) do |a, b|
        seg = PolygonClip.clip_segment_by_polygon(a, b, boundary)
        add_segment(seg[0], seg[1]) if seg
      end
    end

    # Сортировать исходящие рёбра каждой вершины по полярному углу
    def finalize!
      @vertices.each do |v|
        v.out_edges.sort_by! do |he|
          t = he.twin.origin
          Math.atan2(t.y - v.y, t.x - v.x)
        end
        # Связать next/prev в цикле вокруг грани
        v.out_edges.each_with_index do |he, i|
          # twin.next = следующее ребро вокруг вершины (по часовой стрелке от twin)
          prev_he = v.out_edges[(i - 1 + v.out_edges.size) % v.out_edges.size]
          he.twin.next_edge = prev_he
          prev_he.prev_edge = he.twin
        end
      end
    end

    private

    def key_for(pt)
      x = (pt[0] / EPSILON).round
      y = (pt[1] / EPSILON).round
      "#{x},#{y}"
    end

    def points_equal?(a, b)
      (a[0]-b[0]).abs < EPSILON && (a[1]-b[1]).abs < EPSILON
    end

    def find_or_create_vertex(pt)
      k = key_for(pt)
      return @vert_map[k] if @vert_map[k]
      v = Vertex.new(pt[0], pt[1], [])
      @vertices << v
      @vert_map[k] = v
      v
    end

    def add_half_edge_pair(v1, v2)
      # Проверить, не существует ли уже это ребро
      existing = v1.out_edges.find { |he| he.twin.origin.equal?(v2) }
      return if existing

      he1 = HalfEdge.new(v1, nil, nil, nil, false)
      he2 = HalfEdge.new(v2, nil, nil, nil, false)
      he1.twin = he2
      he2.twin = he1

      v1.out_edges << he1
      v2.out_edges << he2

      @half_edges << he1
      @half_edges << he2
    end
  end
end
