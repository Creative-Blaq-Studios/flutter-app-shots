// flutter-app-shots/tool/test/output_validator_test.dart
//
// Ported verbatim from compositor/src/validateOutput.ts.
import 'dart:typed_data';

import 'package:app_shots/src/output_validator.dart';
import 'package:app_shots/src/store_specs.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

StoreTarget _targetFor(String deviceClass) =>
    storeTargets.firstWhere((t) => t.deviceClass == deviceClass);

/// Builds a non-blank RGB(A) fixture image: a smooth gradient so per-channel
/// stdev is comfortably above the blank threshold.
img.Image _gradientImage(int width, int height, {bool alpha = false}) {
  final image = img.Image(
    width: width,
    height: height,
    numChannels: alpha ? 4 : 3,
  );
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final r = (x * 255 / (width - 1)).round();
      final g = (y * 255 / (height - 1)).round();
      final b = ((x + y) * 255 / (width + height - 2)).round();
      if (alpha) {
        image.setPixelRgba(x, y, r, g, b, 255);
      } else {
        image.setPixelRgb(x, y, r, g, b);
      }
    }
  }
  return image;
}

Uint8List _solidPng(int width, int height, {int gray = 128}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, gray, gray, gray);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  group('dimensions', () {
    test('correct-size non-blank RGB image passes with no dimension warning',
        () {
      final target = _targetFor('android_phone');
      final bytes =
          img.encodePng(_gradientImage(target.width, target.height));
      final result =
          validateStoreOutput(bytes: bytes, target: target);
      expect(result.passed, isTrue);
      expect(result.width, target.width);
      expect(result.height, target.height);
      expect(
          result.warnings
              .any((w) => w.startsWith('dimensions') || w.contains('!=')),
          isFalse);
    });

    test('wrong size fails with the verbatim dimensions warning', () {
      final target = _targetFor('android_phone');
      final wrongW = target.width - 100;
      final wrongH = target.height - 100;
      final bytes = img.encodePng(_gradientImage(wrongW, wrongH));
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(result.passed, isFalse);
      expect(
        result.warnings,
        contains(
            'dimensions ${wrongW}x$wrongH != target ${target.width}x${target.height}'),
      );
    });
  });

  group('format', () {
    test('non-PNG bytes (JPEG) fail with the format warning', () {
      final target = _targetFor('android_phone');
      final jpegBytes = img.encodeJpg(
        _gradientImage(target.width, target.height),
        quality: 90,
      );
      final result = validateStoreOutput(bytes: jpegBytes, target: target);
      expect(result.passed, isFalse);
      expect(result.warnings, contains('format jpeg is not png'));
    });

    test('unknown/garbage bytes fail with the "unknown" format warning', () {
      final target = _targetFor('android_phone');
      final garbage = Uint8List.fromList(List.filled(64, 7));
      final result = validateStoreOutput(bytes: garbage, target: target);
      expect(result.passed, isFalse);
      expect(result.warnings, contains('format unknown is not png'));
    });
  });

  group('alpha', () {
    test(
        'RGBA image against feature_graphic (allowAlpha false) fails with the alpha warning',
        () {
      final target = _targetFor('feature_graphic');
      final bytes = img.encodePng(
          _gradientImage(target.width, target.height, alpha: true));
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(result.hasAlpha, isTrue);
      expect(result.passed, isFalse);
      expect(
        result.warnings,
        contains('image has an alpha channel but this target forbids alpha'),
      );
    });

    test('RGBA image against iphone_6_9 (allowAlpha true) passes', () {
      final target = _targetFor('iphone_6_9');
      final bytes = img.encodePng(
          _gradientImage(target.width, target.height, alpha: true));
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(result.hasAlpha, isTrue);
      expect(result.passed, isTrue);
      expect(
        result.warnings
            .contains('image has an alpha channel but this target forbids alpha'),
        isFalse,
      );
    });
  });

  group('text overlay fraction', () {
    test(
        'textOverlayFraction 0.3 vs android_phone (max 0.2) fails with the verbatim overlay warning',
        () {
      final target = _targetFor('android_phone');
      final bytes =
          img.encodePng(_gradientImage(target.width, target.height));
      final result = validateStoreOutput(
        bytes: bytes,
        target: target,
        textOverlayFraction: 0.3,
      );
      expect(result.passed, isFalse);
      expect(
        result.warnings,
        contains('text overlay 30% exceeds limit 20%'),
      );
    });

    test('textOverlayFraction within the limit does not warn or fail', () {
      final target = _targetFor('android_phone');
      final bytes =
          img.encodePng(_gradientImage(target.width, target.height));
      final result = validateStoreOutput(
        bytes: bytes,
        target: target,
        textOverlayFraction: 0.2,
      );
      expect(result.passed, isTrue);
      expect(result.warnings.any((w) => w.contains('text overlay')), isFalse);
    });
  });

  group('blank-image heuristic (advisory only)', () {
    test(
        'a solid-single-color image at correct size warns "looks blank" but still passes',
        () {
      final target = _targetFor('android_phone');
      final bytes = _solidPng(target.width, target.height);
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(
        result.warnings,
        contains('image looks blank or near-empty'),
      );
      // The asymmetry under test: blank is advisory-only, never gates passed.
      expect(result.passed, isTrue);
    });

    test('a non-blank gradient image does not warn about blankness', () {
      final target = _targetFor('android_phone');
      final bytes =
          img.encodePng(_gradientImage(target.width, target.height));
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(
          result.warnings.contains('image looks blank or near-empty'), isFalse);
    });

    test(
        'Bessel stdev (n-1 divisor) causes 2-pixel image to cross blank threshold',
        () {
      // Construct a 2-pixel RGB image with values [0,0,0] and [3,3,3].
      // For 2 pixels per channel:
      //   mean = 1.5
      //   m2 = (0-1.5)² + (3-1.5)² = 2.25 + 2.25 = 4.5
      // Using population stdev (÷2): stdev = sqrt(4.5/2) = 1.5 per channel
      //   total = 1.5 + 1.5 + 1.5 = 4.5 (below 5, warns)
      // Using sample stdev (÷1): stdev = sqrt(4.5/1) ≈ 2.12 per channel
      //   total ≈ 2.12 + 2.12 + 2.12 ≈ 6.36 (above 5, no warn)
      // This test ensures the code uses the sample formula (n-1).
      final image = img.Image(width: 2, height: 1, numChannels: 3);
      image.setPixelRgb(0, 0, 0, 0, 0);
      image.setPixelRgb(1, 0, 3, 3, 3);
      final target = StoreTarget(
        store: 'app_store',
        deviceClass: 'test_2x1',
        width: 2,
        height: 1,
        orientation: 'portrait',
        textOverlayMaxFraction: 0.5,
        allowAlpha: true,
      );
      final bytes = Uint8List.fromList(img.encodePng(image));
      final result = validateStoreOutput(bytes: bytes, target: target);
      // With Bessel correction (n-1), the stdev sum is above 5, so no blank warning.
      expect(result.warnings.contains('image looks blank or near-empty'),
          isFalse,
          reason:
              'Expected no blank warning with sample stdev (Bessel) correction');
    });
  });

  group('StoreValidationResult shape', () {
    test('toJson has exactly the five ValidationResult fields', () {
      final target = _targetFor('android_phone');
      final bytes =
          img.encodePng(_gradientImage(target.width, target.height));
      final result = validateStoreOutput(bytes: bytes, target: target);
      expect(
        result.toJson().keys.toSet(),
        {'passed', 'warnings', 'width', 'height', 'hasAlpha'},
      );
    });
  });
}
