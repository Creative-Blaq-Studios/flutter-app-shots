// Pure-math unit tests for css_geometry.dart — pinned concrete values per
// the Task B4 brief (no goldens/widgets involved). Values are derived from
// the CSS gradient-line formula ported from backgrounds.ts's 160deg
// gradient recipe: direction d = (sin theta, -cos theta) in screen coords,
// line length L = |W*sin theta| + |H*cos theta|,
// begin = center - d*L/2, end = center + d*L/2.
import 'dart:ui';

import 'package:app_shots_renderer/renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cssLinearGradientLine', () {
    test('0deg: gradient line points straight up (begin at bottom, end at top)', () {
      final line = cssLinearGradientLine(0, const Size(100, 200));
      expect(line.begin.dx, closeTo(50, 1e-9));
      expect(line.begin.dy, closeTo(200, 1e-9));
      expect(line.end.dx, closeTo(50, 1e-9));
      expect(line.end.dy, closeTo(0, 1e-9));
    });

    test('90deg: gradient line points straight right (begin at left, end at right)', () {
      final line = cssLinearGradientLine(90, const Size(100, 200));
      expect(line.begin.dx, closeTo(0, 1e-9));
      expect(line.begin.dy, closeTo(100, 1e-9));
      expect(line.end.dx, closeTo(100, 1e-9));
      expect(line.end.dy, closeTo(100, 1e-9));
    });

    test('160deg on a square: line length is 128.17 +/- 0.01, and the line '
        'is symmetric about the center with end below-right of begin', () {
      const size = Size(100, 100);
      final line = cssLinearGradientLine(160, size);
      final center = Offset(size.width / 2, size.height / 2);

      final length = (line.end - line.begin).distance;
      expect(length, closeTo(128.17, 0.01));

      // Symmetric about the center.
      final midpoint = Offset(
        (line.begin.dx + line.end.dx) / 2,
        (line.begin.dy + line.end.dy) / 2,
      );
      expect(midpoint.dx, closeTo(center.dx, 1e-9));
      expect(midpoint.dy, closeTo(center.dy, 1e-9));

      // end is below-and-right of begin for a 160deg CSS angle.
      expect(line.end.dx, greaterThan(line.begin.dx));
      expect(line.end.dy, greaterThan(line.begin.dy));
    });
  });

  group('colorFromHex', () {
    test('parses a 6-digit hex string as an opaque Color', () {
      expect(colorFromHex('#0F172A'), equals(const Color(0xFF0F172A)));
      expect(colorFromHex('#38BDF8'), equals(const Color(0xFF38BDF8)));
    });

    test('throws FormatException on non-hex or malformed input', () {
      expect(() => colorFromHex('not-a-color'), throwsFormatException);
      expect(() => colorFromHex('#12345'), throwsFormatException); // too short
      expect(() => colorFromHex('#1234567'), throwsFormatException); // too long
      expect(() => colorFromHex('0F172A'), throwsFormatException); // missing '#'
      expect(() => colorFromHex('#GGGGGG'), throwsFormatException); // non-hex digits
    });
  });
}
