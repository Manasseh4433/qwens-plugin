# encoding: UTF-8
# PolygonClip — обрезка полигонов и полилиний

module PolygonalMasonry
  module PolygonClip

    # Sutherland-Hodgman: обрезать subject по clip (clip должен быть выпуклым, CCW).
    def self.clip_polygon_by_polygon(subject_pts, clip_pts)
      output = subject_pts.dup
      n = clip_pts.size
      n.times do |i|
        break if output.empty?
        input  = output
        output = []
        a = clip_pts[i]
        b = clip_pts[(i + 1) % n]
        input.size.times do |k|
          curr = input[k]
          prev = input[(k - 1 + input.size) % input.size]
          if inside?(curr, a, b)
            output << line_intersect(prev, curr, a, b) unless inside?(prev, a, b)
            output << curr
          elsif inside?(prev, a, b)
            pt = line_intersect(prev, curr, a, b)
            output << pt if pt
          end
        end
      end
      output
    end

    # Обрезка по невыпуклому полигону: если clip выпуклый — Sutherland-Hodgman,
    # иначе — последовательная обрезка по полуплоскостям рёбер.
    def self.clip_polygon_by_nonconvex(subject_pts, clip_pts)
      if convex?(clip_pts)
        clip_polygon_by_polygon(subject_pts, ensure_ccw(clip_pts))
      else
        result = subject_pts.dup
        n = clip_pts.size
        n.times do |i|
          a = clip_pts[i]
          b = clip_pts[(i + 1) % n]
          result = clip_by_halfplane(result, a, b)
          break if result.empty?
        end
        result
      end
    end

    # Обрезать отрезок [p1,p2] по выпуклому полигону boundary (CCW).
    # Возвращает [q1, q2] или nil.
    def self.clip_segment_by_polygon(p1, p2, boundary_pts)
      t_enter = 0.0
      t_exit  = 1.0
      dx = p2[0] - p1[0]
      dy = p2[1] - p1[1]
      n  = boundary_pts.size

      n.times do |i|
        a  = boundary_pts[i]
        b  = boundary_pts[(i + 1) % n]
        ex = b[0] - a[0]; ey = b[1] - a[1]
        nx = -ey;          ny =  ex
        denom = nx * dx + ny * dy
        num   = nx * (a[0] - p1[0]) + ny * (a[1] - p1[1])

        if denom.abs < 1e-10
          return nil if num < 0
        else
          t = num / denom
          if denom < 0
            t_exit  = [t_exit,  t].min
          else
            t_enter = [t_enter, t].max
          end
        end
        return nil if t_enter > t_exit + 1e-8
      end

      return nil if t_enter > t_exit + 1e-8
      q1 = [p1[0] + t_enter * dx, p1[1] + t_enter * dy]
      q2 = [p1[0] + t_exit  * dx, p1[1] + t_exit  * dy]
      [q1, q2]
    end

    # Обрезать ломаную по полигону. Возвращает Array[[q1,q2], ...].
    def self.clip_polyline_by_polygon(polyline_pts, boundary_pts)
      result = []
      polyline_pts.each_cons(2) do |p1, p2|
        seg = clip_segment_by_polygon(p1, p2, boundary_pts)
        result << seg if seg
      end
      result
    end

    # Проверить выпуклость полигона (все кросс-произведения одного знака)
    def self.convex?(pts)
      n = pts.size
      return true if n <= 3
      sign = nil
      n.times do |i|
        a = pts[i]; b = pts[(i+1)%n]; c = pts[(i+2)%n]
        cross = (b[0]-a[0])*(c[1]-b[1]) - (b[1]-a[1])*(c[0]-b[0])
        next if cross.abs < 1e-10
        s = cross > 0 ? 1 : -1
        sign ||= s
        return false if s != sign
      end
      true
    end

    private

    def self.inside?(pt, a, b)
      (b[0]-a[0])*(pt[1]-a[1]) - (b[1]-a[1])*(pt[0]-a[0]) >= -1e-10
    end

    def self.line_intersect(p1, p2, p3, p4)
      dx1 = p2[0]-p1[0]; dy1 = p2[1]-p1[1]
      dx2 = p4[0]-p3[0]; dy2 = p4[1]-p3[1]
      denom = dx1*dy2 - dy1*dx2
      return nil if denom.abs < 1e-12
      t = ((p3[0]-p1[0])*dy2-(p3[1]-p1[1])*dx2) / denom
      [p1[0]+t*dx1, p1[1]+t*dy1]
    end

    def self.clip_by_halfplane(pts, a, b)
      return [] if pts.empty?
      output = []
      n = pts.size
      n.times do |i|
        curr = pts[i]
        prev = pts[(i - 1 + n) % n]
        if inside?(curr, a, b)
          output << line_intersect(prev, curr, a, b) unless inside?(prev, a, b)
          output << curr
        elsif inside?(prev, a, b)
          pt = line_intersect(prev, curr, a, b)
          output << pt if pt
        end
      end
      output
    end

    def self.ensure_ccw(pts)
      area = 0.0
      n = pts.size
      n.times do |i|
        j = (i+1)%n
        area += pts[i][0]*pts[j][1] - pts[j][0]*pts[i][1]
      end
      area < 0 ? pts.reverse : pts
    end
  end
end
