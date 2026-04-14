# encoding: UTF-8
# SketchupBuilder — запись финальной геометрии в модель SketchUp

module PolygonalMasonry
  class SketchupBuilder

    def initialize(face, frame, params)
      @face   = face
      @frame  = frame
      @params = params
    end

    def build(stones)
      model    = Sketchup.active_model
      entities = model.active_entities

      model.start_operation('Polygonal Masonry', true)

      begin
        group  = entities.add_group
        g_ents = group.entities

        built   = 0
        skipped = 0
        jw      = @params[:joint_width] || 0.0

        stones.each do |stone|
          pts2d = stone.points2d
          next if pts2d.nil? || pts2d.size < 3

          # Если задана ширина шва — сделать inset
          display_pts = if jw > 1e-4
                          inset = Geom2D.offset_polygon(pts2d, -jw / 2.0)
                          (inset && inset.size >= 3) ? inset : pts2d
                        else
                          pts2d
                        end

          pts3d = display_pts.map { |p| @frame.to_3d(p[0], p[1]) }
          next if pts3d.size < 3

          begin
            face = g_ents.add_face(pts3d)
            if face.is_a?(Sketchup::Face)
              face.material = material_for(stone.kind, model)
              built += 1
            else
              skipped += 1
            end
          rescue => e
            skipped += 1
          end
        end

        # Стереть исходную грань
        @face.erase! if @face.valid?

        model.commit_operation
        UI.messagebox("Готово! Создано #{built} камней, пропущено #{skipped}.")

      rescue => e
        model.abort_operation
        UI.messagebox("Ошибка генерации кладки:\n#{e.message}\n\n#{e.backtrace.first(5).join("\n")}")
      end
    end

    private

    def material_for(kind, model)
      case kind
      when :key
        get_or_create_material(model, 'PM_KeyStone',    [140, 115, 90])
      when :edge
        get_or_create_material(model, 'PM_EdgeStone',   [160, 150, 135])
      else
        get_or_create_material(model, 'PM_NormalStone', [185, 170, 148])
      end
    end

    def get_or_create_material(model, name, rgb)
      mat = model.materials[name]
      unless mat
        mat = model.materials.add(name)
        mat.color = Sketchup::Color.new(*rgb)
      end
      mat
    end
  end
end
