// Manifest-driven compose harness for production store-image rendering.
//
// Run from renderer/ after generating a manifest:
//   flutter test test/compose_test.dart
//
// Override manifest path when needed:
//   flutter test --dart-define=APP_SHOTS_MANIFEST=/abs/path/manifest.json test/compose_test.dart
//
// If the manifest file is absent, this file declares one skipped test so the
// normal renderer suite stays green without requiring fixture outputs.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

// ignore: implementation_imports
import 'package:app_shots/src/compose_specs.dart';
// ignore: implementation_imports
import 'package:app_shots/src/store_specs.dart';
import 'package:app_shots_renderer/renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const manifestPath = String.fromEnvironment(
    'APP_SHOTS_MANIFEST',
    defaultValue: '.compose/manifest.json',
  );
  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    test('compose manifest is absent', () {},
        skip: 'No compose manifest found');
    return;
  }

  final manifest = ComposeManifest.fromJson(
    jsonDecode(manifestFile.readAsStringSync()) as Map,
  );

  for (final entry in manifest.entries) {
    testWidgets('compose ${entry.id} ${entry.deviceClass}', (tester) async {
      final target =
          storeTargets.firstWhere((t) => t.deviceClass == entry.deviceClass);
      final previousPhysicalSize = tester.view.physicalSize;
      final previousDevicePixelRatio = tester.view.devicePixelRatio;
      final captureKey = GlobalKey();

      // Flutter's test invariant checks run before addTearDown/tearDownAll, so
      // view mutations must reset inside this test body.
      try {
        tester.view.physicalSize =
            Size(target.width.toDouble(), target.height.toDouble());
        tester.view.devicePixelRatio = 1.0;

        final screenshot =
            entry.raw == null ? null : _memoryImageFromFile(entry.raw!);
        final backgroundImage = entry.background.kind == 'image'
            ? _memoryImageFromFile(entry.background.path!)
            : null;
        final logo =
            entry.logo == null ? null : _memoryImageFromFile(entry.logo!);

        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Material(
              type: MaterialType.transparency,
              child: RepaintBoundary(
                key: captureKey,
                child: MarketingCanvas(
                  entry: entry,
                  palette: entry.palette,
                  targetSize:
                      Size(target.width.toDouble(), target.height.toDouble()),
                  screenshot: screenshot,
                  backgroundImage: backgroundImage,
                  logo: logo,
                ),
              ),
            ),
          ),
        );

        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            await precacheImage((element.widget as Image).image, element);
          }
        });
        await tester.pump();
        await tester.pump();

        final rawBytes = (await tester.runAsync<Uint8List>(() async {
          final boundary = captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return byteData!.buffer.asUint8List();
        }))!;
        final bytes =
            target.allowAlpha ? rawBytes : _flattenPngOverBlack(rawBytes);

        final out = File(entry.out);
        out.parent.createSync(recursive: true);
        out.writeAsBytesSync(bytes);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.view.physicalSize = previousPhysicalSize;
        tester.view.devicePixelRatio = previousDevicePixelRatio;
      }
    });
  }
}

Uint8List _flattenPngOverBlack(Uint8List bytes) {
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    throw StateError('Could not decode PNG bytes for alpha flattening');
  }
  final flattened =
      img.Image(width: decoded.width, height: decoded.height, numChannels: 3);
  for (var y = 0; y < decoded.height; y++) {
    for (var x = 0; x < decoded.width; x++) {
      final pixel = decoded.getPixel(x, y);
      final alpha = pixel.a / 255;
      flattened.setPixelRgb(
        x,
        y,
        (pixel.r * alpha).round(),
        (pixel.g * alpha).round(),
        (pixel.b * alpha).round(),
      );
    }
  }
  return Uint8List.fromList(img.encodePng(flattened));
}

MemoryImage _memoryImageFromFile(String filePath) =>
    MemoryImage(File(filePath).readAsBytesSync());
