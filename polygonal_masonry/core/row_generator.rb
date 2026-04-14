# encoding: UTF-8
# Генерация волнистых рядовых кривых

module PolygonalMasonry
  RowCurve = Struct.new(:samples)  # [[x,y], [x,y], ...]

  class RowGenerator
    def initialize(bbox, params, rng)
      @bbox = bbox
      @params = params
      @rng = rng
      @ymin = bbox[:ymin]
      @ymax = bbox[:ymax]
      @xmin = bbox[:xmin]
      @xmax = bbox[:xmax]
    end

    def build_rows
      rows = []
      y = @ymin

      # Первый ряд — прямая по нижнему краю
      rows << make_straight_row(y)

      loop do
        # Случайный шаг высоты
        jitter = (@rng.rand * 2 - 1) * @params[:row_height_jitter]
        step = @params[:row_height_mean] + jitter
        step = [step, @params[:min_edge] * 2].max  # минимальный зазор

        y += step
        break if y >= @ymax - @params[:min_edge]

        rows << make_wavy_row(y)
      end

      # Последний ряд — прямая по верхнему краю
      rows << make_straight_row(@ymax)

      # Проверка: минимум 2 ряда
      rows << make_straight_row(@ymax) if rows.length < 2

      rows
    end

    private

    def make_straight_row(y)
      samples = generate_x_samples
      samples.map { |x| [x, y] }
    end

    def make_wavy_row(y_base)
      samples = generate_x_samples
      amplitude = @params[:row_curve_amplitude]
      wavelength = @params[:row_curve_wavelength]
      phase = @rng.rand * 2 * Math::PI

      samples.map do |x|
        dy = amplitude * Math.sin(2 * Math::PI * x / wavelength + phase)
        [x, y_base + dy]
      end
    end

    def generate_x_samples
      step = @params[:stone_width_mean] / 4.0
      step = [step, (@xmax - @xmin) / 60.0].max  # минимум 60 сэмплов
      step = [step, (@xmax - @xmin) / 3.0].min   # максимум ~3 сэмпла

      n = ((@xmax - @xmin) / step).to_i
      n = [n, 4].max

      (0..n).map { |i| @xmin + i * (@xmax - @xmin) / n.to_f }
    end
  end
end
