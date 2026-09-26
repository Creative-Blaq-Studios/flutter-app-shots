// Loads real fonts before any golden test runs. Trusting Flutter's implicit
// font auto-loading in `flutter test` is a known trap (Plan A lesson) — the
// test harness does not rasterize with the real glyphs unless a FontLoader
// is explicitly awaited first. Paths are hardcoded relative to the package
// root because `cwd` under `flutter test` is the package root (`renderer/`).
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  goldenFileComparator = _SmallRasterDiffComparator(
    Uri.file('${Directory.current.path}/test/flutter_test_config.dart'),
  );
  await _loadFont('Sora', 'fonts/Sora/Sora-Bold.ttf');
  await _loadFont('Inter', 'fonts/Inter/Inter-Regular.ttf');
  await testMain();
}

// Flutter engine updates can move a few antialiased edge pixels. Keep the
// goldens strict about any change larger than eight pixels per image.
class _SmallRasterDiffComparator extends LocalFileComparator {
  _SmallRasterDiffComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final image = img.decodePng(imageBytes);
    final changedPixels = image == null
        ? double.infinity
        : result.diffPercent * image.width * image.height;
    if (result.passed || changedPixels <= 8.01) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}
