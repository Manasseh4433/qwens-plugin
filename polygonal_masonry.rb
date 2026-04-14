# encoding: UTF-8
# Корневой файл плагина «Рядная полигональная кладка»
# Устанавливается в папку Plugins SketchUp

require 'sketchup.rb'
require 'extensions.rb'

module PolygonalMasonry
  PLUGIN_DIR = File.dirname(__FILE__)

  unless file_loaded?(__FILE__)
    loader = File.join(PLUGIN_DIR, 'polygonal_masonry', 'polygonal_masonry.rb')

    ex = SketchupExtension.new(
      'Polygonal Masonry — Рядная полигональная кладка',
      loader
    )
    ex.description = 'Генерирует рядную полигональную кладку (древний стиль) на выбранной плоской грани'
    ex.version     = '0.3.0'
    ex.copyright   = '2024'
    ex.creator     = 'PolygonalMasonry'

    Sketchup.register_extension(ex, true)

    # Добавляем пункт меню (как резервный вариант если тулбар не появился)
    menu = UI.menu('Extensions')
    sub  = menu.add_submenu('Polygonal Masonry')
    sub.add_item('Применить к выбранной грани') do
      require loader
      PolygonalMasonry.run_on_selected_face
    end
    sub.add_separator
    sub.add_item('О плагине') do
      UI.messagebox(
        "Рядная полигональная кладка v0.3.0\n\n" \
        "Выберите плоскую грань и запустите плагин.\n" \
        "Параметры подбираются автоматически.",
        MB_OK
      )
    end

    # Тулбар (загружается после регистрации расширения)
    UI.start_timer(0.1, false) do
      begin
        require loader
        require File.join(PLUGIN_DIR, 'polygonal_masonry', 'ui', 'toolbar')
        PolygonalMasonry::Toolbar.create
      rescue => e
        # Тулбар опционален — ошибка не критична
        puts "PM Toolbar: #{e.message}"
      end
    end

    file_loaded(__FILE__)
  end
end
