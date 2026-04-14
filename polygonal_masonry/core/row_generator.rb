# encoding: UTF-8
# RowGenerator — генерация волнистых рядовых кривых

module PolygonalMasonry
  class RowGenerator
    # Кривая ряда: массив [[x, y], ...] с монотонным x
    RowCurve = Struct.new(:samples) do
      def y_at(x)
        PolygonalMasonry::Geom2D.polyline_y_at_x(samples, x)
      end
    end

    def initialize(bbox2d, params, rng)
      @bbox   = bbox2d
      @params = params
      @rng    = rng
    end

    def build_rows
      xmin = @bbox[:xmin]; xmax = @bbox[:xmax]
      ymin = @bbox[:ymin]; ymax = @bbox[:ymax]

      rows = []

      # Нижняя граница — прямая линия
      rows << make_straight_curve(xmin, xmax, ymin)

      y_current = ymin
      loop do
        delta = @params[:row_height_mean] +
                (@rng.rand * 2 - 1) * @params[:row_height_jitter]
        min_h = @params[:min_stone_height] || @params[:row_height_mean] * 0.4
        delta = [min_h, delta].max
        y_current += delta
        break if y_current >= ymax - min_h * 0.5
        rows << make_wavy_curve(xmin, xmax, y_current)
      end

      # Верхняя граница — прямая линия
      rows << make_straight_curve(xmin, xmax, ymax)

      rows
    end

    private

    def make_straight_curve(xmin, xmax, y)
      samples = linspace(xmin, xmax, 4).map { |x| [x, y] }
      RowCurve.new(samples)
    end

    def make_wavy_curve(xmin, xmax, y_base)
      amplitude  = @params[:row_curve_amplitude] || 0.0
      wavelength = @params[:row_curve_wavelength] || (xmax - xmin)
      phase      = @rng.rand * Math::PI * 2

      # Количество сэмплов: чем шире, тем больше (но не менее 12)
      width     = xmax - xmin
      n_samples = [[12, (width / (wavelength * 0.3)).ceil].max, 40].min

      samples = linspace(xmin, xmax, n_samples).map do |x|
        # Синусоидальная волна + небольшой случайный шум
        wave  = amplitude * Math.sin(2 * Math::PI * x / wavelength + phase)
        noise = (@rng.rand * 2 - 1) * amplitude * 0.15
        [x, y_base + wave + noise]
      end

      # Сглаживание: скользящее среднее по 3 точкам
      smoothed = samples.dup
      1.upto(samples.size - 2) do |i|
        smoothed[i] = [
          samples[i][0],
          (samples[i-1][1] + samples[i][1] + samples[i+1][1]) / 3.0
        ]
      end

      # Монотонность по x гарантирована linspace, но проверим y-диапазон
      # (кривые не должны "уходить" слишком далеко)
      RowCurve.new(smoothed)
    end

    def linspace(a, b, n)
      return [a] if n <= 1
      step = (b - a).to_f / (n - 1)
      (0...n).map { |i| a + i * step }
    end
  end
end
