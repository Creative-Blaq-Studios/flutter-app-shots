import 'package:app_shots/src/palette_extractor.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  img.Image solid(int r, int g, int b) {
    final image = img.Image(width: 24, height: 24, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(r, g, b));
    return image;
  }

  group('paletteFromImage', () {
    test('accent is the dominant color of a solid image', () {
      final p = paletteFromImage(solid(32, 96, 160));
      expect(p.accent, '#2060A0');
    });

    test('picks a light-contrasting text color over a dark background', () {
      final p = paletteFromImage(solid(20, 24, 40));
      expect(p.text, '#FFFFFF');
    });

    test('picks a dark-contrasting text color over a light background', () {
      final p = paletteFromImage(solid(245, 245, 245));
      expect(p.text, '#111827');
    });

    test('is deterministic for identical input', () {
      final a = paletteFromImage(solid(200, 40, 60));
      final b = paletteFromImage(solid(200, 40, 60));
      expect(a.accent, b.accent);
      expect(a.bg, b.bg);
      expect(a.bgAlt, b.bgAlt);
      expect(a.text, b.text);
      expect(a.subtext, b.subtext);
    });

    test('falls back to a neutral palette for a fully transparent image', () {
      final transparent = img.Image(width: 8, height: 8, numChannels: 4);
      img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));
      final p = paletteFromImage(transparent);
      expect(p.bg, '#111827');
      expect(p.accent, '#6750A4');
    });
  });
}
