import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ValidationResult {
  final bool passed;
  final List<String> warnings;
  final int width;
  final int height;
  const ValidationResult({
    required this.passed,
    required this.warnings,
    required this.width,
    required this.height,
  });
}

double luminanceVariance(img.Image image, {int sampleStep = 17}) {
  final values = <double>[];
  for (var y = 0; y < image.height; y += sampleStep) {
    for (var x = 0; x < image.width; x += sampleStep) {
      final p = image.getPixel(x, y);
      values.add(0.299 * p.r + 0.587 * p.g + 0.114 * p.b);
    }
  }
  if (values.isEmpty) return 0;
  final mean = values.reduce((a, b) => a + b) / values.length;
  final variance =
      values.map((v) => math.pow(v - mean, 2).toDouble()).reduce((a, b) => a + b) /
          values.length;
  return variance;
}

ValidationResult validateImageBytes({
  required List<int> bytes,
  required int targetWidth,
  required int targetHeight,
  double blankThreshold = 5.0,
}) {
  final image = img.decodeImage(Uint8List.fromList(bytes));
  if (image == null) {
    return const ValidationResult(
        passed: false, warnings: ['could not decode image'], width: 0, height: 0);
  }
  final warnings = <String>[];
  final dimsOk = image.width >= targetWidth && image.height >= targetHeight;
  if (!dimsOk) {
    warnings.add(
        'dimensions ${image.width}x${image.height} are below target '
        '${targetWidth}x$targetHeight (would require upscaling)');
  }
  if (luminanceVariance(image) < blankThreshold) {
    warnings.add('image looks blank or near-empty — bad for marketing');
  }
  return ValidationResult(
    // Dimensions are the hard pass/fail gate; blank is a non-failing warning the agent must honor.
    passed: dimsOk,
    warnings: warnings,
    width: image.width,
    height: image.height,
  );
}
