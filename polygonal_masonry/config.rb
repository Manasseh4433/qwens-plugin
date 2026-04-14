# encoding: UTF-8
# encoding: UTF-8
# Конфигурация плагина «Рядная полигональная кладка»

module PolygonalMasonry
  module Config
    VERSION = '1.0.0'

    # Параметры по умолчанию (в дюймах — единицы SketchUp)
    # 1 inch = 25.4 mm
    DEFAULT_PARAMS = {
      row_height_mean:       35.433.mm,     # ~900mm средняя высота ряда
      row_height_jitter:      9.843.mm,     # ~250mm разброс высоты
      stone_width_mean:      47.244.mm,     # ~1200mm средняя ширина камня
      stone_width_jitter:    15.748.mm,     # ~400mm разброс ширины
      row_curve_amplitude:    4.331.mm,     # ~110mm амплитуда волны ряда
      row_curve_wavelength: 118.110.mm,     # ~3000mm длина волны
      seam_jitter:            5.512.mm,     # ~140mm излом шва
      key_stone_ratio:       0.20,          # 20% замковых камней
      key_tooth_depth:        7.087.mm,     # ~180mm глубина зуба
      key_tooth_depth_min:    2.362.mm,     # ~60mm мин глубина зуба
      min_edge:               4.724.mm,     # ~120mm мин ребро
      min_area:               0.06.m2,      # мин площадь камня
      min_angle_deg:         26.0,          # мин внутренний угол
      joint_width:            0.mm,         # ширина шва (0 = линии)
      one_to_one_prob:       0.60,
      one_to_two_prob:       0.20,
      two_to_one_prob:       0.20,
      seed:                  nil
    }

    # Целевой диапазон числа камней
    TARGET_STONE_COUNT_RANGE = 30..120
    ASPECT_RATIO_IDEAL       = 1.4
    KEY_STONE_RATIO          = 0.20
  end
end
