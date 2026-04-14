# encoding: UTF-8
# Автомасштаб параметров по размеру грани

module PolygonalMasonry
  class AutoParams
    TARGET_STONE_COUNT_RANGE = 30..120
    ASPECT_RATIO_IDEAL = 1.4

    def initialize(bbox)
      @bbox = bbox
      @width = bbox[:xmax] - bbox[:xmin]
      @height = bbox[:ymax] - bbox[:ymin]
    end

    def compute
      area = @width * @height
      target_count = compute_target_count(area)
      stone_area = area / target_count.to_f

      stone_height = Math.sqrt(stone_area / ASPECT_RATIO_IDEAL)
      stone_width = stone_area / stone_height

      n_rows = (@height / stone_height).round
      n_rows = [n_rows, 2].max
      row_height_mean = @height / n_rows.to_f

      {
        row_height_mean:      row_height_mean,
        row_height_jitter:    row_height_mean * 0.25,
        stone_width_mean:     stone_width,
        stone_width_jitter:   stone_width * 0.3,
        row_curve_amplitude:  row_height_mean * 0.12,
        row_curve_wavelength: stone_width * 3.0,
        seam_jitter:          stone_width * 0.12,
        key_stone_ratio:      0.20,
        key_tooth_depth:      stone_width * 0.15,
        key_tooth_depth_min:  stone_width * 0.05,
        min_edge:             [stone_width * 0.1, 0.2].min,
        min_area:             stone_area * 0.1,
        min_angle_deg:        26.0,
        joint_width:          0.0,
        one_to_one_prob:      0.60,
        one_to_two_prob:      0.20,
        two_to_one_prob:      0.20,
        seed:                 nil
      }
    end

    private

    def compute_target_count(area)
      # Эвристика: больше площадь -> больше камней, но в диапазоне
      count = (area / 1000.0).round  # настраиваемый коэффициент
      [[count, TARGET_STONE_COUNT_RANGE.begin].max, TARGET_STONE_COUNT_RANGE.end].min
    end
  end
end
