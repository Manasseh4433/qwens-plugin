# encoding: UTF-8
# StoneValidator — фильтрует дефектные камни и маркирует замковые

module PolygonalMasonry
  class StoneValidator

    ValidatedStone = Struct.new(:points2d, :kind, :area, :centroid)

    def initialize(params)
      @params = params
    end

    # cells — Array[StoneCell]
    # Возвращает Array[ValidatedStone]
    def filter_and_repair(cells)
      result = []
      cells.each do |cell|
        pts = cell.points2d
        next if pts.nil? || pts.size < 3

        # Убрать дублирующиеся точки
        pts = remove_duplicates(pts)
        next if pts.size < 3

        # Проверить самопересечение (упрощённо: площадь должна быть > 0)
        area = Geom2D.polygon_area(pts).abs
        # Порог для краевых (обрезанных) камней — 40% от min_area
        next if area < (@params[:min_area] || 0.01) * 0.40

        # Минимальный угол — смягчённый фильтр (18° вместо 26°)
        min_ang = Geom2D.min_interior_angle_deg(pts)
        min_allowed = [(@params[:min_angle_deg] || 20.0) * 0.70, 18.0].max
        next if min_ang < min_allowed

        # Максимальное соотношение сторон (bbox) — увеличено до 8 для краевых камней
        bbox   = Geom2D.bbox(pts)
        bw     = bbox[:xmax] - bbox[:xmin]
        bh     = bbox[:ymax] - bbox[:ymin]
        aspect = [bw, bh].max / ([bw, bh].min + 1e-10)
        next if aspect > 8.0

        # Определяем kind
        kind = detect_kind(pts, cell.kind, bbox)

        centroid = Geom2D.polygon_centroid(pts)
        result << ValidatedStone.new(pts, kind, area, centroid)
      end
      result
    end

    private

    def remove_duplicates(pts)
      eps = 1e-6
      result = [pts[0]]
      pts[1..].each do |p|
        last = result.last
        dist = Math.sqrt((p[0]-last[0])**2 + (p[1]-last[1])**2)
        result << p if dist > eps
      end
      # Проверить последнюю и первую
      if result.size > 1
        first = result.first; last = result.last
        dist = Math.sqrt((first[0]-last[0])**2 + (first[1]-last[1])**2)
        result.pop if dist < 1e-6
      end
      result
    end

    def detect_kind(pts, original_kind, bbox)
      return :key if original_kind == :key

      # Автоопределение замкового камня:
      # верхняя ширина сильно отличается от нижней
      top_pts = pts.select { |p| (p[1] - bbox[:ymax]).abs < (bbox[:ymax]-bbox[:ymin])*0.25 }
      bot_pts = pts.select { |p| (p[1] - bbox[:ymin]).abs < (bbox[:ymax]-bbox[:ymin])*0.25 }

      if top_pts.size >= 2 && bot_pts.size >= 2
        top_w = top_pts.map{|p|p[0]}.max - top_pts.map{|p|p[0]}.min
        bot_w = bot_pts.map{|p|p[0]}.max - bot_pts.map{|p|p[0]}.min
        ratio = [top_w, bot_w].min / ([top_w, bot_w].max + 1e-10)
        return :key if ratio < 0.78
      end

      original_kind || :normal
    end
  end
end
