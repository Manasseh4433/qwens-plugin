# encoding: UTF-8
# encoding: UTF-8
# Главная точка входа плагина «Рядная полигональная кладка»

require 'sketchup.rb'

# Загрузка модулей
PLUGIN_DIR_QWEN = File.dirname(__FILE__)

require File.join(PLUGIN_DIR_QWEN, 'config.rb')
require File.join(PLUGIN_DIR_QWEN, 'utils', 'geom2d.rb')
require File.join(PLUGIN_DIR_QWEN, 'utils', 'polygon_clip.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'face_local_frame.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'auto_params.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'row_generator.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'node_distributor.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'seam_matcher.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'cell_builder.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'seam_deformer.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'planar_graph.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'stone_validator.rb')
require File.join(PLUGIN_DIR_QWEN, 'core', 'sketchup_builder.rb')

module PolygonalMasonry
  # Главная функция: запустить генерацию на выбранной грани
  def self.run_on_selected_face
    model = Sketchup.active_model
    selection = model.selection

    # Проверить выбор
    if selection.empty?
      UI.messagebox("Выберите одну плоскую грань и запустите плагин снова.", MB_OK)
      return
    end

    if selection.length != 1
      UI.messagebox("Выберите только одну грань.", MB_OK)
      return
    end

    entity = selection[0]
    unless entity.is_a?(Sketchup::Face)
      UI.messagebox("Выбранный объект не является гранью.", MB_OK)
      return
    end

    face = entity

    Sketchup.status_text = 'Рядная полигональная кладка: анализ грани...'

    begin
      # Шаг 1: Локальная система координат
      frame = FaceLocalFrame.new(face)
      unless frame.planar?
        UI.messagebox("Грань недостаточно плоская.", MB_OK)
        Sketchup.status_text = ''
        return
      end

      bbox = frame.bbox_2d
      local_width = bbox[:xmax] - bbox[:xmin]
      local_height = bbox[:ymax] - bbox[:ymin]

      # Проверка минимального размера в локальной системе координат
      min_dim = [local_width, local_height].min
      if min_dim < 1.0  # ~25 мм
        UI.messagebox("Грань слишком маленькая. Минимальный размер: ~25 мм.", MB_OK)
        Sketchup.status_text = ''
        return
      end

      # Шаг 2: Автопараметры
      auto = AutoParams.new(bbox)
      params = auto.compute

      # Показать диалог параметров (упрощённый)
      params = show_params_dialog(params)
      return unless params

      # Seed
      seed = params[:seed] || rand(1000000).to_i
      rng = Random.new(seed)

      Sketchup.status_text = 'Генерация рядов...'

      # Шаг 3: Генерация рядов
      row_gen = RowGenerator.new(bbox, params, rng)
      rows = row_gen.build_rows

      if rows.length < 2
        UI.messagebox("Не удалось сгенерировать ряды. Увеличьте размер грани.", MB_OK)
        Sketchup.status_text = ''
        return
      end

      # Шаг 4: Расстановка узлов
      Sketchup.status_text = 'Расстановка узлов...'
      distributor = NodeDistributor.new(rows, bbox, params, rng)
      row_nodes = distributor.distribute

      # Шаг 5: Сопоставление швов
      Sketchup.status_text = 'Сопоставление швов...'
      matcher = SeamMatcher.new(row_nodes, params, rng)
      cell_specs_by_band = matcher.match_all

      # Шаг 6: Построение ячеек
      Sketchup.status_text = 'Построение ячеек...'
      builder = CellBuilder.new(rows, row_nodes, params, rng)
      all_cells = []

      cell_specs_by_band.each_with_index do |specs, band_idx|
        cells = builder.build_cells(band_idx, specs)
        all_cells << cells
      end

      # Шаг 7: Деформация швов (замковые зубья)
      Sketchup.status_text = 'Деформация швов...'
      deformer = SeamDeformer.new(all_cells, params, rng)
      deformed_cells = deformer.deform_all

      # Шаг 8: Обрезка по контуру грани
      Sketchup.status_text = 'Обрезка по контуру...'
      boundary_2d = frame.face_loop_2d

      clipped_cells = []
      deformed_cells.each do |cell|
        clipped = PolygonClip.clip_polygon(cell.points2d, boundary_2d)
        next unless clipped && clipped.length >= 3

        cell.points2d = clipped
        clipped_cells << cell
      end

      # Шаг 9: Валидация
      Sketchup.status_text = 'Валидация камней...'
      validator = StoneValidator.new(params)
      validated = validator.filter_and_repair(clipped_cells)

      if validated.empty?
        UI.messagebox("Не удалось создать камни. Попробуйте увеличить размер грани.", MB_OK)
        Sketchup.status_text = ''
        return
      end

      # Шаг 10: Построение в SketchUp
      Sketchup.status_text = 'Создание геометрии...'
      sketchup_builder = SketchupBuilder.new(face, frame, params)
      created_faces = sketchup_builder.build(validated)

      Sketchup.status_text = ''

      if created_faces.empty?
        UI.messagebox("Не удалось создать грани в SketchUp.", MB_OK)
      else
        UI.messagebox("Создано #{created_faces.length} камней полигональной кладки!", MB_OK)
      end

    rescue => e
      Sketchup.status_text = ''
      error_msg = "Ошибка при генерации:\n\n#{e.message}\n\n"
      error_msg += "Стек:\n#{e.backtrace.first(8).join("\n")}"
      UI.messagebox(error_msg, MB_OK)

      puts "=== Polygonal Masonry Error ==="
      puts e.message
      puts e.backtrace.first(15).join("\n")
    end
  end

  # Упрощённый диалог параметров
  def self.show_params_dialog(params)
    prompts = [
      "Высота ряда (мм)",
      "Ширина камня (мм)",
      "Разброс высоты (мм)",
      "Разброс ширины (мм)",
      "Доля замковых (%)",
      "Глубина зуба (мм)",
      "Ширина шва (мм)",
      "Seed (воспроизводимость)"
    ]

    values = [
      params[:row_height_mean].to_mm.round(1).to_s,
      params[:stone_width_mean].to_mm.round(1).to_s,
      params[:row_height_jitter].to_mm.round(1).to_s,
      params[:stone_width_jitter].to_mm.round(1).to_s,
      (params[:key_stone_ratio] * 100).round(0).to_s,
      params[:key_tooth_depth].to_mm.round(1).to_s,
      params[:joint_width].to_mm.round(1).to_s,
      (params[:seed] || rand(100000).to_i).to_s
    ]

    result = UI.inputbox(prompts, values, "Параметры полигональной кладки")
    return nil unless result

    # Парсинг
    begin
      params[:row_height_mean] = result[0].to_f.mm
      params[:stone_width_mean] = result[1].to_f.mm
      params[:row_height_jitter] = result[2].to_f.mm
      params[:stone_width_jitter] = result[3].to_f.mm
      params[:key_stone_ratio] = result[4].to_f / 100.0
      params[:key_tooth_depth] = result[5].to_f.mm
      params[:joint_width] = result[6].to_f.mm
      params[:seed] = result[7].to_i
    rescue
      UI.messagebox("Ошибка разбора параметров. Используются значения по умолчанию.", MB_OK)
    end

    params
  end

  # Alias для меню
  def self.generate
    run_on_selected_face
  end
end

# Добавить меню
unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  submenu = menu.add_submenu('Полигональная кладка')

  submenu.add_item('Создать кладку') do
    PolygonalMasonry.run_on_selected_face
  end

  submenu.add_separator

  submenu.add_item('О плагине...') do
    UI.messagebox(
      "Рядная полигональная кладка v#{PolygonalMasonry::Config::VERSION}\n\n" \
      "Выберите плоскую грань и запустите плагин.\n" \
      "Параметры подбираются автоматически.\n\n" \
      "Алгоритм: рядная генерация с монотонным сопоставлением\n" \
      "узлов, замковыми зубьями и перевязкой рядов.",
      MB_OK
    )
  end

  file_loaded(__FILE__)
end

puts "Рядная полигональная кладка v#{PolygonalMasonry::Config::VERSION} загружена."
