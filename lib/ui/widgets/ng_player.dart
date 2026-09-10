import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';

/// Части флеш-плеера Newgrounds 2015 — блок `.ngp` из `render.js`.
///
///   .ngp          → [NgPlayerFrame]
///   .ngp-viz      → [NgVizPanel]
///   .ngp-bar      → [NgPlayerBar]
///   .ngp-play     → [NgGlyphButton] (NgGlyph.play / NgGlyph.pause)
///   .ngp-time     → [NgTimeLabel]
///   .ngp-seek     → [NgSeekBar]
///
/// Все глифы рисуются вручную: в спрайте `a-15yellows.png` транспорта нет,
/// а в CSS плеера они собраны из border/линейных градиентов цвета `#fc0`.

// ── Глифы транспорта ──────────────────────────────────────────────────────────

enum NgGlyph { play, pause, prev, next, shuffle, repeat, repeatOne, chevronDown }

class NgGlyphIcon extends StatelessWidget {
  final NgGlyph glyph;
  final Color color;
  final double size;

  /// `.ngp-play { width:22px; height:24px }` — глиф чуть выше, чем шире.
  const NgGlyphIcon(this.glyph, {super.key, this.color = ngPlayerYellow, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GlyphPainter(glyph, color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final NgGlyph glyph;
  final Color color;
  const _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.6, w * 0.11)
      ..strokeCap = StrokeCap.butt;

    Path tri(double x1, double y1, double x2, double y2, double x3, double y3) =>
        Path()
          ..moveTo(x1 * w, y1 * h)
          ..lineTo(x2 * w, y2 * h)
          ..lineTo(x3 * w, y3 * h)
          ..close();

    void rect(double l, double t, double r, double b) =>
        canvas.drawRect(Rect.fromLTRB(l * w, t * h, r * w, b * h), fill);

    switch (glyph) {
      // border-left:16px solid #fc0 + прозрачные 11px сверху/снизу
      case NgGlyph.play:
        canvas.drawPath(tri(0.18, 0.04, 0.18, 0.96, 0.90, 0.50), fill);

      // .playing: две полосы по 5px из 14px ширины
      case NgGlyph.pause:
        rect(0.16, 0.04, 0.42, 0.96);
        rect(0.58, 0.04, 0.84, 0.96);

      case NgGlyph.prev:
        rect(0.06, 0.08, 0.20, 0.92);
        canvas.drawPath(tri(0.96, 0.06, 0.96, 0.94, 0.26, 0.50), fill);

      case NgGlyph.next:
        rect(0.80, 0.08, 0.94, 0.92);
        canvas.drawPath(tri(0.04, 0.06, 0.04, 0.94, 0.74, 0.50), fill);

      case NgGlyph.shuffle:
        _arrow(canvas, size, stroke, fill,
            const Offset(0.08, 0.26), const Offset(0.74, 0.74));
        _arrow(canvas, size, stroke, fill,
            const Offset(0.08, 0.74), const Offset(0.74, 0.26));

      case NgGlyph.repeat:
      case NgGlyph.repeatOne:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(0.12 * w, 0.20 * h, 0.82 * w, 0.80 * h),
            Radius.circular(0.2 * w),
          ),
          stroke,
        );
        // «клюв» потока в правой стенке
        canvas.drawPath(tri(0.68, 0.34, 0.98, 0.34, 0.83, 0.62), fill);
        if (glyph == NgGlyph.repeatOne) {
          final tp = TextPainter(
            text: TextSpan(
              text: '1',
              style: TextStyle(
                color: color,
                fontSize: h * 0.42,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas,
              Offset((w - tp.width) / 2, (h - tp.height) / 2 - h * 0.02));
        }

      case NgGlyph.chevronDown:
        final p = Path()
          ..moveTo(0.16 * w, 0.36 * h)
          ..lineTo(0.50 * w, 0.68 * h)
          ..lineTo(0.84 * w, 0.36 * h);
        canvas.drawPath(p, stroke);
    }
  }

  /// Линия со стрелкой на конце; координаты нормированы 0..1.
  void _arrow(Canvas canvas, Size size, Paint stroke, Paint fill, Offset from,
      Offset to) {
    Offset px(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
    canvas.drawLine(px(from), px(to), stroke);

    final d = (to - from);
    final len = d.distance;
    if (len == 0) return;
    final dir = Offset(d.dx / len, d.dy / len);
    final perp = Offset(-dir.dy, dir.dx);
    const head = 0.22;
    const half = 0.13;
    final tip = to + dir * head;
    final a = to + perp * half;
    final b = to - perp * half;
    canvas.drawPath(
      Path()
        ..moveTo(px(tip).dx, px(tip).dy)
        ..lineTo(px(a).dx, px(a).dy)
        ..lineTo(px(b).dx, px(b).dy)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// Кнопка транспорта: глиф `#fc0`, белый при нажатии (`.ngp-play:hover`),
/// серый когда выключена или неактивна.
class NgGlyphButton extends StatefulWidget {
  final NgGlyph glyph;
  final VoidCallback? onTap;
  final double glyphSize;

  /// Размер области нажатия — на телефоне глиф маленький, палец большой.
  final double hitSize;

  /// Для режимных кнопок (shuffle/repeat): выключенный режим — серый глиф.
  final bool active;
  final String? tooltip;

  const NgGlyphButton({
    super.key,
    required this.glyph,
    this.onTap,
    this.glyphSize = 22,
    this.hitSize = 44,
    this.active = true,
    this.tooltip,
  });

  @override
  State<NgGlyphButton> createState() => _NgGlyphButtonState();
}

class _NgGlyphButtonState extends State<NgGlyphButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = !enabled
        ? ngDimmer
        : _down
            ? ngWhite
            : widget.active
                ? ngPlayerYellow
                : ngDim;

    Widget child = SizedBox(
      width: widget.hitSize,
      height: widget.hitSize,
      child: Center(
        child: NgGlyphIcon(widget.glyph, color: color, size: widget.glyphSize),
      ),
    );
    if (widget.tooltip != null) {
      child = Tooltip(message: widget.tooltip!, child: child);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: child,
    );
  }
}

// ── Корпус плеера ─────────────────────────────────────────────────────────────

/// `.ngp { background:#000; border:1px solid #2a2724; border-radius:2px }`
class NgPlayerFrame extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets margin;

  const NgPlayerFrame({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border.fromBorderSide(BorderSide(color: Color(0xFF2A2724))),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// `.ngp-bar { height:44px; background:linear-gradient(#242220,#141210);
/// border-top:1px solid #000; gap:10px; padding:0 12px }`
class NgPlayerBar extends StatelessWidget {
  final List<Widget> children;
  final double height;
  final EdgeInsets padding;
  final MainAxisAlignment alignment;
  final bool topBorder;

  const NgPlayerBar({
    super.key,
    required this.children,
    this.height = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.alignment = MainAxisAlignment.start,
    this.topBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ngPlayerBarTop, ngPlayerBarBot],
        ),
        border: topBorder
            ? const Border(top: BorderSide(color: ngBlack))
            : null,
      ),
      child: Row(mainAxisAlignment: alignment, children: children),
    );
  }
}

/// `.ngp-time { color:#fc0 }`, текущая позиция — белая (`.ngp-cur`).
class NgTimeLabel extends StatelessWidget {
  final Duration position;
  final Duration? duration;
  final double fontSize;

  const NgTimeLabel({
    super.key,
    required this.position,
    this.duration,
    this.fontSize = 12,
  });

  static String fmt(Duration? d) {
    if (d == null) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: ngPlayerYellow,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        children: [
          TextSpan(
            text: fmt(position),
            style: const TextStyle(color: ngWhite),
          ),
          const TextSpan(text: ' / '),
          TextSpan(text: fmt(duration)),
        ],
      ),
    );
  }
}

/// `.ngp-seek` + `.ngp-seek-fill`: полосатая заливка под 45°, тянется мышью.
/// На телефоне бар высотой 14px, но зона нажатия расширена по вертикали.
class NgSeekBar extends StatefulWidget {
  /// 0..1, живая позиция.
  final double value;

  /// Ушёл палец — отдаём долю 0..1.
  final ValueChanged<double>? onSeek;

  /// Трек ещё грузится: полоски бегут вместо позиции.
  final bool loading;
  final double height;

  const NgSeekBar({
    super.key,
    required this.value,
    this.onSeek,
    this.loading = false,
    this.height = 14,
  });

  @override
  State<NgSeekBar> createState() => _NgSeekBarState();
}

class _NgSeekBarState extends State<NgSeekBar>
    with SingleTickerProviderStateMixin {
  double? _drag;
  double _width = 1;

  late final AnimationController _run = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(NgSeekBar old) {
    super.didUpdateWidget(old);
    _syncRunner();
  }

  @override
  void initState() {
    super.initState();
    _syncRunner();
  }

  void _syncRunner() {
    if (widget.loading && !_run.isAnimating) {
      _run.repeat();
    } else if (!widget.loading && _run.isAnimating) {
      _run.stop();
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  void _set(double dx) => setState(() => _drag = (dx / _width).clamp(0.0, 1.0));

  void _commit() {
    final v = _drag;
    setState(() => _drag = null);
    if (v != null) widget.onSeek?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onSeek != null && !widget.loading;
    return LayoutBuilder(builder: (_, c) {
      _width = c.maxWidth <= 0 ? 1 : c.maxWidth;
      final bar = widget.loading
          ? AnimatedBuilder(
              animation: _run,
              builder: (_, __) => NgStripedSeek(
                value: 1,
                height: widget.height,
                phase: -_run.value * 16,
              ),
            )
          : NgStripedSeek(
              value: _drag ?? widget.value,
              height: widget.height,
              knob: _drag != null,
            );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (d) => _set(d.localPosition.dx) : null,
        onTapUp: enabled ? (_) => _commit() : null,
        onTapCancel: enabled ? () => setState(() => _drag = null) : null,
        onHorizontalDragStart: enabled ? (d) => _set(d.localPosition.dx) : null,
        onHorizontalDragUpdate:
            enabled ? (d) => _set(d.localPosition.dx) : null,
        onHorizontalDragEnd: enabled ? (_) => _commit() : null,
        child: Padding(
          // зона нажатия ~40px по вертикали, сам бар остаётся 14px
          padding: EdgeInsets.symmetric(vertical: (40 - widget.height) / 2),
          child: bar,
        ),
      );
    });
  }
}

/// Сам полосатый бар без жестов: `.ngp-seek` с `.ngp-seek-fill` внутри.
class NgStripedSeek extends StatelessWidget {
  final double value;
  final double height;
  final double phase;

  /// Метка позиции при перетаскивании.
  final bool knob;

  const NgStripedSeek({
    super.key,
    required this.value,
    this.height = 14,
    this.phase = 0,
    this.knob = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: ngBlack,
        border: Border.fromBorderSide(BorderSide(color: ngSeekBorder)),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _SeekPainter(value.clamp(0.0, 1.0), phase, knob),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SeekPainter extends CustomPainter {
  final double value;
  final double phase;
  final bool knob;
  const _SeekPainter(this.value, this.phase, this.knob);

  static const _band = 8.0; // ширина полосы из CSS

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * value;
    if (w > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, size.height),
          Paint()..color = ngPlayerStripe);

      final paint = Paint()..color = ngPlayerYellow;
      const step = _band * 2;
      final start = -size.height - (phase % step);
      for (double x = start; x < w + size.height; x += step) {
        canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + _band, size.height)
            ..lineTo(x + _band + size.height, 0)
            ..lineTo(x + size.height, 0)
            ..close(),
          paint,
        );
      }
      canvas.restore();
    }
    if (knob) {
      canvas.drawRect(
        Rect.fromLTWH(math.max(0, w - 2), 0, 3, size.height),
        Paint()..color = ngWhite,
      );
    }
  }

  @override
  bool shouldRepaint(_SeekPainter old) =>
      old.value != value || old.phase != phase || old.knob != knob;
}

// ── Визуализатор ──────────────────────────────────────────────────────────────

/// `.ngp-viz { radial-gradient(ellipse at 50% 40%, #241a2e, #14101c 55%, #0a0810) }`
/// — тёмная «сцена» плеера: обложка по центру, столбики и подписи снизу.
class NgVizPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const NgVizPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [ngVizTop, ngVizMid, ngVizBot],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Столбики визуализатора: прямоугольные, от жёлтого к оранжевому.
/// Настоящего спектра у нас нет, поэтому это тот же «фейк», что в 2015 flash.
class NgVizBars extends StatefulWidget {
  final bool active;
  final double height;
  final double opacity;

  const NgVizBars({
    super.key,
    required this.active,
    this.height = 48,
    this.opacity = 1,
  });

  @override
  State<NgVizBars> createState() => _NgVizBarsState();
}

class _NgVizBarsState extends State<NgVizBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Opacity(
        opacity: widget.opacity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _VizPainter(_c.value, widget.active),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _VizPainter extends CustomPainter {
  final double t;
  final bool active;
  static const _bars = 28;

  const _VizPainter(this.t, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final barW = size.width / _bars;
    const gap = 2.0;

    for (var i = 0; i < _bars; i++) {
      final phase = i / _bars * 2 * math.pi;
      final h = (active
              ? (0.35 +
                      0.30 * math.sin(t * 2 * math.pi + phase) +
                      0.20 * math.sin(t * 3.7 * math.pi + phase * 1.3) +
                      0.12 * math.sin(t * 6 * math.pi + phase * 0.8))
                  .clamp(0.08, 1.0)
              : 0.12 + 0.06 * math.sin(phase * 2.5 + t * math.pi * 0.5)) *
          size.height;

      final color = Color.lerp(
          ngPlayerYellow, ngOrangeDeep, i / (_bars - 1))!;
      canvas.drawRect(
        Rect.fromLTWH(i * barW + gap / 2, size.height - h, barW - gap, h),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_VizPainter old) => old.t != t || old.active != active;
}

/// Обложка без рамок и свечений: тянется на весь выделенный ей квадрат.
/// [urls] — кандидаты от лучшего качества к худшему (`_raw.png` → `_raw.jpg` →
/// `_full.webp` → превью): каждый следующий подхватывается, если предыдущий
/// отдал 404.
class NgArtImage extends StatelessWidget {
  final List<String> urls;

  const NgArtImage({super.key, required this.urls});

  @override
  Widget build(BuildContext context) => _cascade(urls, 0);

  static Widget _cascade(List<String> urls, int i) {
    if (i >= urls.length || urls[i].isEmpty) {
      return Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: urls[i],
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, __, ___) => _cascade(urls, i + 1),
      placeholder: (_, __) => const ColoredBox(color: ngPodBg),
    );
  }
}

/// Обложка в рамке 2015: квадрат, чёрная рамка 4px, золотая линия внутри.
/// Обложка заливает всю площадь; [urls] — кандидаты от лучшего качества
/// к худшему (`_raw.png` → `_raw.jpg` → `_full.webp` → превью): каждый следующий
/// подхватывается, если предыдущий отдал 404.
class NgArtFrame extends StatelessWidget {
  final List<String> urls;
  final double size;

  const NgArtFrame({super.key, required this.urls, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: ngPodBg,
        border: Border.fromBorderSide(BorderSide(color: ngBlack, width: 4)),
        boxShadow: [BoxShadow(color: ngBlack, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: DecoratedBox(
        // золотая линия внутри рамки, как у превью в `.itemdetails`
        decoration: const BoxDecoration(
          border: Border.fromBorderSide(BorderSide(color: ngBrown)),
        ),
        child: _cascade(0),
      ),
    );
  }

  Widget _cascade(int i) {
    if (i >= urls.length || urls[i].isEmpty) {
      return Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: urls[i],
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, __, ___) => _cascade(i + 1),
      placeholder: (_, __) => const ColoredBox(color: ngPodBg),
    );
  }
}

// ── Сцена плеера ──────────────────────────────────────────────────────────

/// Компактный `.ngp`: бар со временем и сикбаром плюс бар транспорта.
/// Обложка, название и автор живут в шапке пода и в Credits & Info —
/// дублировать их внутри плеера незачем.
///
/// Данные приходят снаружи — виджет ничего не знает о вьюмодели, поэтому его
/// можно поднять в тесте.
class NgPlayerStage extends StatelessWidget {
  /// Кандидаты обложки (см. `Track.artworkUrls`). Пустой список — без обложки.
  final List<String> artUrls;

  final bool playing;
  final bool loading;
  final Duration position;
  final Duration? duration;

  final bool shuffle;

  /// 0 — выкл, 1 — весь список, 2 — один трек.
  final int repeat;

  final VoidCallback? onPlayPause;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onShuffle;
  final VoidCallback? onRepeat;
  final ValueChanged<Duration>? onSeek;

  /// Явная высота обложки (ландшафт: остаток высоты сцены); null — квадрат
  /// по ширине сцены, как в портрете.
  final double? artHeight;

  const NgPlayerStage({
    super.key,
    this.artUrls = const [],
    this.playing = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration,
    this.shuffle = false,
    this.repeat = 0,
    this.onPlayPause,
    this.onPrev,
    this.onNext,
    this.onShuffle,
    this.onRepeat,
    this.onSeek,
    this.artHeight,
  });

  @override
  Widget build(BuildContext context) {
    final total = duration?.inMilliseconds ?? 0;
    final value = total > 0 ? position.inMilliseconds / total : 0.0;

    return NgPlayerFrame(
      children: [
        // Обложка во всю ширину блока, без свечений и рамок — рамку даёт сам `.ngp`.
        // artHeight задаёт точную высоту: сцена не должна ни раздуваться, ни резаться.
        if (artUrls.isNotEmpty)
          artHeight != null
              ? SizedBox(
                  height: artHeight,
                  child: NgArtImage(urls: artUrls),
                )
              : AspectRatio(
                  aspectRatio: 1,
                  child: NgArtImage(urls: artUrls),
                ),

        // `.ngp-bar` — время и полосатый сикбар
        NgPlayerBar(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          topBorder: artUrls.isNotEmpty,
          children: [
            SizedBox(
              // `.ngp-time { min-width:92px }`
              width: 92,
              child: NgTimeLabel(position: position, duration: duration),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NgSeekBar(
                value: value,
                loading: loading,
                onSeek: total > 0 && onSeek != null
                    ? (v) =>
                        onSeek!(Duration(milliseconds: (v * total).round()))
                    : null,
              ),
            ),
          ],
        ),

        // Весь транспорт в одном ряду, play по центру
        NgPlayerBar(
          height: 48,
          alignment: MainAxisAlignment.spaceEvenly,
          children: [
            NgGlyphButton(
              glyph: NgGlyph.shuffle,
              glyphSize: 19,
              active: shuffle,
              tooltip: 'Shuffle',
              onTap: onShuffle,
            ),
            NgGlyphButton(
              glyph: NgGlyph.prev,
              glyphSize: 20,
              tooltip: 'Previous',
              onTap: onPrev,
            ),
            NgGlyphButton(
              glyph: playing ? NgGlyph.pause : NgGlyph.play,
              glyphSize: 26,
              hitSize: 46,
              tooltip: playing ? 'Pause' : 'Play',
              onTap: loading ? null : onPlayPause,
            ),
            NgGlyphButton(
              glyph: NgGlyph.next,
              glyphSize: 20,
              tooltip: 'Next',
              onTap: onNext,
            ),
            NgGlyphButton(
              glyph: repeat == 2 ? NgGlyph.repeatOne : NgGlyph.repeat,
              glyphSize: 19,
              active: repeat > 0,
              tooltip: 'Repeat',
              onTap: onRepeat,
            ),
          ],
        ),
      ],
    );
  }
}

