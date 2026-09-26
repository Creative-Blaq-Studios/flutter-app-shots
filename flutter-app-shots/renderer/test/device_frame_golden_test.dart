// Golden self-tests for [DeviceFrame], geometry ported verbatim from
// deviceFrames.ts.
//
// Generate/update with `flutter test --update-goldens`, then re-run without
// the flag to prove determinism.
import 'dart:typed_data';

import 'package:app_shots_renderer/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A solid-colour 4:3 PNG stand-in for a real screenshot.
Uint8List _solidPng(int w, int h, int r, int g, int b) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  final screenshot = MemoryImage(_solidPng(400, 300, 0x0E, 0x7A, 0x6B));
  const captureKey = ValueKey('capture');

  Widget harness(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          type: MaterialType.transparency,
          child: Center(
            child: RepaintBoundary(key: captureKey, child: child),
          ),
        ),
      );

  Future<void> pumpAndPrecache(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(harness(child));
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();
  }

  testWidgets('iphone_6_9 frame has an island and 12% corner radius',
      (tester) async {
    await pumpAndPrecache(
      tester,
      DeviceFrame(
        screenshot: screenshot,
        widthPx: 300,
        deviceClass: 'iphone_6_9',
      ),
    );
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/frame_iphone_6_9.png'),
    );
  });

  testWidgets('ipad_13 frame has no island and a tighter 4% corner radius',
      (tester) async {
    await pumpAndPrecache(
      tester,
      DeviceFrame(
        screenshot: screenshot,
        widthPx: 300,
        deviceClass: 'ipad_13',
      ),
    );
    await expectLater(
      find.byKey(captureKey),
      matchesGoldenFile('goldens/frame_ipad_13.png'),
    );
  });

  testWidgets('android_phone frame uses a conservative screen corner radius',
      (tester) async {
    await pumpAndPrecache(
      tester,
      DeviceFrame(
        screenshot: screenshot,
        widthPx: 800,
        deviceClass: 'android_phone',
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    final radius = clip.borderRadius as BorderRadius;
    expect(radius.topLeft.x, lessThanOrEqualTo(40));
    expect(radius.topLeft.y, lessThanOrEqualTo(40));
  });

  testWidgets('android_phone shadow is not a directional bottom bezel',
      (tester) async {
    await pumpAndPrecache(
      tester,
      DeviceFrame(
        screenshot: screenshot,
        widthPx: 800,
        deviceClass: 'android_phone',
      ),
    );

    final frame = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color ==
                const Color(0xFF0A0A0A));
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotNull);
    for (final shadow in decoration.boxShadow!) {
      expect(shadow.offset, Offset.zero);
    }
  });

  testWidgets('iphone shadow stays soft and does not read as a bottom bezel',
      (tester) async {
    await pumpAndPrecache(
      tester,
      DeviceFrame(
        screenshot: screenshot,
        widthPx: 800,
        deviceClass: 'iphone_6_9',
      ),
    );

    final frame = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere((container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color ==
                const Color(0xFF0A0A0A));
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.boxShadow, isNotNull);
    for (final shadow in decoration.boxShadow!) {
      expect(shadow.offset.dy.abs(), lessThanOrEqualTo(8));
      expect(shadow.color.a, lessThanOrEqualTo(0.22));
    }
  });
}
