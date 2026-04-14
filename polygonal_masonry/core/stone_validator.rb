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
        next unless valid_polygon?(cell.points2d)
        next unless sufficient_area?(cell.points2d)
        next unless sufficient_angle?(cell.points2d)

        kind = classify_stone(cell)
        area = Geom2D.polygon_area(cell.points2d).abs
        centroid = Geom2D.polygon_centroid(cell.points2d)

        valid << ValidatedStone.new(cell.points2d, kind, area, centroid)
      end

      valid
    end

    private

    def valid_polygon?(pts)
      return false if pts.nil? || pts.length < 3
      # Проверка самопересечений (простая)
      n = pts.length
      return false if n > 100  # слишком много вершин — артефакт

      # Проверка коллинеарности
      (0...n).each do |i|
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        return false if Geom2D.distance(p1, p2) < @params[:min_edge] * 0.5
      end

      true
    end

    def sufficient_area?(pts)
      area = Geom2D.polygon_area(pts).abs
      area >= @params[:min_area]
    end

    def sufficient_angle?(pts)
      angle = Geom2D.min_interior_angle(pts)
      angle >= @params[:min_angle_deg]
    end

    def classify_stone(cell)
      # Простая эвристика: one_to_two / two_to_one = замковый
      return :key if cell.kind == :key

      # Проверка асимметрии bbox
      pts = cell.points2d
      xs = pts.map { |p| p[0] }
      ys = pts.map { |p| p[1] }
      w = xs.max - xs.min
      h = ys.max - ys.min
      return :normal if w < 0.001 || h < 0.001

      # Если соотношение сторон слишком большое — edge
      ratio = [w, h].max / [w, h].min
      return :edge if ratio > 5.0

      :normal
    end
  end
end
