# encoding: UTF-8
# Локальная система координат для плоской грани SketchUp.
# Ось U направлена вдоль «горизонтали» (проекция мировой оси X или Y),
# чтобы ряды кладки шли горизонтально.

module PolygonalMasonry
  class FaceLocalFrame
    attr_reader :origin, :u_axis, :v_axis, :normal

    def initialize(face)
      @face   = face
      @normal = face.normal

      outer   = face.outer_loop.vertices.map(&:position)
      @origin = outer[0]

      # Выбираем U-ось: проекция мировой оси X на плоскость грани.
      # Если грань вертикальная (нормаль почти горизонтальная), U = проекция X_мира.
      # Если грань горизонтальная (нормаль почти вертикальная), U = проекция X_мира тоже.
      world_x = Geom::Vector3d.new(1, 0, 0)
      world_y = Geom::Vector3d.new(0, 1, 0)

      # Проецируем мировую X на плоскость нормали грани
      proj_x = project_on_plane(world_x, @normal)
      proj_y = project_on_plane(world_y, @normal)

      # Выбираем ту проекцию, которая длиннее (не коллинеарна нормали)
      if proj_x.length > proj_y.length
        @u_axis = proj_x.normalize
      else
        @u_axis = proj_y.normalize
      end

      # V = Normal × U (правая тройка)
      @v_axis = (@normal * @u_axis).normalize
    end

    # Geom::Point3d → [x, y]
    def to_2d(pt3d)
      vec = pt3d - @origin
      [vec % @u_axis, vec % @v_axis]
    end

    # [x, y] → Geom::Point3d
    def to_3d(x, y)
      Geom::Point3d.new(
        @origin.x + x * @u_axis.x + y * @v_axis.x,
        @origin.y + x * @u_axis.y + y * @v_axis.y,
        @origin.z + x * @u_axis.z + y * @v_axis.z
      )
    end

    # Внешний контур грани в 2D
    def face_loop_2d
      @face.outer_loop.vertices.map { |v| to_2d(v.position) }
    end

    # Bounding box в 2D
    def bbox_2d
      pts = face_loop_2d
      xs  = pts.map { |p| p[0] }
      ys  = pts.map { |p| p[1] }
      { xmin: xs.min, xmax: xs.max, ymin: ys.min, ymax: ys.max }
    end

    private

    # Проекция вектора v на плоскость с нормалью n
    def project_on_plane(v, n)
      dot = v % n  # скалярное произведение
      Geom::Vector3d.new(
        v.x - dot * n.x,
        v.y - dot * n.y,
        v.z - dot * n.z
      )
    end
  end
end
