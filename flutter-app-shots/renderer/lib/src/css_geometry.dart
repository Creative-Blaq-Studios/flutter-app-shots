// CSS-faithful geometry helpers, ported verbatim from the math implied by
// compositor/src/backgrounds.ts's CSS `linear-gradient()` and
// `radial-gradient()` recipes. These are pure canvas/painting helpers with no dependency on the
// composition data model — `backgrounds.dart` composes them with `Palette`.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

/// The two endpoints of a CSS `linear-gradient()` gradient line.
///
/// [begin] is the 0% stop, [end] is the 100% stop — i.e. paint a
/// [Gradient.linear] (or `LinearGradient`) from [begin] to [end].
typedef GradientLine = ({Offset begin, Offset end});

/// Computes the endpoints of a CSS `linear-gradient(<angleDeg>deg, ...)`
/// gradient line for a box of the given [size], replicating the CSS
/// gradient-line algorithm exactly (not Flutter's `Alignment`-based
/// `LinearGradient`, which has different endpoint semantics).
///
/// CSS angles are measured clockwise from "up" (0deg = to top, 90deg = to
/// right, 180deg = to bottom). In screen coordinates (y grows downward),
/// the unit direction vector pointing "toward" the angle is:
///   d = (sin(theta), -cos(theta))
/// The gradient line's length (the distance the 0%..100% stops must span
/// to cover the whole box in the harshest case, per the CSS spec) is:
///   L = |W * sin(theta)| + |H * cos(theta)|
/// and the line is centered on the box, so:
///   begin = center - d * L/2   (0% stop)
///   end   = center + d * L/2   (100% stop, pointing toward the angle)
GradientLine cssLinearGradientLine(double angleDeg, Size size) {
  final theta = angleDeg * math.pi / 180.0;
  final dx = math.sin(theta);
  final dy = -math.cos(theta);
  final length = (size.width * dx).abs() + (size.height * dy).abs();
  final center = Offset(size.width / 2, size.height / 2);
  final half = length / 2;
  final begin = Offset(center.dx - dx * half, center.dy - dy * half);
  final end = Offset(center.dx + dx * half, center.dy + dy * half);
  return (begin: begin, end: end);
}

/// Paints an elliptical CSS-style `radial-gradient()` onto [canvas],
/// replicating `radial-gradient(<rxFrac*100>% <ryFrac*100>% at <cx> <cy>,
/// color 0%, transparent <fadeStop*100>%)`.
///
/// [centerFrac] is the ellipse center as a fraction of [size] (may be
/// negative or >1, matching CSS's `at -10%` etc.). [rxFrac]/[ryFrac] are the
/// ellipse radii as fractions of [size].width/[size].height respectively.
/// [color] is the 0%-stop color; it fades to fully transparent (alpha 0,
/// same RGB) at [fadeStop] (default 0.6, matching every recipe in
/// backgrounds.ts, which all fade out at 60%), then clamps (CSS's implicit
/// `transparent` beyond the last stop == `TileMode.clamp` holding the last
/// color, which is already fully transparent).
void paintEllipticalRadial(
  Canvas canvas,
  Size size, {
  required Offset centerFrac,
  required double rxFrac,
  required double ryFrac,
  required Color color,
  double fadeStop = 0.6,
}) {
  final center = Offset(size.width * centerFrac.dx, size.height * centerFrac.dy);
  final rx = size.width * rxFrac;
  final ry = size.height * ryFrac;

  // ui.Gradient.radial paints a circle of the given radius around `center`
  // in the *pre-transform* coordinate space; to get an ellipse we paint a
  // unit circle (radius 1) and apply a matrix that translates to `center`,
  // scales by (rx, ry), then translates back — so the gradient's own
  // internal circle-to-ellipse warp happens entirely inside the shader.
  // Built by hand (column-major 4x4, dart:ui's Float64List matrix format)
  // to avoid pulling in a Matrix4 dependency for a single fixed-shape
  // translate*scale*translate composition:
  //   p' = S*(p - center) + center = (rx*p.x + cx*(1-rx), ry*p.y + cy*(1-ry))
  final matrix = Float64List.fromList([
    rx, 0, 0, 0,
    0, ry, 0, 0,
    0, 0, 1, 0,
    center.dx * (1 - rx), center.dy * (1 - ry), 0, 1,
  ]);

  final shader = Gradient.radial(
    center,
    1.0,
    [color, color.withAlpha(0)],
    [0.0, fadeStop],
    TileMode.clamp,
    matrix,
  );

  final paint = Paint()..shader = shader;
  canvas.drawRect(Offset.zero & size, paint);
}

/// Parses a `#RRGGBB` hex color string into an opaque [Color].
///
/// Throws a [FormatException] if [hex] is not exactly `#` followed by 6 hex
/// digits (this is the only form used anywhere in the ported [Palette] /
/// brand-color data — no alpha suffix, no 3-digit shorthand).
Color colorFromHex(String hex) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex);
  if (match == null) {
    throw FormatException('Expected a "#RRGGBB" hex color string', hex);
  }
  final value = int.parse(match.group(1)!, radix: 16);
  return Color(0xFF000000 | value);
}
