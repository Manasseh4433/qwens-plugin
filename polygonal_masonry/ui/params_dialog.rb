# encoding: UTF-8
# ParamsDialog — диалог параметров кладки

module PolygonalMasonry
  class ParamsDialog
    def initialize(auto_params, bbox2d)
      @auto = auto_params
      @bbox = bbox2d
    end

    # Показать диалог. Возвращает Hash параметров или nil (Cancel).
    def show
      m = 1.0 / 39.3701   # дюймы → метры

      rh  = (@auto[:row_height_mean]    * m).round(3)
      sw  = (@auto[:stone_width_mean]   * m).round(3)
      rj  = (@auto[:row_height_jitter]  * m).round(3)
      wj  = (@auto[:stone_width_jitter] * m).round(3)
      ksr = @auto[:key_stone_ratio].round(2)
      jw  = (@auto[:joint_width]        * m).round(3)

      # Оценка количества камней
      w_m = (@bbox[:xmax] - @bbox[:xmin]) * m
      h_m = (@bbox[:ymax] - @bbox[:ymin]) * m
      est_count = ((w_m / sw) * (h_m / rh)).round

      prompts = [
        "Высота ряда (м)  [авто: #{rh}]",
        "Ширина камня (м)  [авто: #{sw}]",
        'Разброс высоты (м)',
        'Разброс ширины (м)',
        'Доля замковых камней (0–0.4)',
        'Ширина шва (м, 0 = только линии)',
        'Seed (0 = случайный)',
        "≈ #{est_count} камней (только инфо)"
      ]
      defaults = [rh, sw, rj, wj, ksr, jw, 0, '']
      list     = ['', '', '', '', '', '', '', '']

      results = UI.inputbox(prompts, defaults, list, 'Параметры кладки v0.3')
      return nil unless results

      scale = 39.3701
      rh2  = results[0].to_f * scale
      sw2  = results[1].to_f * scale
      rj2  = results[2].to_f * scale
      wj2  = results[3].to_f * scale
      ksr2 = [[results[4].to_f, 0.0].max, 0.45].min
      jw2  = results[5].to_f * scale
      seed = results[6].to_i

      {
        row_height_mean:      rh2,
        row_height_jitter:    rj2,
        stone_width_mean:     sw2,
        stone_width_jitter:   wj2,
        row_curve_amplitude:  rh2 * 0.12,
        row_curve_wavelength: sw2 * 2.5,
        seam_jitter:          sw2 * 0.12,
        key_stone_ratio:      ksr2,
        key_tooth_depth:      sw2 * 0.15,
        key_tooth_depth_min:  sw2 * 0.06,
        min_stone_height:     rh2 * 0.35,
        min_stone_width:      sw2 * 0.28,
        min_area:             rh2 * sw2 * 0.07,
        min_angle_deg:        26.0,
        joint_width:          jw2,
        one_to_one_prob:      0.60,
        one_to_two_prob:      0.20,
        two_to_one_prob:      0.20,
        seed:                 seed > 0 ? seed : nil
      }
    end
  end
end
