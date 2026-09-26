import 'dart:convert';
import 'dart:io';
import 'package:app_shots/src/capture_log.dart';
import 'package:app_shots/src/cli.dart';
import 'package:app_shots/src/config_store.dart';
import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/process_runner.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

void main() {
  test('unknown command returns a non-zero exit code', () async {
    final code =
        await runCli(['bogus'], runner: FakeProcessRunner(responses: const {}));
    expect(code, isNot(0));
  });

  group('doctor command', () {
    late Directory dir;
    late Directory toolDir;
    late Directory rendererDir;
    late Directory appDir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cli_doctor_');
      toolDir = Directory('${dir.path}/tool')..createSync(recursive: true);
      rendererDir = Directory('${dir.path}/renderer')..createSync();
      appDir = Directory('${dir.path}/app')..createSync();
      File('${toolDir.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${rendererDir.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${appDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('emits pure Dart/Flutter capability JSON with no compositor flags',
        () async {
      final out = StringBuffer();
      final code = await runCli([
        'doctor',
        '--tool-dir',
        toolDir.path,
        '--renderer-dir',
        rendererDir.path,
        '--app-dir',
        appDir.path,
        '--image-gen',
        'true',
      ],
          runner: FakeProcessRunner(responses: {
            'flutter --version': ProcessResultData(
                exitCode: 0, stdout: 'Flutter 3.27', stderr: ''),
          }),
          out: out);

      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded.keys, isNot(contains('node')));
      expect(decoded.keys, isNot(contains('compositor')));
      expect(decoded['flutter'], isTrue);
      expect(decoded['tool'], {'resolved': true});
      expect(decoded['renderer'], {'resolved': true});
      expect(decoded['targetApp'], {'path': appDir.path, 'pubspec': true});
      expect(decoded['imageGeneration'], isTrue);
      expect(decoded['readyForGolden'], isTrue);
    });
  });

  group('preflight command', () {
    late Directory dir;
    late Directory toolDir;
    late Directory rendererDir;
    late Directory appDir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('cli_preflight_');
      toolDir = Directory('${dir.path}/tool')..createSync(recursive: true);
      rendererDir = Directory('${dir.path}/renderer')..createSync();
      appDir = Directory('${dir.path}/app')..createSync();
      File('${toolDir.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${rendererDir.path}/.dart_tool/package_config.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      File('${appDir.path}/pubspec.yaml').writeAsStringSync('name: app\n');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    test('golden mode returns 0 when Flutter, packages, and app are ready',
        () async {
      final out = StringBuffer();
      final code = await runCli([
        'preflight',
        '--mode',
        'golden',
        '--tool-dir',
        toolDir.path,
        '--renderer-dir',
        rendererDir.path,
        '--app-dir',
        appDir.path,
      ],
          runner: FakeProcessRunner(responses: {
            'flutter --version': ProcessResultData(
                exitCode: 0, stdout: 'Flutter 3.27', stderr: ''),
          }),
          out: out);

      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['mode'], 'golden');
      expect(decoded['ready'], isTrue);
      expect(decoded['nextStep'], 'run-golden-scaffold');
      expect((decoded['checks'] as Map).keys, isNot(contains('xcode')));
    });

    test('golden mode returns 1 with setup gaps when the app is missing',
        () async {
      File('${appDir.path}/pubspec.yaml').deleteSync();
      final out = StringBuffer();
      final code = await runCli([
        'preflight',
        '--mode',
        'golden',
        '--tool-dir',
        toolDir.path,
        '--renderer-dir',
        rendererDir.path,
        '--app-dir',
        appDir.path,
      ],
          runner: FakeProcessRunner(responses: {
            'flutter --version': ProcessResultData(
                exitCode: 0, stdout: 'Flutter 3.27', stderr: ''),
          }),
          out: out);

      expect(code, 1);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['ready'], isFalse);
      expect(
          decoded['setupGaps'], contains('target app: pubspec.yaml not found'));
    });

    test('live mode boots a best available simulator when --boot is set',
        () async {
      final out = StringBuffer();
      final simctlJson = jsonEncode({
        'devices': {
          'com.apple.CoreSimulator.SimRuntime.iOS-18-0': [
            {
              'udid': 'U1',
              'name': 'iPhone 16 Pro Max',
              'state': 'Shutdown',
              'isAvailable': true,
            }
          ]
        }
      });
      final code = await runCli([
        'preflight',
        '--mode',
        'live',
        '--boot',
        '--tool-dir',
        toolDir.path,
        '--renderer-dir',
        rendererDir.path,
        '--app-dir',
        appDir.path,
      ],
          runner: FakeProcessRunner(responses: {
            'flutter --version': ProcessResultData(
                exitCode: 0, stdout: 'Flutter 3.27', stderr: ''),
            'xcodebuild -version':
                ProcessResultData(exitCode: 0, stdout: 'Xcode 16', stderr: ''),
            'xcrun simctl list devices available --json':
                ProcessResultData(exitCode: 0, stdout: simctlJson, stderr: ''),
            'maestro --version':
                ProcessResultData(exitCode: 0, stdout: '1.40.0', stderr: ''),
            'xcrun simctl boot U1':
                ProcessResultData(exitCode: 0, stdout: '', stderr: ''),
          }),
          out: out);

      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['mode'], 'live');
      expect(decoded['ready'], isTrue);
      expect(decoded['liveDevice'], {'action': 'boot_device', 'udid': 'U1'});
    });
  });

  test(
      'audit aggregates simctl output via the runner and emits iPhone device name',
      () async {
    final out = StringBuffer();
    final runner = FakeProcessRunner(responses: {
      'xcrun simctl list devices available --json': ProcessResultData(
          exitCode: 0,
          stdout: '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":'
              '[{"udid":"U1","name":"iPhone 16 Pro Max","state":"Shutdown","isAvailable":true}]}}',
          stderr: ''),
      'emulator -list-avds':
          ProcessResultData(exitCode: 0, stdout: '', stderr: ''),
      'adb devices': ProcessResultData(
          exitCode: 0, stdout: 'List of devices attached\n', stderr: ''),
    });
    final code = await runCli(['audit'], runner: runner, out: out);
    expect(code, 0);
    expect(out.toString(), contains('iPhone 16 Pro Max'));
  });

  test('validate returns 64 when --target is not WIDTHxHEIGHT', () async {
    final dir = Directory.systemTemp.createTempSync('cli_validate_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/shot.png')..writeAsBytesSync([]);
    final out = StringBuffer();
    final code = await runCli(
      ['validate', '--file', file.path, '--target', 'bogus'],
      runner: FakeProcessRunner(responses: const {}),
      out: out,
    );
    expect(code, 64);
  });

  group('record command', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cli_record_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('upserts entries into the log file', () async {
      final log = File('${dir.path}/capture_log.json');

      // First write — id "hero" with status "passed"
      var code = await runCli([
        'record',
        '--log',
        log.path,
        '--id',
        'hero',
        '--file',
        'raw/hero.png',
        '--platform',
        'ios',
        '--form-factor',
        'iphone',
        '--device',
        'U1',
        '--width',
        '1320',
        '--height',
        '2868',
        '--tier',
        'T1',
        '--signature',
        'sig-v1',
        '--hash',
        'abc123',
      ], runner: FakeProcessRunner(responses: const {}));
      expect(code, 0);

      // Second write — same id "hero" with status "warning" (upsert replaces)
      code = await runCli([
        'record',
        '--log',
        log.path,
        '--id',
        'hero',
        '--file',
        'raw/hero.png',
        '--platform',
        'ios',
        '--form-factor',
        'iphone',
        '--device',
        'U1',
        '--width',
        '1320',
        '--height',
        '2868',
        '--tier',
        'T1',
        '--signature',
        'sig-v2',
        '--hash',
        'abc123',
        '--status',
        'warning',
      ], runner: FakeProcessRunner(responses: const {}));
      expect(code, 0);

      // Third write — new id "budget"
      code = await runCli([
        'record',
        '--log',
        log.path,
        '--id',
        'budget',
        '--file',
        'raw/budget.png',
        '--platform',
        'ios',
        '--form-factor',
        'iphone',
        '--device',
        'U1',
        '--width',
        '1320',
        '--height',
        '2868',
        '--tier',
        'T2',
        '--signature',
        'sig-budget',
        '--hash',
        'abc123',
      ], runner: FakeProcessRunner(responses: const {}));
      expect(code, 0);

      // Read back and assert
      final loaded = CaptureLog.fromJsonString(log.readAsStringSync());
      expect(loaded.entries, hasLength(2));
      expect(loaded.byId('hero')!.status, 'warning');
      expect(loaded.byId('hero')!.signature, 'sig-v2');
      expect(loaded.byId('budget')!.tier, ReliabilityTier.t2);
    });
  });

  group('save-devices command', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cli_savedev_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes device map to config YAML with iphone key', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final runner = FakeProcessRunner(responses: {
        'xcrun simctl list devices available --json': ProcessResultData(
            exitCode: 0,
            stdout: '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":'
                '[{"udid":"U1","name":"iPhone 16 Pro Max","state":"Shutdown","isAvailable":true}]}}',
            stderr: ''),
        'emulator -list-avds':
            ProcessResultData(exitCode: 0, stdout: '', stderr: ''),
      });
      final code = await runCli(
        ['save-devices', '--config', config.path],
        runner: runner,
      );
      expect(code, 0);
      final text = config.readAsStringSync();
      expect(text, contains('devices:'));
      expect(text, contains('iphone:'));
    });
  });

  group('save-plan command', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('cli_saveplan_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('writes plan to config YAML and round-trips via loadPlan', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":["iphone"]}]}');

      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        runner: FakeProcessRunner(responses: const {}),
      );
      expect(code, 0);

      final loaded = loadPlan(config.readAsStringSync());
      expect(loaded.stores, ['app_store']);
      expect(loaded.shots.single.id, 'hero');
    });

    test('accepts exact device classes and derives their form factors',
        () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store","play_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"deviceClasses":["iphone_6_9","android_tablet_10"]}]}');

      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        runner: FakeProcessRunner(responses: const {}),
      );
      expect(code, 0);
      final shot = loadPlan(config.readAsStringSync()).shots.single;
      expect(shot.deviceClasses, ['iphone_6_9', 'android_tablet_10']);
      expect(shot.formFactors, [FormFactor.iphone, FormFactor.androidTablet]);
    });

    test('rejects conflicting broad and exact target declarations', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":["iphone"],"deviceClasses":["ipad_13"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('do not match exact deviceClasses'));
    });

    test('returns 64 for an unknown exact device class', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"deviceClasses":["iphone_future"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('unknown deviceClass "iphone_future"'));
    });

    test('returns 64 when an exact device class belongs to another store',
        () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"deviceClasses":["android_phone"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('deviceClass "android_phone"'));
      expect(err.toString(), contains('not in selected stores'));
    });

    test('returns 64 when feature_graphic is used as a capture target',
        () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["play_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"deviceClasses":["feature_graphic"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('composition-only'));
    });

    test('returns 64 when stores is missing', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":["iphone"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('stores must be a non-empty list'));
    });

    test('returns 64 when a shot has no form factors or exact targets',
        () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":[]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(),
          contains('shot "hero" has no formFactors or deviceClasses'));
    });

    test('returns 64 when a form factor is not in the selected stores',
        () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":["androidPhone"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('form factor "androidPhone"'));
    });

    test('returns 64 for an unknown form factor instead of crashing', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync(
            '{"stores":["app_store"],"shots":[{"id":"hero","description":"Hero","requiredState":{"auth":true,"seeded":false},"selectors":[],"formFactors":["phone"]}]}');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(
          err.toString(),
          contains(
              'Invalid plan: unknown form factor (choices: iphone, ipad, androidPhone, androidTablet)'));
    });

    test('returns 64 for malformed plan JSON instead of crashing', () async {
      final config = File('${dir.path}/app_shots.yaml');
      final planJson = File('${dir.path}/plan.json')
        ..writeAsStringSync('not json');
      final err = StringBuffer();
      final code = await runCli(
        ['save-plan', '--config', config.path, '--plan', planJson.path],
        err: err,
      );
      expect(code, 64);
      expect(err.toString(), contains('Invalid plan JSON'));
    });
  });

  group('golden-scaffold', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('golden_scaffold'));
    tearDown(() => tmp.deleteSync(recursive: true));

    String writeConfig() {
      final plan = ScreenshotPlan(shots: [
        ShotSpec(
          id: 'home',
          description: 'Home',
          route: null,
          requiredState: const RequiredState(auth: false, seeded: true),
          selectors: const [],
          formFactors: const [FormFactor.iphone],
        ),
      ]);
      final configPath = '${tmp.path}/app_shots.yaml';
      File(configPath).writeAsStringSync(writePlan('', plan));
      return configPath;
    }

    test('writes the suite into --app-dir and reports next steps', () async {
      final config = writeConfig();
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
      final out = StringBuffer();
      final code = await runCli([
        'golden-scaffold',
        '--config',
        config,
        '--app-dir',
        tmp.path,
      ], out: out);
      expect(code, 0);
      expect(
          File('${tmp.path}/app_shots/golden/capture_test.dart').existsSync(),
          isTrue);
      expect(File('${tmp.path}/app_shots/golden/status_bar.dart').existsSync(),
          isTrue);
      expect(
          File('${tmp.path}/app_shots/golden/flutter_test_config.dart')
              .existsSync(),
          isTrue);
      expect(
          File('${tmp.path}/app_shots/golden/harness/home_harness.dart')
              .existsSync(),
          isTrue);
      expect(out.toString(),
          contains('flutter test app_shots/golden/capture_test.dart'));
    });

    test('never overwrites an existing harness, always refreshes the suite',
        () async {
      final config = writeConfig();
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
      await runCli(
          ['golden-scaffold', '--config', config, '--app-dir', tmp.path]);
      final harness =
          File('${tmp.path}/app_shots/golden/harness/home_harness.dart');
      harness.writeAsStringSync('// filled by agent');
      final captureTest =
          File('${tmp.path}/app_shots/golden/capture_test.dart');
      captureTest.writeAsStringSync('// stale');
      final statusBar = File('${tmp.path}/app_shots/golden/status_bar.dart');
      statusBar.writeAsStringSync('// stale status_bar');
      final flutterTestConfig =
          File('${tmp.path}/app_shots/golden/flutter_test_config.dart');
      flutterTestConfig.writeAsStringSync('// stale flutter_test_config');
      await runCli(
          ['golden-scaffold', '--config', config, '--app-dir', tmp.path]);
      expect(harness.readAsStringSync(), '// filled by agent');
      expect(captureTest.readAsStringSync(), isNot('// stale'));
      expect(statusBar.readAsStringSync(), isNot('// stale status_bar'));
      expect(flutterTestConfig.readAsStringSync(),
          isNot('// stale flutter_test_config'));
    });

    test('detects google_fonts from the app pubspec', () async {
      final config = writeConfig();
      File('${tmp.path}/pubspec.yaml').writeAsStringSync(
          'name: fixture\ndependencies:\n  google_fonts: ^6.0.0\n');
      final out = StringBuffer();
      await runCli(
          ['golden-scaffold', '--config', config, '--app-dir', tmp.path],
          out: out);
      final test = File('${tmp.path}/app_shots/golden/capture_test.dart')
          .readAsStringSync();
      final testConfig =
          File('${tmp.path}/app_shots/golden/flutter_test_config.dart')
              .readAsStringSync();
      expect(test, isNot(contains('GoogleFonts.pendingFonts')));
      expect(test, isNot(contains("package:google_fonts/google_fonts.dart")));
      expect(testConfig,
          contains('GoogleFonts.config.allowRuntimeFetching = false;'));
      expect(out.toString(), contains('google_fonts/'));
      expect(out.toString(), contains('pubspec.yaml assets'));
    });

    test('returns 64 when --config points to nonexistent file', () async {
      final nonexistent = '${tmp.path}/nonexistent.yaml';
      final code = await runCli([
        'golden-scaffold',
        '--config',
        nonexistent,
        '--app-dir',
        tmp.path,
      ]);
      expect(code, 64);
    });

    test('returns 64 and prints a message to stderr for an invalid shot id',
        () async {
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
      final config = '${tmp.path}/app_shots.yaml';
      File(config).writeAsStringSync(writePlan('', plan));
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
      final err = StringBuffer();
      final code = await runCli([
        'golden-scaffold',
        '--config',
        config,
        '--app-dir',
        tmp.path,
      ], err: err);
      expect(code, 64);
      expect(err.toString(), contains('Home View'));
    });

    test('returns 64 when plan has zero shots', () async {
      final emptyPlan = ScreenshotPlan(shots: []);
      final config = '${tmp.path}/app_shots.yaml';
      File(config).writeAsStringSync(writePlan('', emptyPlan));
      File('${tmp.path}/pubspec.yaml').writeAsStringSync('name: fixture\n');
      final code = await runCli([
        'golden-scaffold',
        '--config',
        config,
        '--app-dir',
        tmp.path,
      ]);
      expect(code, 64);
    });
  });

  group('lint-copy command', () {
    test('exit 0 and ok:true JSON for clean copy', () async {
      final out = StringBuffer();
      final code = await runCli(
        ['lint-copy', '--store', 'app_store', '--text', 'Track every wallet'],
        out: out,
      );
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['ok'], isTrue);
      expect(decoded['issues'], isEmpty);
    });

    test('exit 1 and ok:false JSON when a ranking claim is present', () async {
      final out = StringBuffer();
      final code = await runCli(
        ['lint-copy', '--store', 'app_store', '--text', 'The best app'],
        out: out,
      );
      expect(code, 1);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['ok'], isFalse);
      expect(decoded['issues'],
          contains('unsupported ranking/superlative claim: "best"'));
    });

    test('"download now" exits 0 on app_store, 1 on play_store', () async {
      final appOut = StringBuffer();
      final appCode = await runCli(
        ['lint-copy', '--store', 'app_store', '--text', 'download now'],
        out: appOut,
      );
      expect(appCode, 0);

      final playOut = StringBuffer();
      final playCode = await runCli(
        ['lint-copy', '--store', 'play_store', '--text', 'download now'],
        out: playOut,
      );
      expect(playCode, 1);
    });
  });

  group('bg-prompt command', () {
    test('emits parseable JSON with the five ImagePromptSpec fields', () async {
      final out = StringBuffer();
      final code = await runCli([
        'bg-prompt',
        '--device',
        'iphone_6_9',
        '--tone',
        'premium',
        '--brand-color',
        '#FF0000',
      ], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded.keys.toSet(),
          {'prompt', 'negativePrompt', 'width', 'height', 'aspectRatio'});
      expect(decoded['aspectRatio'], '1320:2868');
      expect(decoded['width'], 1320);
      expect(decoded['height'], 2868);
      expect(
          decoded['prompt'], contains('Composition for a 1320x2868 canvas.'));
    });

    test('returns exit 64 for unknown device', () async {
      final err = StringBuffer();
      final code = await runCli([
        'bg-prompt',
        '--device',
        'not_a_device',
        '--tone',
        'premium',
        '--brand-color',
        '#FF0000',
      ], err: err);
      expect(code, 64);
      expect(err.toString(), contains('Unknown device class'));
    });
  });

  group('list-targets command', () {
    test('returns all 7 entries when unfiltered', () async {
      final out = StringBuffer();
      final code = await runCli(['list-targets'], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as List;
      expect(decoded, hasLength(7));
    });

    test('returns 3 entries for --store app_store', () async {
      final out = StringBuffer();
      final code =
          await runCli(['list-targets', '--store', 'app_store'], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as List;
      expect(decoded, hasLength(3));
      expect(decoded.every((e) => (e as Map)['store'] == 'app_store'), isTrue);
    });

    test('iphone_6_9 entry has full JSON shape with capture profile', () async {
      final out = StringBuffer();
      final code = await runCli(['list-targets'], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as List;
      final iphone = decoded
          .firstWhere((e) => (e as Map)['deviceClass'] == 'iphone_6_9') as Map;
      expect(iphone['store'], 'app_store');
      expect(iphone['deviceClass'], 'iphone_6_9');
      expect(iphone['width'], 1320);
      expect(iphone['height'], 2868);
      expect(iphone['orientation'], 'portrait');
      expect(iphone['textOverlayMaxFraction'], 1);
      expect(iphone['allowAlpha'], isTrue);
      expect(iphone.containsKey('capture'), isTrue);
      final capture = iphone['capture'] as Map;
      expect(capture['dpr'], 3.0);
      expect(capture['statusBarInsetPt'], 62);
      expect(capture['isIos'], isTrue);
    });

    test('feature_graphic entry has no capture key', () async {
      final out = StringBuffer();
      final code = await runCli(['list-targets'], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as List;
      final feature = decoded.firstWhere(
          (e) => (e as Map)['deviceClass'] == 'feature_graphic') as Map;
      expect(feature['store'], 'play_store');
      expect(feature['deviceClass'], 'feature_graphic');
      expect(feature['width'], 1024);
      expect(feature['height'], 500);
      expect(feature['orientation'], 'landscape');
      expect(feature['textOverlayMaxFraction'], 0.5);
      expect(feature['allowAlpha'], isFalse);
      expect(feature.containsKey('capture'), isFalse);
    });
  });

  group('validate-output command', () {
    late Directory dir;
    setUp(() =>
        dir = Directory.systemTemp.createTempSync('cli_validate_output_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File writeGradientPng(String name, int width, int height) {
      final image = img.Image(width: width, height: height, numChannels: 3);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          image.setPixelRgb(x, y, (x * 255 / (width - 1)).round(),
              (y * 255 / (height - 1)).round(), 128);
        }
      }
      final file = File('${dir.path}/$name');
      file.writeAsBytesSync(img.encodePng(image));
      return file;
    }

    test('exit 0 and passed:true JSON for a correct-size PNG', () async {
      final file = writeGradientPng('shot.png', 1080, 1920);
      final out = StringBuffer();
      final code = await runCli([
        'validate-output',
        '--file',
        file.path,
        '--device',
        'android_phone',
      ], out: out);
      expect(code, 0);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['passed'], isTrue);
      expect(decoded['width'], 1080);
      expect(decoded['height'], 1920);
      expect(decoded['hasAlpha'], isFalse);
      expect(decoded.keys.toSet(),
          {'passed', 'warnings', 'width', 'height', 'hasAlpha'});
    });

    test(
        'exit 1 and the verbatim overlay warning when --overlay exceeds the limit',
        () async {
      final file = writeGradientPng('shot.png', 1080, 1920);
      final out = StringBuffer();
      final code = await runCli([
        'validate-output',
        '--file',
        file.path,
        '--device',
        'android_phone',
        '--overlay',
        '0.3',
      ], out: out);
      expect(code, 1);
      final decoded = jsonDecode(out.toString()) as Map;
      expect(decoded['passed'], isFalse);
      expect(
          decoded['warnings'], contains('text overlay 30% exceeds limit 20%'));
    });

    test('returns exit 64 for unknown device', () async {
      final file = writeGradientPng('shot.png', 1080, 1920);
      final err = StringBuffer();
      final code = await runCli([
        'validate-output',
        '--file',
        file.path,
        '--device',
        'not_a_device',
      ], err: err);
      expect(code, 64);
      expect(err.toString(), contains('Unknown device class'));
    });

    test('returns exit 64 and mentions overlay when --overlay is not a number',
        () async {
      final file = writeGradientPng('shot.png', 1080, 1920);
      final err = StringBuffer();
      final code = await runCli([
        'validate-output',
        '--file',
        file.path,
        '--device',
        'android_phone',
        '--overlay',
        'abc',
      ], err: err);
      expect(code, 64);
      expect(err.toString(), contains('--overlay'));
      expect(err.toString(), contains('number'));
    });
  });

  group('compose-manifest command', () {
    late Directory dir;
    setUp(() =>
        dir = Directory.systemTemp.createTempSync('cli_compose_manifest_'));
    tearDown(() => dir.deleteSync(recursive: true));

    File writePng(String rel) {
      final file = File('${dir.path}/$rel');
      file.parent.createSync(recursive: true);
      final image = img.Image(width: 20, height: 20, numChannels: 3);
      img.fill(image, color: img.ColorRgb8(32, 96, 160));
      file.writeAsBytesSync(img.encodePng(image));
      return file;
    }

    File writeSpec(Map<String, dynamic> json) {
      final file = File('${dir.path}/compose-spec.json');
      file.writeAsStringSync(jsonEncode(json));
      return file;
    }

    test('writes a normalized css manifest with out path and overlay',
        () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes, one place',
            'subheadline': 'Fast capture. Zero friction.',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final manifest = File('${dir.path}/renderer/.compose/manifest.json');
      final outDir = '${dir.path}/app_shots/outputs';
      final out = StringBuffer();

      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--out-dir',
        outDir,
        '--manifest',
        manifest.path,
      ], out: out);

      expect(code, 0);
      expect(manifest.existsSync(), isTrue);
      final decoded = jsonDecode(manifest.readAsStringSync()) as Map;
      final entry = (decoded['entries'] as List).single as Map;
      expect(entry['deviceClass'], 'iphone_6_9');
      expect(entry['brandColor'], '#6750A4');
      expect(entry['background'], {'kind': 'css', 'style': 'gradient'});
      // css palette equals the tone table + brand accent (byte-identical).
      expect((entry['palette'] as Map)['bg'], '#0F172A');
      expect((entry['palette'] as Map)['accent'], '#6750A4');
      expect(entry['out'],
          '${File(outDir).absolute.path}/app_store/iphone_6_9/home.png');
      expect(entry['textOverlayFraction'], 0.24);
    });

    test('auto background embeds a palette extracted from the screenshot',
        () async {
      final raw = writePng('raw/home.png'); // solid #2060A0
      final spec = writeSpec({
        'stores': ['app_store'],
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes, one place',
            'background': {'kind': 'auto'},
          }
        ],
      });
      final manifest = File('${dir.path}/manifest.json');
      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--manifest',
        manifest.path
      ]);
      expect(code, 0);
      final entry =
          (jsonDecode(manifest.readAsStringSync()) as Map)['entries'][0] as Map;
      // auto resolves to a css recipe in the manifest...
      expect(entry['background'], {'kind': 'css', 'style': 'gradient'});
      // ...painted with the extracted palette (accent = dominant color).
      expect((entry['palette'] as Map)['accent'], '#2060A0');
      expect((entry['palette'] as Map)['text'], '#FFFFFF');
      // brandColor is not required for an all-auto spec.
      expect(entry.containsKey('brandColor'), isFalse);
    });

    test('rejects an unknown css style with exit 64', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'sparkles'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('unknown css style "sparkles"'));
    });

    test('accepts the new mesh css style', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'mesh'},
          }
        ],
      });
      final manifest = File('${dir.path}/manifest.json');
      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--manifest',
        manifest.path
      ]);
      expect(code, 0);
      final entry =
          (jsonDecode(manifest.readAsStringSync()) as Map)['entries'][0] as Map;
      expect(entry['background'], {'kind': 'css', 'style': 'mesh'});
    });

    test('auto-assigns rotated layouts by distinct shot id, honoring overrides',
        () async {
      final raw = writePng('raw/shot.png');
      Map<String, dynamic> e(String id, String device,
              {String? layout, bool deviceless = false}) =>
          {
            'id': id,
            'deviceClass': device,
            if (!deviceless) 'raw': raw.path,
            'headline': 'H $id',
            if (layout != null) 'layout': layout,
            'background': deviceless
                ? {'kind': 'css', 'style': 'brand_block'}
                : {'kind': 'css', 'style': 'gradient'},
            if (deviceless) 'deviceless': true,
          };
      final spec = writeSpec({
        'stores': ['app_store', 'play_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          e('home', 'iphone_6_9'), // idIndex 0 -> centered_device
          e('home', 'ipad_13'), //    idIndex 0 -> centered_device (same shot)
          e('stats', 'iphone_6_9', layout: 'dual_device'), // explicit override
          e('tips', 'iphone_6_9'), //  idIndex 2 -> feature_callout
          e('more', 'iphone_6_9'), //  idIndex 3 -> text_banner
          e('extra', 'iphone_6_9'), // idIndex 4 -> wraps to centered_device
          e('promo', 'feature_graphic', deviceless: true), // -> full_bleed
        ],
      });
      final manifest = File('${dir.path}/manifest.json');
      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--manifest',
        manifest.path
      ]);
      expect(code, 0);
      final entries =
          (jsonDecode(manifest.readAsStringSync()) as Map)['entries'] as List;
      String layoutOf(int i) => (entries[i] as Map)['layout'] as String;
      expect(layoutOf(0), 'centered_device');
      expect(layoutOf(1), 'centered_device');
      expect(layoutOf(2), 'dual_device'); // explicit wins
      expect(layoutOf(3), 'feature_callout'); // override didn't shift index
      expect(layoutOf(4), 'text_banner');
      expect(layoutOf(5), 'centered_device'); // rotation wrap
      expect(layoutOf(6), 'full_bleed'); // deviceless
    });

    test('returns 64 when stores is missing', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('stores must be a non-empty list'));
    });

    test('returns 64 when a deviceClass is not in the selected stores',
        () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'android_phone',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('not in selected stores'));
    });

    test('returns 64 for an unknown deviceClass', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'not_a_device',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('Unknown device class: not_a_device'));
    });

    test('returns 64 when background is missing', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes',
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('missing required background'));
    });

    test('returns 64 when a css entry has no brandColor', () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['app_store'],
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': raw.path,
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('requires top-level brandColor'));
    });

    test('returns 64 when an auto entry is deviceless (no raw)', () async {
      final spec = writeSpec({
        'stores': ['play_store'],
        'tone': 'professional',
        'entries': [
          {
            'id': 'feature',
            'deviceClass': 'feature_graphic',
            'headline': 'Fixture Notes',
            'deviceless': true,
            'background': {'kind': 'auto'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('kind "auto" requires a raw screenshot'));
    });

    test('returns 64 when raw is missing for a non-deviceless entry', () async {
      final spec = writeSpec({
        'stores': ['app_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'iphone_6_9',
            'raw': '${dir.path}/missing.png',
            'headline': 'All your notes',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final err = StringBuffer();
      final code =
          await runCli(['compose-manifest', '--spec', spec.path], err: err);
      expect(code, 64);
      expect(err.toString(), contains('Missing raw screenshot'));
    });

    test('accepts a deviceless feature graphic with an explicit css background',
        () async {
      final spec = writeSpec({
        'stores': ['play_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'feature',
            'deviceClass': 'feature_graphic',
            'headline': 'Fixture Notes',
            'background': {'kind': 'css', 'style': 'brand_block'},
            'deviceless': true,
          }
        ],
      });
      final manifest = File('${dir.path}/manifest.json');
      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--manifest',
        manifest.path
      ]);
      expect(code, 0);
      final entry =
          (jsonDecode(manifest.readAsStringSync()) as Map)['entries'][0] as Map;
      expect(entry.containsKey('raw'), isFalse);
      expect(entry['layout'], 'full_bleed');
      expect(entry['textOverlayFraction'], 1.0);
    });

    test('embeds lint results but does not block manifest generation',
        () async {
      final raw = writePng('raw/home.png');
      final spec = writeSpec({
        'stores': ['play_store'],
        'brandColor': '#6750A4',
        'tone': 'professional',
        'entries': [
          {
            'id': 'home',
            'deviceClass': 'android_phone',
            'raw': raw.path,
            'headline': '#1 notes app',
            'background': {'kind': 'css', 'style': 'gradient'},
          }
        ],
      });
      final manifest = File('${dir.path}/manifest.json');
      final code = await runCli([
        'compose-manifest',
        '--spec',
        spec.path,
        '--manifest',
        manifest.path
      ]);
      expect(code, 0);
      final entry =
          (jsonDecode(manifest.readAsStringSync()) as Map)['entries'][0] as Map;
      final lint = entry['lint'] as Map;
      expect(lint['ok'], isFalse);
      expect(lint['issues'],
          contains('unsupported ranking/superlative claim: "#1"'));
    });
  });
}
