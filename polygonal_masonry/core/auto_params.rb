# encoding: UTF-8
# AutoParams — автоматический выбор параметров кладки по размерам грани

module PolygonalMasonry
  class AutoParams
    TARGET_STONE_COUNT = 60
    ASPECT_RATIO       = 1.4   # идеальное соотношение ширина:высота камня

    # bbox2d: { xmin, xmax, ymin, ymax } в дюймах (единицы SketchUp)
    def initialize(bbox2d)
      @bbox = bbox2d
    end

    def compute
      w = @bbox[:xmax] - @bbox[:xmin]
      h = @bbox[:ymax] - @bbox[:ymin]
      area = w * h

      # Площадь одного камня
      stone_area = area.to_f / TARGET_STONE_COUNT

      # Размеры камня из соотношения сторон
      sh = Math.sqrt(stone_area / ASPECT_RATIO)
      sw = stone_area / sh

      # Количество рядов
      n_rows = [(h / sh).round, 3].max
      row_h  = h.to_f / n_rows

      # Ограничения снизу (минимум 3 дюйма = ~76 мм)
      sh = [sh, 3.0].max
      sw = [sw, 4.0].max
      row_h = [row_h, sh].max

      {
        row_height_mean:     row_h,
        row_height_jitter:   row_h * 0.28,
        stone_width_mean:    sw,
        stone_width_jitter:  sw * 0.33,
        row_curve_amplitude: row_h * 0.12,
        row_curve_wavelength: sw * 2.5,
        seam_jitter:         sw * 0.12,
        key_stone_ratio:     0.20,
        key_tooth_depth:     sw * 0.15,
        key_tooth_depth_min: sw * 0.06,
        min_stone_height:    sh * 0.38,
        min_stone_width:     sw * 0.30,
        min_area:            sh * sw * 0.08,
        min_angle_deg:       26.0,
        joint_width:         0.0,
        one_to_one_prob:     0.60,
        one_to_two_prob:     0.20,
        two_to_one_prob:     0.20,
        seed:                nil
      }
    end
  end
end
