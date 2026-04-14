# encoding: UTF-8
# Построитель ячеек (камней) кладки
# Версия 4: Shim-архитектура + CellSpec с x_left/x_right (без зазоров гарантировано)

module PolygonalMasonry
  class CellBuilder
    StoneCell = Struct.new(:points2d, :kind)

    # Shim — вертикальный шов между двумя камнями.
    # Три точки: верх [x, y_top] → середина [x+dx, y_mid] → низ [x, y_bot].
    # Оба соседних камня используют ОДИН и тот же Shim-объект → нет зазоров.
    Shim = Struct.new(:x, :y_top, :x_mid, :y_mid, :y_bot) do
      def top_pt; [x,     y_top]; end
      def mid_pt; [x_mid, y_mid]; end
      def bot_pt; [x,     y_bot]; end
    end

    def initialize(rows, row_nodes, params, rng)
      @rows      = rows
      @row_nodes = row_nodes
      @params    = params
      @rng       = rng
    end

    # Основной метод для pipeline v0.2+
    def build_from_specs(band_idx, specs)
      build_band_v4(band_idx, specs)
    end

    # Совместимость
    def build_all
      all_cells = []
      (@rows.size - 1).times do |band_idx|
        all_cells.concat(build_band_v4(band_idx, nil))
      end
      all_cells
    end

    # Вставка замковых камней (публичный метод — вызывается из pipeline)
    def insert_key_stones(cells)
      key_ratio = @params[:key_stone_ratio] || 0.15
      n_bands   = @rows.size - 1
      return cells if n_bands < 2

      result = cells.dup

      (1...n_bands).each do |seam_idx|
        seam_nodes = @row_nodes[seam_idx]
        next if seam_nodes.size < 3

        inner_nodes = seam_nodes[1..-2]
        inner_nodes.each do |node|
          next if @rng.rand > key_ratio

          idx    = seam_nodes.index(node)
          x_prev = seam_nodes[idx - 1].x
          x_next = seam_nodes[idx + 1].x

          half_w_left  = (node.x - x_prev) * (@rng.rand * 0.25 + 0.30)
          half_w_right = (x_next - node.x) * (@rng.rand * 0.25 + 0.30)

          kx_left  = node.x - half_w_left
          kx_right = node.x + half_w_right

          top_curve = @rows[seam_idx - 1]
          bot_curve = @rows[seam_idx + 1]

          x_samples = linspace(kx_left, kx_right, 4)
          top_pts   = x_samples.map { |x| [x, top_curve.y_at(x)] }
          bot_pts   = x_samples.map { |x| [x, bot_curve.y_at(x)] }.reverse
          key_pts   = Geom2D.ensure_ccw(top_pts + bot_pts)

          area = Geom2D.polygon_area(key_pts).abs
          next if area < (@params[:min_area] || 0.001) * 1.5

          new_result = []
          result.each do |cell|
            next if cell.kind == :key
            trimmed = subtract_key_stone(cell.points2d, key_pts)
            if trimmed.nil? || trimmed.size < 3
              next
            elsif trimmed.equal?(cell.points2d)
              new_result << cell
            else
              area2 = Geom2D.polygon_area(trimmed).abs
              next if area2 < (@params[:min_area] || 0.001) * 0.3
              new_result << StoneCell.new(trimmed, :normal)
            end
          end
          new_result << StoneCell.new(key_pts, :key)
          result = new_result
        end
      end

      result
    end

    private

    # ---------------------------------------------------------------
    # ЯДРО: построение одной полосы БЕЗ ЗАЗОРОВ
    # ---------------------------------------------------------------
    def build_band_v4(band_idx, specs)
      top_curve = @rows[band_idx]
      bot_curve = @rows[band_idx + 1]
      top_nodes = @row_nodes[band_idx]
      bot_nodes = @row_nodes[band_idx + 1]

      # Если specs не переданы — строим 1:1 из объединённых x
      specs ||= make_default_specs(top_nodes, bot_nodes)
      return [] if specs.empty?

      # ШАГ 1: Собрать все уникальные x-позиции (из x_left/x_right спецификаций)
      # Используем x_left/x_right если CellSpec имеет их (новый SeamMatcher),
      # иначе — top/bot узлы (старый формат).
      all_xs = collect_xs(specs, top_nodes, bot_nodes)

      # ШАГ 2: Для каждого x создать Shim (один раз, jitter фиксирован)
      shims = build_shims(all_xs, top_curve, bot_curve)

      # ШАГ 3: Построить камни
      cells = []
      specs.each do |spec|
        x_l, x_r = spec_x_bounds(spec, top_nodes, bot_nodes)
        next if x_r <= x_l + 1e-8

        shim_l = snap_shim(shims, x_l)
        shim_r = snap_shim(shims, x_r)
        next unless shim_l && shim_r

        # Промежуточные x для следования кривым (только внутри [x_l, x_r])
        inner_top = nodes_inner_xs(top_nodes, spec.top_from, spec.top_to, x_l, x_r)
        inner_bot = nodes_inner_xs(bot_nodes, spec.bot_from, spec.bot_to, x_l, x_r)

        pts = build_stone_pts(shim_l, shim_r, top_curve, bot_curve,
                              x_l, x_r, inner_top, inner_bot)
        next unless pts && pts.size >= 3

        area = Geom2D.polygon_area(pts).abs
        next if area < (@params[:min_area] || 0.001)

        kind = (spec.kind == :normal || spec.kind.nil?) ? :normal : spec.kind
        cells << StoneCell.new(pts, kind)
      end

      cells
    end

    # Возвращает все уникальные x-позиции для построения шимов
    def collect_xs(specs, top_nodes, bot_nodes)
      xs = []
      specs.each do |spec|
        x_l, x_r = spec_x_bounds(spec, top_nodes, bot_nodes)
        xs << x_l
        xs << x_r
        # Промежуточные узлы тоже добавляем в шимы (для точного следования кривым)
        xs.concat(top_nodes[spec.top_from..spec.top_to].map(&:x))
        xs.concat(bot_nodes[spec.bot_from..spec.bot_to].map(&:x))
      end
      xs.uniq.sort
    end

    # Извлекает x_left и x_right из CellSpec.
    # Поддерживает новый формат (с x_left/x_right) и старый (только индексы).
    def spec_x_bounds(spec, top_nodes, bot_nodes)
      if spec.respond_to?(:x_left) && spec.x_left
        [spec.x_left, spec.x_right]
      else
        x_l = [top_nodes[spec.top_from].x, bot_nodes[spec.bot_from].x].min
        x_r = [top_nodes[spec.top_to  ].x, bot_nodes[spec.bot_to  ].x].max
        [x_l, x_r]
      end
    end

    # Находит ближайший Shim к заданному x
    def snap_shim(shims, x)
      key = shims.keys.min_by { |k| (k - x).abs }
      # Допуск: 10% от диапазона всех шимов или минимум 2 дюйма
      range = shims.keys.size > 1 ? (shims.keys.max - shims.keys.min) * 0.10 : 2.0
      tol   = [range, 2.0].max
      return nil unless key && (key - x).abs < tol
      shims[key]
    end

    # Промежуточные x из узлов, строго внутри (x_l, x_r)
    def nodes_inner_xs(nodes, from_idx, to_idx, x_l, x_r)
      nodes[from_idx..to_idx].map(&:x)
               .select { |x| x > x_l + 1e-8 && x < x_r - 1e-8 }
    end

    # Создаёт Shim для каждого x — jitter вычисляется ОДИН РАЗ
    def build_shims(xs, top_curve, bot_curve)
      jitter = @params[:seam_jitter] || 0.0
      result = {}
      xs.each do |x|
        y_top = top_curve.y_at(x)
        y_bot = bot_curve.y_at(x)
        mid   = (y_top + y_bot) * 0.5
        dy    = (@rng.rand * 2 - 1) * jitter * 0.4
        dx    = (@rng.rand * 2 - 1) * jitter * 0.10
        result[x] = Shim.new(x, y_top, x + dx, mid + dy, y_bot)
      end
      result
    end

    # Строит CCW-контур камня из двух Shim и двух кривых.
    #
    # Контур:
    #   top_left.top_pt
    #   → [inner_top_pts]
    #   → top_right.top_pt
    #   → top_right.mid_pt  (излом правого шва)
    #   → top_right.bot_pt
    #   → [inner_bot_pts в обратном порядке]
    #   → top_left.bot_pt
    #   → top_left.mid_pt   (излом левого шва)
    #   (замкнуто)
    def build_stone_pts(left_shim, right_shim, top_curve, bot_curve,
                        x_l, x_r, inner_top_xs, inner_bot_xs)
      # Верхняя граница (слева → вправо)
      top_xs = ([x_l] + inner_top_xs + [x_r]).uniq.sort
      top_pts = top_xs.map { |x| [x, top_curve.y_at(x)] }

      # Нижняя граница (справа → влево)
      bot_xs = ([x_l] + inner_bot_xs + [x_r]).uniq.sort.reverse
      bot_pts = bot_xs.map { |x| [x, bot_curve.y_at(x)] }

      # Правый шов: вставляем только mid_pt (top и bot уже есть в top_pts/bot_pts)
      r_mid = right_shim.mid_pt
      # Левый шов: вставляем только mid_pt
      l_mid = left_shim.mid_pt

      pts = top_pts + [r_mid] + bot_pts + [l_mid]
      pts = remove_adjacent_dups(pts)
      return nil if pts.size < 3

      Geom2D.ensure_ccw(pts)
    end

    def remove_adjacent_dups(pts)
      result = []
      pts.each do |p|
        next if result.last &&
                (result.last[0] - p[0]).abs < 1e-7 &&
                (result.last[1] - p[1]).abs < 1e-7
        result << p
      end
      if result.size > 1
        f = result.first; l = result.last
        result.pop if (f[0]-l[0]).abs < 1e-7 && (f[1]-l[1]).abs < 1e-7
      end
      result
    end

    # Строит спеки 1:1 из объединённых x-узлов (fallback)
    def make_default_specs(top_nodes, bot_nodes)
      all_x = (top_nodes.map(&:x) + bot_nodes.map(&:x)).uniq.sort
      min_w = @params[:min_stone_width] || 0
      # Создаём структуру совместимую с новым CellSpec (с x_left/x_right)
      spec_klass = Struct.new(:x_left, :x_right, :top_from, :top_to,
                              :bot_from, :bot_to, :kind)
      specs = []
      all_x.each_cons(2) do |x_l, x_r|
        next if (x_r - x_l) < min_w * 0.5
        ti_l = nearest_idx(top_nodes, x_l)
        ti_r = nearest_idx(top_nodes, x_r)
        bi_l = nearest_idx(bot_nodes, x_l)
        bi_r = nearest_idx(bot_nodes, x_r)
        specs << spec_klass.new(x_l, x_r, ti_l, ti_r, bi_l, bi_r, :normal)
      end
      specs
    end

    def nearest_idx(nodes, x)
      best_i = 0; best_d = (nodes[0].x - x).abs
      nodes.each_with_index do |n, i|
        d = (n.x - x).abs
        if d < best_d; best_d = d; best_i = i; end
      end
      best_i
    end

    # --- Вычитание замкового камня ---

    def subtract_key_stone(subject_pts, key_pts)
      s_bb = Geom2D.bbox(subject_pts)
      k_bb = Geom2D.bbox(key_pts)
      no_overlap = s_bb[:xmax] <= k_bb[:xmin] || s_bb[:xmin] >= k_bb[:xmax] ||
                   s_bb[:ymax] <= k_bb[:ymin] || s_bb[:ymin] >= k_bb[:ymax]
      return subject_pts if no_overlap

      all_inside = subject_pts.all? { |p| Geom2D.point_in_polygon?(p, key_pts) }
      return nil if all_inside

      output = subject_pts.dup
      n = key_pts.size
      n.times do |i|
        break if output.empty?
        input  = output; output = []
        a = key_pts[i]; b = key_pts[(i + 1) % n]
        input.size.times do |k|
          curr = input[k]
          prev = input[(k - 1 + input.size) % input.size]
          curr_out = outside?(curr, a, b)
          prev_out = outside?(prev, a, b)
          if curr_out
            unless prev_out
              pt = PolygonClip.send(:line_intersect, prev, curr, a, b)
              output << pt if pt
            end
            output << curr
          elsif prev_out
            pt = PolygonClip.send(:line_intersect, prev, curr, a, b)
            output << pt if pt
          end
        end
      end
      return subject_pts if output.empty?
      output.size >= 3 ? Geom2D.ensure_ccw(output) : subject_pts
    end

    def outside?(pt, a, b)
      (b[0]-a[0])*(pt[1]-a[1]) - (b[1]-a[1])*(pt[0]-a[0]) < 0
    end

    def linspace(a, b, n)
      return [a] if n <= 1
      step = (b - a).to_f / (n - 1)
      (0...n).map { |i| a + i * step }
    end
  end
end
