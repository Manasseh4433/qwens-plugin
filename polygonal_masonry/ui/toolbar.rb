# encoding: UTF-8
# Toolbar — тулбар плагина с кнопкой запуска

module PolygonalMasonry
  module Toolbar
    TOOLBAR_NAME = 'Polygonal Masonry'

    def self.create
      tb = UI::Toolbar.new(TOOLBAR_NAME)

      # Кнопка «Применить кладку»
      cmd = UI::Command.new('Apply Masonry') do
        PolygonalMasonry.run_on_selected_face
      end

      # Иконки (PNG 24x24 и 48x48)
      icons_dir = File.join(File.dirname(__FILE__), '..', '..', 'icons')
      small_icon = File.join(icons_dir, 'masonry_24.png')
      large_icon = File.join(icons_dir, 'masonry_48.png')

      if File.exist?(small_icon) && File.exist?(large_icon)
        cmd.small_icon = small_icon
        cmd.large_icon = large_icon
      end

      cmd.tooltip         = 'Применить рядную полигональную кладку к выбранной грани'
      cmd.status_bar_text = 'Выберите плоскую грань и нажмите кнопку'

      tb.add_item(cmd)
      tb.restore

      tb
    end
  end
end
