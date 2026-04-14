# encoding: UTF-8
# 3D <-> 2D преобразование координат грани

require 'sketchup.rb'

module PolygonalMasonry
  class FaceLocalFrame
    attr_reader :face, :origin, :u, :v, :normal

    def initialize(face)
      @face = face
      @normal = face.normal

      # Origin — первая вершина внешнего контура
      loop3d = face.outer_loop.vertices.map(&:position)
      @origin = loop3d[0]

      # Ось u — первое ребро грани
      e1 = loop3d[1] - @origin
      @u = e1.normalize

      # Ось v = normal x u
      @v = @normal * @u
      @v.normalize!

      # Переортогонализировать u
      @u = @v * @normal
      @u.normalize!
    end

    # 3D -> 2D [x, y]
    def to_2d(pt3d)
      vec = pt3d - @origin
      x = vec.dot(@u)
      y = vec.dot(@v)
      [x, y]
    end

    # 2D -> 3D Geom::Point3d
    def to_3d(x, y)
      @origin.offset(@u, x).offset(@v, y)
    end

    # Внешний контур в 2D
    def face_loop_2d
      @face.outer_loop.vertices.map { |v| to_2d(v.position) }
    end

    # Bounding box контура в 2D
    def bbox_2d
      loop2d = face_loop_2d
      xs = loop2d.map { |p| p[0] }
      ys = loop2d.map { |p| p[1] }
      { xmin: xs.min, xmax: xs.max, ymin: ys.min, ymax: ys.max }
    end

    # Проверка плоскостности грани
    def planar?
      tolerance = 0.001  # дюймы
      @face.vertices.each do |v|
        pt = v.position
        vec = pt - @origin
        dist = vec.dot(@normal).abs
        return false if dist > tolerance
      end
      true
    end
  end
end
