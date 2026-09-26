// Golden self-tests for the six [MarketingCanvas] layouts, geometry ported
// verbatim from templates.ts. Each golden is a 330x717 canvas (quarter-scale iphone_6_9) with the
// `professional` palette and a gradient background. The textOverlayFraction
// assertions tie each rendered layout to the exact validation number
// validateStoreOutput compares against.
//
// Generate/update with `flutter test --update-goldens`, then re-run without
// the flag to prove determinism.
import 'dart:typed_data';

// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';
import 'package:app_shots_renderer/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const _size = Size(330, 717);

Uint8List _solidPng(int w, int h, int r, int g, int b) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(im));
}

ComposeEntry _entry(
  ComposeLayout layout, {
  bool deviceless = false,
  String? subheadline = 'Smart lists that sort themselves',
}) =>
    ComposeEntry(
      id: layout.wire,
      deviceClass: 'iphone_6_9',
      headline: 'Plan your day',
      out: 'unused.png',
      subheadline: subheadline,
      raw: deviceless ? null : 'unused-raw.png',
      tone: Tone.professional,
      layout: layout,
      brandColor: '#38BDF8',
      palette: paletteFor(Tone.professional, '#38BDF8'),
      background: const ComposeBackground(kind: 'css', style: 'gradient'),
      deviceless: deviceless,
    );

void main() {
  final palette = paletteFor(Tone.professional, '#38BDF8');
  final screenshot = MemoryImage(_solidPng(400, 866, 0x0E, 0x7A, 0x6B));
  const captureKey = ValueKey('capture');

  Widget harness(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: captureKey, child: child),
        ),
      );

  Future<void> pumpAndPrecache(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = _size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(child));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  }

  for (final layout in ComposeLayout.values) {
    final deviceless = layout == ComposeLayout.fullBleed;
    testWidgets('${layout.wire} layout matches golden', (tester) async {
      await pumpAndPrecache(
        tester,
        MarketingCanvas(
          entry: _entry(layout, deviceless: deviceless),
          palette: palette,
          targetSize: _size,
          screenshot: deviceless ? null : screenshot,
        ),
      );
      await expectLater(
        find.byKey(captureKey),
        matchesGoldenFile('goldens/layout_${layout.wire}.png'),
      );
    });
  }

  test('textOverlayFraction (with subheadline) matches each layout golden', () {
    // These are the numbers validateStoreOutput checks the composed image's
    // overlay estimate against; the goldens above render the matching layout.
    expect(textOverlayFraction(ComposeLayout.centeredDevice, hasSubheadline: true), 0.24);
    expect(textOverlayFraction(ComposeLayout.textBanner, hasSubheadline: true), 0.26);
    expect(textOverlayFraction(ComposeLayout.featureCallout, hasSubheadline: true), 0.30);
    expect(textOverlayFraction(ComposeLayout.dualDevice, hasSubheadline: true), 0.24);
    expect(textOverlayFraction(ComposeLayout.tiltedDevice, hasSubheadline: true), 0.24);
    expect(textOverlayFraction(ComposeLayout.fullBleed, hasSubheadline: true), 1.0);
  });
}
