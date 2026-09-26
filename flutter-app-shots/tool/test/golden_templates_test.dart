// flutter-app-shots/tool/test/golden_templates_test.dart
import 'package:app_shots/src/golden_templates.dart';
import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/store_specs.dart';
import 'package:test/test.dart';

final _tokenRe = RegExp(r'\{\{[^}]+\}\}');

void main() {
  test('status bar file is token-free and defines the chrome contract', () {
    expect(_tokenRe.hasMatch(kGoldenStatusBarFile), isFalse);
    expect(kGoldenStatusBarFile, contains('enum ShotStatusBarStyle'));
    expect(kGoldenStatusBarFile, contains('class AppShotsChrome'));
    expect(kGoldenStatusBarFile, contains('class AppShotsStatusBar'));
    expect(kGoldenStatusBarFile, contains("Text('9:41'"));
    expect(kGoldenStatusBarFile, contains('CustomPainter'));
    // Chrome must reserve the inset for the app content.
    expect(kGoldenStatusBarFile, contains('EdgeInsets.only(top: statusBarInset)'));
    // Regression: the chrome's Stack must have a Material ancestor so the
    // status bar's Text inherits the theme's DefaultTextStyle (fontFamily)
    // instead of falling through to MaterialApp's non-Material fallback
    // style, which rendered as tofu in the headless font environment.
    expect(kGoldenStatusBarFile, contains('MaterialType.transparency'));
  });

  test('test config renders for plain apps (no google_fonts)', () {
    final out = renderGoldenTestConfig(
        goldenDir: 'app_shots/golden', useGoogleFonts: false);
    expect(_tokenRe.hasMatch(out), isFalse);
    expect(out, contains('FontLoader'));
    expect(out, contains("Directory('app_shots/golden/fonts')"));
    expect(out, isNot(contains('google_fonts')));
    // Regression: plain `flutter test` never loads the framework's bundled
    // MaterialIcons font, so icon glyphs (e.g. the FAB's Icons.add) render
    // as tofu unless the config loads it explicitly via rootBundle.
    expect(out, contains("FontLoader('MaterialIcons')"));
    expect(out, contains("rootBundle.load('fonts/MaterialIcons-Regular.otf')"));
  });

  test('test config renders google_fonts guards when detected', () {
    final out = renderGoldenTestConfig(
        goldenDir: 'app_shots/golden', useGoogleFonts: true);
    expect(out, contains("import 'package:google_fonts/google_fonts.dart';"));
    expect(out, contains('GoogleFonts.config.allowRuntimeFetching = false;'));
    expect(out, contains('pubspec.yaml assets'));
  });

  test('google_fonts capture test never waits on pendingFonts', () {
    final out = renderGoldenCaptureTest(
      shots: const [
        (id: 'home', prefix: 'home_harness', deviceClasses: ['iphone_6_9'])
      ],
      devices: [storeTargets.first],
      outDir: 'app_shots/screenshots/golden',
      selfPath: 'app_shots/golden/capture_test.dart',
    );
    expect(_tokenRe.hasMatch(out), isFalse);
    expect(out,
        isNot(contains("import 'package:google_fonts/google_fonts.dart';")));
    expect(out, isNot(contains('GoogleFonts.pendingFonts')));
  });

  test('harness template renders write-once shot skeleton', () {
    final out = renderGoldenHarness(shotId: 'tempo', statusBarStyle: 'light');
    expect(_tokenRe.hasMatch(out), isFalse);
    expect(out, contains('ShotStatusBarStyle.light'));
    expect(out, contains('Widget buildShot()'));
    expect(out, contains('ThemeData buildTheme()'));
    expect(out, contains('Future<void> preCapture(WidgetTester tester)'));
    expect(out, contains('tempo'));
    expect(out, contains('FIXED'));
  });

  group('renderGoldenCaptureTest precache hardening', () {
    final rendered = renderGoldenCaptureTest(
      shots: [(id: 'home', prefix: 'home', deviceClasses: ['iphone_6_9'])],
      devices: captureTargetsFor([FormFactor.iphone]),
      outDir: 'app_shots/screenshots/golden',
      selfPath: 'app_shots/golden/capture_test.dart',
    );

    test('precaches only bundled providers (Asset/Memory)', () {
      expect(rendered, contains('provider is! AssetBundleImageProvider'));
      expect(rendered, contains('provider is! MemoryImage'));
    });

    test('timeout-guards each precache', () {
      expect(rendered,
          contains('.timeout(const Duration(seconds: 5))'));
    });

    test('skips non-bundled providers with a warning', () {
      expect(rendered,
          contains('APP_SHOTS_WARNING: skipped precache of non-bundled'));
    });

    test('no unbounded precache remains', () {
      expect(
          rendered,
          isNot(contains('await precacheImage(widget.image, element);')));
    });
  });
}
