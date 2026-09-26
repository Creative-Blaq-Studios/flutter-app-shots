import 'package:app_shots/src/capture_validator.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

List<int> _solidPng(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return img.encodePng(image);
}

List<int> _noisyPng(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = ((x * 7 + y * 13) % 256);
      image.setPixelRgb(x, y, v, (v + 80) % 256, (v + 160) % 256);
    }
  }
  return img.encodePng(image);
}

void main() {
  test('passes when dimensions meet the target and image is not blank', () {
    final result = validateImageBytes(
      bytes: _noisyPng(1320, 2868), targetWidth: 1320, targetHeight: 2868);
    expect(result.passed, isTrue);
    expect(result.warnings, isEmpty);
    expect(result.width, 1320);
  });

  test('warns when the image is below the target size', () {
    final result = validateImageBytes(
      bytes: _noisyPng(1000, 2000), targetWidth: 1320, targetHeight: 2868);
    expect(result.passed, isFalse);
    expect(result.warnings.any((w) => w.contains('below target')), isTrue);
  });

  test('warns when the image looks blank', () {
    final result = validateImageBytes(
      bytes: _solidPng(1320, 2868), targetWidth: 1320, targetHeight: 2868);
    expect(result.warnings.any((w) => w.contains('blank')), isTrue);
  });

  test('blank image with correct dimensions passes (blank is non-failing warning)', () {
    final result = validateImageBytes(
      bytes: _solidPng(1320, 2868), targetWidth: 1320, targetHeight: 2868);
    // blank warning is advisory only — dimensions are the hard pass/fail gate
    expect(result.passed, isTrue);
    expect(result.warnings.any((w) => w.contains('blank')), isTrue);
  });
}
