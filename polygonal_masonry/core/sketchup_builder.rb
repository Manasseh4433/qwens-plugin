# encoding: UTF-8
# Запись геометрии в модель SketchUp

require 'sketchup.rb'

module PolygonalMasonry
  class SketchupBuilder
    def initialize(face, frame, params)
      @face = face
      @frame = frame
      @params = params
      @model = face.model
      @entities = face.parent.entities
    end

    def build(validated_stones)
      return [] if validated_stones.empty?

      # Создаём группу для всех камней
      group = @entities.add_group
      g_entities = group.entities

      @model.start_operation('Рядная полигональная кладка', true)

      # Материалы для разных типов камней
      mat_normal = get_or_create_material('Stone_Normal', [0.75, 0.7, 0.65])
      mat_key = get_or_create_material('Stone_Key', [0.65, 0.55, 0.5])
      mat_edge = get_or_create_material('Stone_Edge', [0.7, 0.65, 0.6])

      created_faces = []

      validated_stones.each do |stone|
        pts3d = stone.points2d.map { |p2d| @frame.to_3d(p2d[0], p2d[1]) }

        # Убрать дубликаты
        pts3d = unique_points(pts3d)
        next if pts3d.length < 3

        # Проверить компланарность
        next unless points_coplanar?(pts3d)

        begin
          new_face = g_entities.add_face(pts3d)

          # Назначить материал
          case stone.kind
          when :key
            new_face.material = mat_key
          when :edge
            new_face.material = mat_edge
          else
            new_face.material = mat_normal
          end

          created_faces << new_face
        rescue => e
          puts "SketchupBuilder: ошибка создания грани: #{e.message}"
        end
      end

      # Удалить исходную грань
      begin
        @entities.erase_entities(@face) if @face.valid?
      rescue
        # Игнорируем ошибки удаления
      end

      @model.commit_operation

      # Обратная ориентация, если нужно
      created_faces.each do |f|
        begin
          f.reverse! unless f.normal.samedirection?(@face.normal) rescue nil
        rescue
          # Face может быть невалидным после erase
        end
      end

      created_faces
    end

    private

    def get_or_create_material(name, color_rgb)
      materials = @model.materials
      mat = materials[name]
      unless mat
        mat = materials.add(name)
      end
      mat.color = Sketchup::Color.new(
        (color_rgb[0] * 255).to_i,
        (color_rgb[1] * 255).to_i,
        (color_rgb[2] * 255).to_i
      )
      mat
    rescue
      nil
    end

    def unique_points(pts)
      unique = []
      tolerance = 0.001  # дюймы

      pts.each do |pt|
        dup = unique.find { |u| u.distance(pt) < tolerance }
        unique << pt unless dup
      end

      unique
    end

    def points_coplanar?(pts)
      return true if pts.length <= 3

      # Проверить все точки против плоскости первых трёх
      p0, p1, p2 = pts[0], pts[1], pts[2]
      v1 = Geom::Vector3d.new(p1.x - p0.x, p1.y - p0.y, p1.z - p0.z)
      v2 = Geom::Vector3d.new(p2.x - p0.x, p2.y - p0.y, p2.z - p0.z)
      normal = v1 * v2
      return true if normal.length < 0.0001

      normal.normalize!

      pts.each do |pt|
        v = Geom::Vector3d.new(pt.x - p0.x, pt.y - p0.y, pt.z - p0.z)
        return false if v.dot(normal).abs > 0.01
      end

      true
    end
  end
end
