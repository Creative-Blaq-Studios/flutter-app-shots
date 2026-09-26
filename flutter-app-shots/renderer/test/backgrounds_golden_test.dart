// Golden self-tests for the four CSS background recipes, ported verbatim
// from backgrounds.ts's `backgroundCss()`. Each style is painted at
// the same 300x600 canvas with the `professional` tone palette and accent
// `#38BDF8`, matching the fixed reference PNG in `goldens/`.
//
// Generate/update with `flutter test --update-goldens`, then re-run without
// the flag — a passing second run is the proof that painting is
// deterministic (no randomness, no animation, no float-noise across runs).
import 'dart:typed_data';
import 'dart:ui' as ui;

// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';
import 'package:app_shots_renderer/renderer.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _canvasSize = Size(300, 600);

void main() {
  final palette = paletteFor(Tone.professional, '#38BDF8');

  for (final style in [
    solid,
    gradient,
    brandBlock,
    softShapes,
    mesh,
    spotlight,
    boldDiagonal,
    dots,
  ]) {
    testWidgets('bg_$style matches golden at ${_canvasSize.width.toInt()}x'
        '${_canvasSize.height.toInt()}', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: ComposeBackgroundWidget(style: style, palette: palette),
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(RepaintBoundary),
        matchesGoldenFile('goldens/bg_$style.png'),
      );
    });
  }

  testWidgets('painting the same style twice produces byte-identical output '
      '(determinism, independent of the golden-file mechanism)', (tester) async {
    // toImage/toByteData do real async rasterization work, which never
    // completes inside flutter_test's fake-async zone — they must run under
    // tester.runAsync (same Plan A discipline as precacheImage).
    Future<Uint8List> renderOnce() async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: _canvasSize.width,
                height: _canvasSize.height,
                child: ComposeBackgroundWidget(
                    style: softShapes, palette: palette),
              ),
            ),
          ),
        ),
      );
      final bytes = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    final first = await renderOnce();
    // Tear the tree down fully between renders so the second render paints
    // a fresh layer tree rather than reusing the first one's raster.
    await tester.pumpWidget(const SizedBox.shrink());
    final second = await renderOnce();
    expect(first, equals(second));
  });
}
