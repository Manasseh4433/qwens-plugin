# encoding: UTF-8
# Фильтрация и маркировка камней

module PolygonalMasonry
  ValidatedStone = Struct.new(:points2d, :kind, :area, :centroid)

  class StoneValidator
    def initialize(params)
      @params = params
    end

    def filter_and_repair(cells)
      valid = []

      cells.each do |cell|
        next unless cell.points2d && cell.points2d.length >= 3
        # Только базовая проверка — принимаем почти всё
        valid << ValidatedStone.new(
          cell.points2d,
          classify_stone(cell),
          Geom2D.polygon_area(cell.points2d).abs,
          Geom2D.polygon_centroid(cell.points2d)
        )
      end

      valid
    end

    private

    def classify_stone(cell)
      return :key if cell.kind == :key
      :normal
    end
  end
end
