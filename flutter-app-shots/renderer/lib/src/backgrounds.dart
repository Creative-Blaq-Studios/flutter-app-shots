// CSS background recipes, ported verbatim from `backgroundCss()` in
// compositor/src/backgrounds.ts. Every fraction, angle, and alpha-suffix below is copied from that
// source — do not "clean up" or recompute them.
import 'dart:ui' as ui;

// `tool/` deliberately has no public barrel file (see B1) — `Palette` and
// `paletteFor` are consumed straight from their `lib/src` location, per the
// interface contract in the Task B4 brief.
// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';
import 'package:flutter/widgets.dart';

import 'css_geometry.dart';

/// The four CSS background style recipes from `CssBackground['style']` in
/// types.ts, as verbatim strings (matches `ComposeBackground.style` wire
/// values in `tool`'s `compose_specs.dart`).
const solid = 'solid';
const gradient = 'gradient';
const brandBlock = 'brand_block';
const softShapes = 'soft_shapes';

// New expressive recipes (not part of the verbatim TS port — added for the
// layout-variety/fun-backgrounds work). All deterministic; golden-tested.
const mesh = 'mesh';
const spotlight = 'spotlight';
const boldDiagonal = 'bold_diagonal';
const dots = 'dots';

/// Paints one of the four CSS background recipes from backgrounds.ts, given
/// a resolved [palette]. Fills all available space (wrap in a `SizedBox`
/// sized to the target canvas, as the compose harness does).
///
/// Recipes, ported verbatim from `backgroundCss()`:
/// - `solid`: flat fill of `palette.bg`.
/// - `gradient`: `linear-gradient(160deg, bg 0%, bgAlt 100%)`.
/// - `brand_block`: `bg` fill, plus one radial gradient
///   `120% 60% at 50% -10%` from `accent` at alpha `0x33` (20%) fading to
///   transparent at 60%.
/// - `soft_shapes`: `bg` fill, plus two radial gradients:
///   (a) `40% 30% at 15% 20%` from opaque `bgAlt` fading to transparent at
///   60%; (b) `45% 35% at 85% 80%` from `accent` at alpha `0x22` (13.3%)
///   fading to transparent at 60%.
/// - `mesh`: `bg` fill + three overlapping soft radials (accent/bgAlt/accent)
///   → a colorful gradient-mesh field.
/// - `spotlight`: `bg` fill + a large bright top-center radial + an accent
///   glow → dramatic staged light.
/// - `bold_diagonal`: a 135° two-tone linear gradient (bg → accent) with a
///   soft seam → a bold diagonal color block.
/// - `dots`: `bg` fill + a fixed-grid tiling of low-alpha accent dots.
///
/// CSS radial-gradient shorthand `<rx>% <ry>% at <cx>% <cy>%` is
/// radii-then-position: the first pair is the ellipse radii (as fractions
/// of the box), the second pair is the ellipse center (also as fractions,
/// which may be negative or >100% — e.g. `-10%` sits above the top edge).
class ComposeBackgroundWidget extends StatelessWidget {
  const ComposeBackgroundWidget({
    super.key,
    required this.style,
    required this.palette,
  });

  final String style;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BackgroundPainter(style: style, palette: palette),
      size: Size.infinite,
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter({required this.style, required this.palette});

  final String style;
  final Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = colorFromHex(palette.bg);
    final bgAlt = colorFromHex(palette.bgAlt);
    final accent = colorFromHex(palette.accent);

    switch (style) {
      case solid:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        return;

      case gradient:
        final line = cssLinearGradientLine(160, size);
        final shader = ui.Gradient.linear(
          line.begin,
          line.end,
          [bg, bgAlt],
          [0.0, 1.0],
        );
        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
        return;

      case brandBlock:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        paintEllipticalRadial(
          canvas,
          size,
          centerFrac: const Offset(0.5, -0.1),
          rxFrac: 1.2,
          ryFrac: 0.6,
          color: accent.withAlpha(0x33),
        );
        return;

      case softShapes:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        paintEllipticalRadial(
          canvas,
          size,
          centerFrac: const Offset(0.15, 0.2),
          rxFrac: 0.40,
          ryFrac: 0.30,
          color: bgAlt,
        );
        paintEllipticalRadial(
          canvas,
          size,
          centerFrac: const Offset(0.85, 0.8),
          rxFrac: 0.45,
          ryFrac: 0.35,
          color: accent.withAlpha(0x22),
        );
        return;

      case mesh:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        paintEllipticalRadial(canvas, size,
            centerFrac: const Offset(0.15, 0.15),
            rxFrac: 0.55, ryFrac: 0.45, color: accent.withAlpha(0x66));
        paintEllipticalRadial(canvas, size,
            centerFrac: const Offset(0.9, 0.1),
            rxFrac: 0.5, ryFrac: 0.4, color: bgAlt);
        paintEllipticalRadial(canvas, size,
            centerFrac: const Offset(0.5, 0.95),
            rxFrac: 0.6, ryFrac: 0.5, color: accent.withAlpha(0x40));
        return;

      case spotlight:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        paintEllipticalRadial(canvas, size,
            centerFrac: const Offset(0.5, -0.05),
            rxFrac: 1.1, ryFrac: 0.75, color: bgAlt);
        paintEllipticalRadial(canvas, size,
            centerFrac: const Offset(0.5, 0.05),
            rxFrac: 0.5, ryFrac: 0.32, color: accent.withAlpha(0x66));
        return;

      case boldDiagonal:
        final line = cssLinearGradientLine(135, size);
        final shader = ui.Gradient.linear(
          line.begin,
          line.end,
          [bg, bg, accent, accent],
          [0.0, 0.48, 0.52, 1.0],
        );
        canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
        return;

      case dots:
        canvas.drawRect(Offset.zero & size, Paint()..color = bg);
        final spacing = size.width / 12;
        final radius = spacing * 0.12;
        final dotPaint = Paint()..color = accent.withAlpha(0x22);
        for (var y = spacing / 2; y < size.height; y += spacing) {
          for (var x = spacing / 2; x < size.width; x += spacing) {
            canvas.drawCircle(Offset(x, y), radius, dotPaint);
          }
        }
        return;

      default:
        throw ArgumentError.value(style, 'style', 'Unknown background style');
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.palette != palette;
  }
}
