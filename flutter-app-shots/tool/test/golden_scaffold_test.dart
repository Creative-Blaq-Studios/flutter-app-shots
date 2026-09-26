// flutter-app-shots/tool/test/golden_scaffold_test.dart
import 'package:app_shots/src/golden_scaffold.dart';
import 'package:app_shots/src/models.dart';
import 'package:test/test.dart';

final _tokenRe = RegExp(r'\{\{[^}]+\}\}');

ScreenshotPlan _plan() => ScreenshotPlan(shots: [
      ShotSpec(
        id: 'home',
        description: 'Home list',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.iphone, FormFactor.androidPhone],
      ),
      ShotSpec(
        id: 'stats-view',
        description: 'Stats',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.ipad],
      ),
    ]);

void main() {
  test('dartIdentifier sanitizes shot ids', () {
    expect(dartIdentifier('home'), 'home');
    expect(dartIdentifier('stats-view'), 'stats_view');
    expect(dartIdentifier('My Shot!'), 'my_shot_');
    expect(dartIdentifier('6pack'), 's_6pack');
  });

  test('detectGoogleFonts reads dependencies and dev_dependencies', () {
    expect(detectGoogleFonts('''
name: x
dependencies:
  google_fonts: ^6.0.0
'''), isTrue);
    expect(detectGoogleFonts('''
name: x
dev_dependencies:
  google_fonts: ^6.0.0
'''), isTrue);
    expect(
        detectGoogleFonts('name: x\ndependencies:\n  http: ^1.0.0\n'), isFalse);
    expect(detectGoogleFonts(''), isFalse);
  });

  test('detectGoogleFonts returns false for malformed YAML instead of throwing',
      () {
    expect(detectGoogleFonts('name: x\ndependencies:\n  google_fonts: [\n'),
        isFalse);
  });

  test('renderGoldenSuite rejects an invalid shot id', () {
    final plan = ScreenshotPlan(shots: [
      ShotSpec(
        id: 'Home View',
        description: 'Home',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.iphone],
      ),
    ]);
    expect(
      () => renderGoldenSuite(
        plan: plan,
        goldenDir: 'app_shots/golden',
        outDir: 'app_shots/screenshots/golden',
        useGoogleFonts: false,
      ),
      throwsA(isA<FormatException>().having(
        (e) => e.message,
        'message',
        allOf(contains('Home View'), contains('^[a-z0-9]')),
      )),
    );
  });

  test('renderGoldenSuite rejects shot ids that sanitize to the same prefix',
      () {
    final plan = ScreenshotPlan(shots: [
      ShotSpec(
        id: 'stats-view',
        description: 'Stats (dash)',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.iphone],
      ),
      ShotSpec(
        id: 'stats_view',
        description: 'Stats (underscore)',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.iphone],
      ),
    ]);
    expect(
      () => renderGoldenSuite(
        plan: plan,
        goldenDir: 'app_shots/golden',
        outDir: 'app_shots/screenshots/golden',
        useGoogleFonts: false,
      ),
      throwsA(isA<FormatException>().having(
        (e) => e.message,
        'message',
        allOf(contains('stats-view'), contains('stats_view')),
      )),
    );
  });

  test(
      'renderGoldenSuite rejects a goldenDir/outDir with quotes or backslashes',
      () {
    expect(
      () => renderGoldenSuite(
        plan: _plan(),
        goldenDir: r"app_shots/golden'; import 'dart:io",
        outDir: 'app_shots/screenshots/golden',
        useGoogleFonts: false,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => renderGoldenSuite(
        plan: _plan(),
        goldenDir: 'app_shots/golden',
        outDir: r'app_shots\screenshots\golden',
        useGoogleFonts: false,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('renderGoldenSuite emits the four-file suite keyed by relative path',
      () {
    final suite = renderGoldenSuite(
      plan: _plan(),
      goldenDir: 'app_shots/golden',
      outDir: 'app_shots/screenshots/golden',
      useGoogleFonts: false,
    );
    expect(
        suite.writeAlways.keys,
        containsAll([
          'app_shots/golden/flutter_test_config.dart',
          'app_shots/golden/status_bar.dart',
          'app_shots/golden/capture_test.dart',
        ]));
    expect(
        suite.writeIfAbsent.keys,
        containsAll([
          'app_shots/golden/harness/home_harness.dart',
          'app_shots/golden/harness/stats_view_harness.dart',
        ]));
    for (final content in [
      ...suite.writeAlways.values,
      ...suite.writeIfAbsent.values,
    ]) {
      expect(_tokenRe.hasMatch(content), isFalse);
    }
  });

  test('capture test wires shots to their form-factor device classes', () {
    final suite = renderGoldenSuite(
      plan: _plan(),
      goldenDir: 'app_shots/golden',
      outDir: 'app_shots/screenshots/golden',
      useGoogleFonts: true,
    );
    final test = suite.writeAlways['app_shots/golden/capture_test.dart']!;
    // home: iphone + androidPhone → 3 device classes; stats: ipad only.
    expect(
        test,
        contains(
            "_Shot('home', ['iphone_6_9', 'iphone_6_5', 'android_phone']"));
    expect(test, contains("_Shot('stats-view', ['ipad_13']"));
    // Harness imports are prefixed.
    expect(
        test, contains("import 'harness/home_harness.dart' as home_harness;"));
    expect(
        test,
        contains(
            "import 'harness/stats_view_harness.dart' as stats_view_harness;"));
    // Devices carry px + dpr + inset + platform.
    expect(
        test,
        contains(
            "_GoldenDevice('iphone_6_9', 1320, 2868, 3.0, 62.0, TargetPlatform.iOS)"));
    expect(
        test,
        contains(
            "_GoldenDevice('android_phone', 1080, 1920, 3.0, 24.0, TargetPlatform.android)"));
    // Only devices used by some shot are emitted (no tablets here).
    expect(test, isNot(contains('android_tablet_7')));
    // Robustness kit.
    expect(test, contains('debugDisableShadows = false'));
    expect(test, contains('precacheImage'));
    expect(test, isNot(contains('GoogleFonts.pendingFonts')));
    expect(test, isNot(contains("package:google_fonts/google_fonts.dart")));
    expect(test, contains('pumpAndSettle'));
    expect(test, contains("toImage(pixelRatio: device.dpr)"));
    expect(test, contains('app_shots/screenshots/golden'));
    // Regression: debugDefaultTargetPlatformOverride must be reset inline
    // before the testWidgets body returns, not via addTearDown —
    // flutter_test's _verifyInvariants() runs before addTearDown callbacks
    // and would otherwise false-fail every capture test on Flutter 3.41.
    expect(test, contains('debugDefaultTargetPlatformOverride = null;'));
    expect(
        test,
        isNot(contains(
            'addTearDown(() => debugDefaultTargetPlatformOverride = null)')));
    // Regression: debugDisableShadows must be toggled per-test, not via
    // setUpAll/tearDownAll — _verifyInvariants() runs after every individual
    // test, so a suite-scoped toggle false-fails every test but the last.
    expect(test, contains('debugDisableShadows = false;'));
    expect(test, contains('debugDisableShadows = true;'));
    expect(test, isNot(contains('setUpAll(() => debugDisableShadows')));
    expect(test, isNot(contains('tearDownAll(() => debugDisableShadows')));
    // Regression: the resets must be exception-safe (try/finally), not bare
    // statements at the end of the test body — otherwise a throw between
    // pumpWidget and the resets (precacheImage, pumpAndSettle, toImage)
    // skips them and false-fails every subsequent capture test too with
    // "debug variable was changed".
    final finallyIndex = test.indexOf('} finally {');
    expect(finallyIndex, greaterThan(-1),
        reason: 'resets must live in a finally block');
    final finallyBlock = test.substring(finallyIndex);
    expect(
        finallyBlock, contains('debugDefaultTargetPlatformOverride = null;'));
    expect(finallyBlock, contains('debugDisableShadows = true;'));
    // The capture work (pumpWidget onward) must run inside the try, ahead of
    // the finally, so the resets still fire if it throws.
    expect(test.indexOf('await tester.pumpWidget'), lessThan(finallyIndex));
    expect(test.indexOf('toImage(pixelRatio: device.dpr)'),
        lessThan(finallyIndex));
    // Old exception-unsafe pattern (bare resets with no enclosing finally)
    // must be gone.
    expect(
        test,
        isNot(contains(
            '// Reset synchronously at the end of the test body (not via\n'
            '        // addTearDown)')));
  });

  test('capture test honors exact device-class selections', () {
    final plan = ScreenshotPlan(shots: [
      ShotSpec(
        id: 'home',
        description: 'Home list',
        route: null,
        requiredState: const RequiredState(auth: false, seeded: true),
        selectors: const [],
        formFactors: const [FormFactor.iphone, FormFactor.androidTablet],
        deviceClasses: const ['iphone_6_9', 'android_tablet_10'],
      ),
    ]);
    final suite = renderGoldenSuite(
      plan: plan,
      goldenDir: 'app_shots/golden',
      outDir: 'app_shots/screenshots/golden',
      useGoogleFonts: false,
    );
    final test = suite.writeAlways['app_shots/golden/capture_test.dart']!;
    expect(test, contains("_Shot('home', ['iphone_6_9', 'android_tablet_10']"));
    expect(test, isNot(contains("_GoldenDevice('iphone_6_5'")));
    expect(test, isNot(contains("_GoldenDevice('android_tablet_7'")));
  });

  test('capture test omits google_fonts when not used', () {
    final suite = renderGoldenSuite(
      plan: _plan(),
      goldenDir: 'app_shots/golden',
      outDir: 'app_shots/screenshots/golden',
      useGoogleFonts: false,
    );
    final test = suite.writeAlways['app_shots/golden/capture_test.dart']!;
    expect(test, isNot(contains('GoogleFonts')));
  });
}
