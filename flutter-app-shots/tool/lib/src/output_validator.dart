// flutter-app-shots/tool/lib/src/output_validator.dart
//
// Store output validation ported verbatim from compositor/src/validateOutput.ts
// with the original warning-message formats and the
// pass/fail boolean expression below is copied verbatim; do not "clean up"
// or rephrase them.
//
// Notable, deliberate asymmetry (ported exactly): the blank-image heuristic
// (summed per-channel stdev < 5) only ever pushes a warning — it never
// participates in `passed`.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'store_specs.dart';

/// The result of validating a composed store-output image against a
/// [StoreTarget]. Ported verbatim from `ValidationResult` in
/// validateOutput.ts (types.ts).
class StoreValidationResult {
  final bool passed;
  final List<String> warnings;
  final int width;
  final int height;
  final bool hasAlpha;

  const StoreValidationResult({
    required this.passed,
    required this.warnings,
    required this.width,
    required this.height,
    required this.hasAlpha,
  });

  Map<String, dynamic> toJson() => {
        'passed': passed,
        'warnings': warnings,
        'width': width,
        'height': height,
        'hasAlpha': hasAlpha,
      };
}

/// Sums per-channel standard deviation across all pixels of [image] (sum,
/// not average, across channels) — ported verbatim from the
/// `stats().channels.reduce((a, c) => a + c.stdev, 0)` aggregation in
/// validateOutput.ts. Computed with a one-pass (Welford) algorithm per
/// channel so large images don't require buffering every sample.
double _totalStdev(img.Image image) {
  final numChannels = image.numChannels;
  final means = List<double>.filled(numChannels, 0);
  final m2s = List<double>.filled(numChannels, 0);
  var n = 0;
  for (final pixel in image) {
    n++;
    for (var c = 0; c < numChannels; c++) {
      final value = pixel[c].toDouble();
      final delta = value - means[c];
      means[c] += delta / n;
      final delta2 = value - means[c];
      m2s[c] += delta * delta2;
    }
  }
  if (n == 0) return 0;
  var total = 0.0;
  for (var c = 0; c < numChannels; c++) {
    // Bessel's correction: divide by (n - 1) for sample stdev.
    // If n <= 1, treat stdev as 0 to avoid division by zero.
    final stdev = n <= 1 ? 0.0 : math.sqrt(m2s[c] / (n - 1));
    total += stdev;
  }
  return total;
}

/// Validates composed store-output [bytes] against [target], ported
/// verbatim from `validateOutput` in validateOutput.ts. [textOverlayFraction]
/// mirrors the optional third argument there (the manifest-stamped estimate
/// of how much of the canvas the text overlay occupies).
///
/// `passed = dimsOk && isPng && !alphaBad && !overlayBad` exactly — the
/// blank-image heuristic is advisory-only and never gates `passed`.
StoreValidationResult validateStoreOutput({
  required List<int> bytes,
  required StoreTarget target,
  double? textOverlayFraction,
}) {
  final data = Uint8List.fromList(bytes);
  final warnings = <String>[];

  final isPng = img.PngDecoder().isValidFile(data);
  final isJpeg = !isPng && img.JpegDecoder().isValidFile(data);
  final format = isPng ? 'png' : (isJpeg ? 'jpeg' : 'unknown');

  final decoded = img.decodeImage(data);
  final width = decoded?.width ?? 0;
  final height = decoded?.height ?? 0;
  // hasAlpha = the decoded image HAS an alpha channel (numChannels == 4),
  // matching sharp's channel-presence semantics — not per-pixel opacity.
  final hasAlpha = decoded != null && decoded.numChannels == 4;

  final dimsOk = width == target.width && height == target.height;
  if (!dimsOk) {
    warnings.add(
        'dimensions ${width}x$height != target ${target.width}x${target.height}');
  }
  if (!isPng) {
    warnings.add('format $format is not png');
  }

  var alphaBad = false;
  if (!target.allowAlpha && hasAlpha) {
    warnings.add('image has an alpha channel but this target forbids alpha');
    alphaBad = true;
  }

  var overlayBad = false;
  if (textOverlayFraction != null &&
      textOverlayFraction > target.textOverlayMaxFraction) {
    final pct = (textOverlayFraction * 100).round();
    final maxPct = (target.textOverlayMaxFraction * 100).round();
    warnings.add('text overlay $pct% exceeds limit $maxPct%');
    overlayBad = true;
  }

  if (decoded != null && _totalStdev(decoded) < 5) {
    warnings.add('image looks blank or near-empty');
  }

  return StoreValidationResult(
    passed: dimsOk && isPng && !alphaBad && !overlayBad,
    warnings: warnings,
    width: width,
    height: height,
    hasAlpha: hasAlpha,
  );
}
