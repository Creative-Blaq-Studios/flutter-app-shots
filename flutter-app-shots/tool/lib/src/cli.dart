import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as path;

import 'capture_log.dart';
import 'capture_validator.dart';
import 'chrome_normalizer.dart';
import 'compose_specs.dart';
import 'config_store.dart';
import 'copy_lint.dart';
import 'device_auditor.dart';
import 'doctor.dart';
import 'golden_scaffold.dart';
import 'models.dart';
import 'output_validator.dart';
import 'palette_extractor.dart';
import 'preflight.dart';
import 'process_runner.dart';
import 'prompt_spec.dart';
import 'regen_diff.dart';
import 'store_scope.dart';
import 'store_specs.dart';

Future<int> runCli(List<String> args,
    {ProcessRunner? runner, StringSink? out, StringSink? err}) async {
  final r = runner ?? RealProcessRunner();
  final sink = out ?? stdout;
  final errSink = err ?? stderr;
  final runnerCmd = CommandRunner<int>('app_shots', 'Flutter App Shots engine')
    ..addCommand(_AuditCommand(r, sink))
    ..addCommand(_NormalizeCommand(r))
    ..addCommand(_ValidateCommand(sink))
    ..addCommand(_RegenCheckCommand(sink))
    ..addCommand(_RecordCommand())
    ..addCommand(_SaveDevicesCommand(r))
    ..addCommand(_SavePlanCommand(errSink))
    ..addCommand(_GoldenScaffoldCommand(sink, errSink))
    ..addCommand(_LintCopyCommand(sink))
    ..addCommand(_BgPromptCommand(sink, errSink))
    ..addCommand(_ListTargetsCommand(sink))
    ..addCommand(_DoctorCommand(r, sink))
    ..addCommand(_PreflightCommand(r, sink))
    ..addCommand(_ValidateOutputCommand(sink, errSink))
    ..addCommand(_ComposeManifestCommand(sink, errSink));
  try {
    return await runnerCmd.run(args) ?? 0;
  } on UsageException catch (e) {
    errSink.writeln(e.message);
    return 64;
  }
}

class _AuditCommand extends Command<int> {
  final ProcessRunner _runner;
  final StringSink _out;
  _AuditCommand(this._runner, this._out);
  @override
  String get name => 'audit';
  @override
  String get description => 'Detect simulators/emulators and map form-factors.';

  @override
  Future<int> run() async {
    final simctl = await _runner
        .run('xcrun', ['simctl', 'list', 'devices', 'available', '--json']);
    final devices = <Device>[];
    if (simctl.exitCode == 0 && simctl.stdout.trim().isNotEmpty) {
      devices.addAll(parseSimctl(simctl.stdout));
    }
    // Android resolution requires booted devices / AVD configs; report names only.
    final avds = await _runner.run('emulator', ['-list-avds']);
    final avdNames =
        avds.exitCode == 0 ? parseEmulatorList(avds.stdout) : <String>[];
    final map = selectBest(devices, const [FormFactor.iphone, FormFactor.ipad]);
    _out.writeln(const JsonEncoder.withIndent('  ').convert({
      'devices': devices.map((d) => d.toJson()).toList(),
      'selected': map.selected.map((k, v) => MapEntry(k.wire, v.toJson())),
      'gaps': map.gaps.map((g) => g.wire).toList(),
      'androidAvds': avdNames,
    }));
    return 0;
  }
}

class _NormalizeCommand extends Command<int> {
  final ProcessRunner _runner;
  _NormalizeCommand(this._runner) {
    argParser
      ..addOption('platform', allowed: ['ios', 'android'], mandatory: true)
      ..addOption('udid', help: 'iOS simulator UDID (required for ios)');
  }
  @override
  String get name => 'normalize';
  @override
  String get description => 'Set a clean status bar and disable animations.';

  @override
  Future<int> run() async {
    final platform = argResults!['platform'] as String;
    if (platform == 'ios') {
      final udid = argResults!['udid'] as String?;
      if (udid == null) {
        stderr.writeln('--udid is required for ios');
        return 64;
      }
      await _runner.run('xcrun', iosStatusBarArgv(udid));
      await _runner.run('xcrun', iosDisableAnimationsArgv(udid));
    } else {
      for (final argv in [
        ...androidDemoModeArgvs(),
        ...androidDisableAnimationsArgvs()
      ]) {
        await _runner.run('adb', argv);
      }
    }
    return 0;
  }
}

class _ValidateCommand extends Command<int> {
  final StringSink _out;
  _ValidateCommand(this._out) {
    argParser
      ..addOption('file', mandatory: true)
      ..addOption('target', mandatory: true, help: 'WIDTHxHEIGHT');
  }
  @override
  String get name => 'validate';
  @override
  String get description => 'Validate a captured screenshot.';

  @override
  Future<int> run() async {
    final targetStr = argResults!['target'] as String;
    final parts = targetStr.split('x');
    final w = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final h = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (w == null || h == null || w <= 0 || h <= 0) {
      stderr.writeln(
          '--target must be WIDTHxHEIGHT with two positive integers, got: "$targetStr"');
      return 64;
    }
    final result = validateImageBytes(
      bytes: File(argResults!['file'] as String).readAsBytesSync(),
      targetWidth: w,
      targetHeight: h,
    );
    _out.writeln(jsonEncode({
      'passed': result.passed,
      'width': result.width,
      'height': result.height,
      'warnings': result.warnings,
    }));
    return result.passed ? 0 : 1;
  }
}

class _RegenCheckCommand extends Command<int> {
  final StringSink _out;
  _RegenCheckCommand(this._out) {
    argParser
      ..addOption('config', mandatory: true)
      ..addOption('log', mandatory: true)
      ..addOption('hash', mandatory: true)
      ..addOption('raw-dir', defaultsTo: 'app_shots/screenshots/raw');
  }
  @override
  String get name => 'regen-check';
  @override
  String get description => 'List shot ids that need recapture.';

  @override
  Future<int> run() async {
    final plan =
        loadPlan(File(argResults!['config'] as String).readAsStringSync());
    final logFile = File(argResults!['log'] as String);
    final log = logFile.existsSync()
        ? CaptureLog.fromJsonString(logFile.readAsStringSync())
        : CaptureLog.empty();
    final ids = shotsNeedingRecapture(
      plan: plan,
      log: log,
      appBuildHash: argResults!['hash'] as String,
      fileExists: (p) => File(p).existsSync(),
    );
    _out.writeln(jsonEncode({'recapture': ids}));
    return 0;
  }
}

class _RecordCommand extends Command<int> {
  _RecordCommand() {
    argParser
      ..addOption('log', mandatory: true)
      ..addOption('id', mandatory: true)
      ..addOption('file', mandatory: true)
      ..addOption('platform', allowed: ['ios', 'android'], mandatory: true)
      ..addOption('form-factor',
          allowed: ['iphone', 'ipad', 'androidPhone', 'androidTablet'],
          mandatory: true)
      ..addOption('device', mandatory: true)
      ..addOption('width', mandatory: true)
      ..addOption('height', mandatory: true)
      ..addOption('tier',
          allowed: ['T1', 'T2', 'T3', 'T4', 'T5', 'T6'], mandatory: true)
      ..addOption('signature', mandatory: true)
      ..addOption('hash', mandatory: true)
      ..addOption('provider', defaultsTo: 'maestro_native')
      ..addOption('status', defaultsTo: 'passed')
      ..addFlag('synthetic', defaultsTo: false);
  }

  @override
  String get name => 'record';
  @override
  String get description => 'Upsert one CaptureResult into the capture log.';

  @override
  Future<int> run() async {
    final a = argResults!;
    final logFile = File(a['log'] as String);
    final log = logFile.existsSync()
        ? CaptureLog.fromJsonString(logFile.readAsStringSync())
        : CaptureLog.empty();
    final result = CaptureResult(
      id: a['id'] as String,
      file: a['file'] as String,
      platform: AppPlatform.fromWire(a['platform'] as String),
      formFactor: FormFactor.fromWire(a['form-factor'] as String),
      device: a['device'] as String,
      width: int.parse(a['width'] as String),
      height: int.parse(a['height'] as String),
      provider: CaptureProvider.fromWire(a['provider'] as String),
      tier: ReliabilityTier.fromWire(a['tier'] as String),
      synthetic: a['synthetic'] as bool,
      status: a['status'] as String,
      warnings: const [],
      signature: a['signature'] as String,
      appBuildHash: a['hash'] as String,
    );
    log.upsert(result);
    logFile.writeAsStringSync(log.toJsonString());
    return 0;
  }
}

class _SaveDevicesCommand extends Command<int> {
  final ProcessRunner _runner;
  _SaveDevicesCommand(this._runner) {
    argParser.addOption('config', mandatory: true);
  }

  @override
  String get name => 'save-devices';
  @override
  String get description =>
      'Audit devices and persist the device map into the config file.';

  @override
  Future<int> run() async {
    final configFile = File(argResults!['config'] as String);
    final simctl = await _runner
        .run('xcrun', ['simctl', 'list', 'devices', 'available', '--json']);
    final devices = <Device>[];
    if (simctl.exitCode == 0 && simctl.stdout.trim().isNotEmpty) {
      devices.addAll(parseSimctl(simctl.stdout));
    }
    await _runner.run('emulator', ['-list-avds']);
    // Android AVDs need separate resolution lookup; selectBest on parsed Device objects only.
    final map = selectBest(devices, [FormFactor.iphone, FormFactor.ipad]);
    final existingText =
        configFile.existsSync() ? configFile.readAsStringSync() : '';
    final updated = writeDevices(existingText, map);
    configFile.writeAsStringSync(updated);
    return 0;
  }
}

class _SavePlanCommand extends Command<int> {
  final StringSink _err;
  _SavePlanCommand(this._err) {
    argParser
      ..addOption('config', mandatory: true)
      ..addOption('plan', mandatory: true);
  }

  @override
  String get name => 'save-plan';
  @override
  String get description =>
      'Persist a plan JSON file into the config YAML file.';

  @override
  Future<int> run() async {
    final configFile = File(argResults!['config'] as String);
    final planFile = File(argResults!['plan'] as String);

    final ScreenshotPlan plan;
    try {
      final decoded = jsonDecode(planFile.readAsStringSync());
      plan = ScreenshotPlan.fromJson(decoded as Map);
    } on FormatException catch (e) {
      _err.writeln('Invalid plan JSON: ${e.message}');
      return 64;
    } on TypeError {
      _err.writeln('Invalid plan JSON: root must be an object');
      return 64;
    } on StateError {
      _err.writeln('Invalid plan: unknown form factor '
          '(choices: iphone, ipad, androidPhone, androidTablet)');
      return 64;
    }

    final List<String> stores;
    try {
      stores = parseStores(plan.stores);
    } on FormatException catch (e) {
      _err.writeln(e.message);
      return 64;
    }
    final storeSet = stores.toSet();
    final normalizedShots = <ShotSpec>[];
    for (final shot in plan.shots) {
      if (shot.formFactors.isEmpty && shot.deviceClasses.isEmpty) {
        _err.writeln('shot "${shot.id}" has no formFactors or deviceClasses '
            '(form factors: iphone, ipad, androidPhone, androidTablet; '
            'run list-targets for exact device classes)');
        return 64;
      }

      for (final ff in shot.formFactors) {
        if (!formFactorAllowedByStores(ff, storeSet)) {
          _err.writeln('shot "${shot.id}" form factor "${ff.wire}" '
              'belongs to store "${storeForFormFactor(ff)}", '
              'not in selected stores $stores');
          return 64;
        }
      }

      final exactTargets = <StoreTarget>[];
      for (final deviceClass in shot.deviceClasses) {
        final matches = storeTargets
            .where((target) => target.deviceClass == deviceClass)
            .toList();
        if (matches.isEmpty) {
          _err.writeln(
              'shot "${shot.id}" has unknown deviceClass "$deviceClass"; '
              'run list-targets for choices');
          return 64;
        }
        final target = matches.single;
        if (target.capture == null || target.formFactor == null) {
          _err.writeln('shot "${shot.id}" deviceClass "$deviceClass" is '
              'composition-only and cannot be used as a capture target');
          return 64;
        }
        if (!storeSet.contains(target.store)) {
          _err.writeln('shot "${shot.id}" deviceClass "$deviceClass" '
              'belongs to store "${target.store}", '
              'not in selected stores $stores');
          return 64;
        }
        if (!exactTargets
            .any((existing) => existing.deviceClass == target.deviceClass)) {
          exactTargets.add(target);
        }
      }

      final exactFormFactors = <FormFactor>[];
      for (final target in exactTargets) {
        final formFactor = target.formFactor!;
        if (!exactFormFactors.contains(formFactor)) {
          exactFormFactors.add(formFactor);
        }
      }
      if (exactFormFactors.isNotEmpty && shot.formFactors.isNotEmpty) {
        final declared = shot.formFactors.toSet();
        final derived = exactFormFactors.toSet();
        if (declared.length != derived.length ||
            !declared.containsAll(derived)) {
          _err.writeln('shot "${shot.id}" formFactors '
              '${shot.formFactors.map((ff) => ff.wire).toList()} do not match '
              'exact deviceClasses ${shot.deviceClasses}');
          return 64;
        }
      }

      normalizedShots.add(ShotSpec(
        id: shot.id,
        description: shot.description,
        route: shot.route,
        requiredState: shot.requiredState,
        selectors: shot.selectors,
        formFactors:
            exactFormFactors.isEmpty ? shot.formFactors : exactFormFactors,
        deviceClasses: exactTargets.isEmpty
            ? shot.deviceClasses
            : exactTargets.map((target) => target.deviceClass).toList(),
      ));
    }

    final normalizedPlan =
        ScreenshotPlan(stores: stores, shots: normalizedShots);
    final existingText =
        configFile.existsSync() ? configFile.readAsStringSync() : '';
    final updated = writePlan(existingText, normalizedPlan);
    configFile.writeAsStringSync(updated);
    return 0;
  }
}

class _GoldenScaffoldCommand extends Command<int> {
  final StringSink _out;
  final StringSink _err;

  _GoldenScaffoldCommand(this._out, this._err) {
    argParser
      ..addOption('config',
          mandatory: true, help: 'Config YAML containing the saved plan')
      ..addOption('app-dir', defaultsTo: '.', help: 'Target Flutter app root')
      ..addOption('golden-dir',
          defaultsTo: 'app_shots/golden',
          help: 'Harness suite directory, relative to --app-dir')
      ..addOption('out-dir',
          defaultsTo: 'app_shots/screenshots/golden',
          help: 'Capture output directory, relative to --app-dir');
  }

  @override
  String get name => 'golden-scaffold';

  @override
  String get description =>
      'Emit the golden capture harness suite for the saved plan into a '
      'target app (harnesses are write-once; the rest is regenerated).';

  @override
  Future<int> run() async {
    final a = argResults!;
    final configFile = File(a['config'] as String);
    if (!configFile.existsSync()) {
      _err.writeln('Config not found: ${configFile.path}');
      return 64;
    }
    final plan = loadPlan(configFile.readAsStringSync());
    if (plan.shots.isEmpty) {
      _err.writeln('Config has no shots; run save-plan first.');
      return 64;
    }
    final appDir = a['app-dir'] as String;
    final pubspec = File('$appDir/pubspec.yaml');
    final useGoogleFonts =
        pubspec.existsSync() && detectGoogleFonts(pubspec.readAsStringSync());

    final GoldenSuite suite;
    try {
      suite = renderGoldenSuite(
        plan: plan,
        goldenDir: a['golden-dir'] as String,
        outDir: a['out-dir'] as String,
        useGoogleFonts: useGoogleFonts,
      );
    } on FormatException catch (e) {
      _err.writeln(e.message);
      return 64;
    }

    final written = <String>[];
    final skipped = <String>[];
    void write(String rel, String content, {required bool ifAbsent}) {
      final file = File('$appDir/$rel');
      if (ifAbsent && file.existsSync()) {
        skipped.add(rel);
        return;
      }
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(content);
      written.add(rel);
    }

    suite.writeAlways.forEach((rel, c) => write(rel, c, ifAbsent: false));
    suite.writeIfAbsent.forEach((rel, c) => write(rel, c, ifAbsent: true));

    _out.writeln('Written:');
    for (final w in written) {
      _out.writeln('  $w');
    }
    if (skipped.isNotEmpty) {
      _out.writeln('Kept (write-once harnesses):');
      for (final s in skipped) {
        _out.writeln('  $s');
      }
    }
    _out.writeln('Next: fill the TODOs in each new harness with the real '
        'screen + fixed mocks, then from the app root run:');
    _out.writeln('  flutter test ${a['golden-dir']}/capture_test.dart');
    if (useGoogleFonts) {
      _out.writeln('Google Fonts detected: golden capture disables runtime '
          'font fetching. If app code calls GoogleFonts.* directly, copy those '
          'font files into <app>/google_fonts/ and include google_fonts/ in '
          'pubspec.yaml assets.');
    }
    return 0;
  }
}

class _LintCopyCommand extends Command<int> {
  final StringSink _out;
  _LintCopyCommand(this._out) {
    argParser
      ..addOption('store',
          allowed: ['app_store', 'play_store'], mandatory: true)
      ..addOption('text', mandatory: true);
  }

  @override
  String get name => 'lint-copy';
  @override
  String get description =>
      'Lint marketing copy against ranking/CTA claim rules for a store.';

  @override
  Future<int> run() async {
    final store = argResults!['store'] as String;
    final text = argResults!['text'] as String;
    final result = lintCopy(text, store);
    _out.writeln(const JsonEncoder.withIndent('  ').convert(result));
    return result.ok ? 0 : 1;
  }
}

class _BgPromptCommand extends Command<int> {
  final StringSink _out;
  final StringSink _err;
  _BgPromptCommand(this._out, this._err) {
    argParser
      ..addOption('device',
          mandatory: true, help: 'DeviceClass, e.g. iphone_6_9')
      ..addOption('tone',
          allowed: Tone.values.map((t) => t.name).toList(), mandatory: true)
      ..addOption('brand-color', mandatory: true)
      ..addOption('variant',
          defaultsTo: '0', help: 'Composition variant (0-based; wraps).');
  }

  @override
  String get name => 'bg-prompt';
  @override
  String get description =>
      'Emit the background image-generation prompt spec for a device/tone/brand.';

  @override
  Future<int> run() async {
    final deviceClass = argResults!['device'] as String;
    final matches =
        storeTargets.where((t) => t.deviceClass == deviceClass).toList();
    if (matches.isEmpty) {
      _err.writeln('Unknown device class: $deviceClass');
      return 64;
    }
    final tone = Tone.values.byName(argResults!['tone'] as String);
    final brandColor = argResults!['brand-color'] as String;
    final variant = int.tryParse(argResults!['variant'] as String) ?? 0;
    final spec =
        backgroundPromptSpec(matches.first, tone, brandColor, variant: variant);
    _out.writeln(const JsonEncoder.withIndent('  ').convert(spec));
    return 0;
  }
}

class _DoctorCommand extends Command<int> {
  final ProcessRunner _runner;
  final StringSink _out;

  _DoctorCommand(this._runner, this._out) {
    argParser
      ..addOption('app-dir', defaultsTo: '.', help: 'Target Flutter app root')
      ..addOption('tool-dir',
          defaultsTo: '.', help: 'app_shots tool package directory')
      ..addOption('renderer-dir',
          defaultsTo: '../renderer',
          help: 'app_shots renderer package directory')
      ..addOption('image-gen',
          allowed: ['true', 'false'],
          help: 'Whether the agent has an image-generation capability');
  }

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Report pure Dart/Flutter App Shots capabilities for golden mode.';

  @override
  Future<int> run() async {
    final facts = await _doctorFacts(
      runner: _runner,
      appDir: argResults!['app-dir'] as String,
      toolDir: argResults!['tool-dir'] as String,
      rendererDir: argResults!['renderer-dir'] as String,
      imageGenFlag: argResults!['image-gen'] as String?,
    );
    _out.writeln(const JsonEncoder.withIndent('  ')
        .convert(buildDoctorReport(facts).toJson()));
    return 0;
  }
}

class _PreflightCommand extends Command<int> {
  final ProcessRunner _runner;
  final StringSink _out;

  _PreflightCommand(this._runner, this._out) {
    argParser
      ..addOption('mode',
          allowed: AppShotsMode.values.map((mode) => mode.wire).toList(),
          mandatory: true,
          help: 'golden or live')
      ..addOption('app-dir', defaultsTo: '.', help: 'Target Flutter app root')
      ..addOption('tool-dir',
          defaultsTo: '.', help: 'app_shots tool package directory')
      ..addOption('renderer-dir',
          defaultsTo: '../renderer',
          help: 'app_shots renderer package directory')
      ..addFlag('boot',
          defaultsTo: false,
          negatable: false,
          help: 'In live mode, boot the selected simulator when needed');
  }

  @override
  String get name => 'preflight';

  @override
  String get description =>
      'Check whether golden or live screenshot capture can proceed.';

  @override
  Future<int> run() async {
    final appDir = argResults!['app-dir'] as String;
    final toolDir = argResults!['tool-dir'] as String;
    final rendererDir = argResults!['renderer-dir'] as String;
    final hasFlutter = await _commandOk(_runner, 'flutter', ['--version']);
    final toolResolved = _packageResolved(toolDir);
    final rendererResolved = _packageResolved(rendererDir);
    final targetAppPubspec = _targetAppPubspec(appDir);
    final mode = AppShotsMode.fromWire(argResults!['mode'] as String);

    if (mode == AppShotsMode.golden) {
      final verdict = buildGoldenPreflight(
        hasFlutter: hasFlutter,
        toolResolved: toolResolved,
        rendererResolved: rendererResolved,
        targetAppPubspec: targetAppPubspec,
      );
      _out.writeln(
          const JsonEncoder.withIndent('  ').convert(verdict.toJson()));
      return verdict.ready ? 0 : 1;
    }

    final hasXcode = await _commandOk(_runner, 'xcodebuild', ['-version']);
    final iosDevices = await _simctlDevices(_runner);
    var deviceDecision = decideLiveDevice(
      isMacos: Platform.isMacOS,
      hasXcode: hasXcode,
      iosDevices: iosDevices,
      boot: argResults!['boot'] as bool,
    );
    if (deviceDecision.action == LiveDeviceAction.bootDevice &&
        deviceDecision.udid != null) {
      final bootResult = await _runOrNull(
          _runner, 'xcrun', ['simctl', 'boot', deviceDecision.udid!]);
      if (bootResult?.exitCode != 0) {
        deviceDecision = LiveDeviceDecision(
          action: LiveDeviceAction.needsBoot,
          udid: deviceDecision.udid,
        );
      }
    }

    final maestroPresent = await _commandOk(_runner, 'maestro', ['--version']);
    final verdict = buildLivePreflight(
      hasFlutter: hasFlutter,
      toolResolved: toolResolved,
      rendererResolved: rendererResolved,
      targetAppPubspec: targetAppPubspec,
      isMacos: Platform.isMacOS,
      hasXcode: hasXcode,
      maestroPresent: maestroPresent,
      deviceDecision: deviceDecision,
    );
    _out.writeln(const JsonEncoder.withIndent('  ').convert(verdict.toJson()));
    return verdict.ready ? 0 : 1;
  }
}

class _ValidateOutputCommand extends Command<int> {
  final StringSink _out;
  final StringSink _err;
  _ValidateOutputCommand(this._out, this._err) {
    argParser
      ..addOption('file', mandatory: true, help: 'Path to the composed PNG')
      ..addOption('device',
          mandatory: true, help: 'DeviceClass, e.g. android_phone')
      ..addOption('overlay', help: 'Stamped textOverlayFraction, e.g. 0.24');
  }

  @override
  String get name => 'validate-output';
  @override
  String get description =>
      'Validate a composed store-output PNG against a StoreTarget '
      '(dims, format, alpha, overlay fraction, blank-image heuristic).';

  @override
  Future<int> run() async {
    final deviceClass = argResults!['device'] as String;
    final matches =
        storeTargets.where((t) => t.deviceClass == deviceClass).toList();
    if (matches.isEmpty) {
      _err.writeln('Unknown device class: $deviceClass');
      return 64;
    }
    final overlayStr = argResults!['overlay'] as String?;
    double? textOverlayFraction;
    if (overlayStr != null) {
      textOverlayFraction = double.tryParse(overlayStr);
      if (textOverlayFraction == null) {
        _err.writeln('--overlay must be a number, got: "$overlayStr"');
        return 64;
      }
    }
    final result = validateStoreOutput(
      bytes: File(argResults!['file'] as String).readAsBytesSync(),
      target: matches.first,
      textOverlayFraction: textOverlayFraction,
    );
    _out.writeln(const JsonEncoder.withIndent('  ').convert(result));
    return result.passed ? 0 : 1;
  }
}

class _ListTargetsCommand extends Command<int> {
  final StringSink _out;
  _ListTargetsCommand(this._out) {
    argParser.addOption('store', allowed: ['app_store', 'play_store']);
  }

  @override
  String get name => 'list-targets';
  @override
  String get description =>
      'List store screenshot targets, optionally filtered by --store.';

  @override
  Future<int> run() async {
    final store = argResults!['store'] as String?;
    final targets = store == null
        ? storeTargets
        : storeTargets.where((t) => t.store == store).toList();
    _out.writeln(const JsonEncoder.withIndent('  ').convert(targets));
    return 0;
  }
}

Future<DoctorFacts> _doctorFacts({
  required ProcessRunner runner,
  required String appDir,
  required String toolDir,
  required String rendererDir,
  required String? imageGenFlag,
}) async {
  final imageGeneration = imageGenFlag == null
      ? Platform.environment['APP_SHOTS_IMAGE_GEN'] == '1'
      : imageGenFlag == 'true';
  return DoctorFacts(
    hasFlutter: await _commandOk(runner, 'flutter', ['--version']),
    toolResolved: _packageResolved(toolDir),
    rendererResolved: _packageResolved(rendererDir),
    targetAppPubspec: _targetAppPubspec(appDir),
    targetAppPath: appDir,
    imageGeneration: imageGeneration,
  );
}

bool _packageResolved(String packageDir) =>
    File(path.join(packageDir, '.dart_tool', 'package_config.json'))
        .existsSync();

bool _targetAppPubspec(String appDir) =>
    File(path.join(appDir, 'pubspec.yaml')).existsSync();

Future<bool> _commandOk(
  ProcessRunner runner,
  String exe,
  List<String> args,
) async =>
    (await _runOrNull(runner, exe, args))?.exitCode == 0;

Future<ProcessResultData?> _runOrNull(
  ProcessRunner runner,
  String exe,
  List<String> args,
) async {
  try {
    return await runner.run(exe, args);
  } on Object {
    return null;
  }
}

Future<List<Device>> _simctlDevices(ProcessRunner runner) async {
  final result = await _runOrNull(
    runner,
    'xcrun',
    ['simctl', 'list', 'devices', 'available', '--json'],
  );
  if (result == null || result.exitCode != 0 || result.stdout.trim().isEmpty) {
    return const [];
  }
  try {
    return parseSimctl(result.stdout);
  } on Object {
    return const [];
  }
}

const _knownCssStyles = <String>{
  'solid',
  'gradient',
  'brand_block',
  'soft_shapes',
  'mesh',
  'spotlight',
  'bold_diagonal',
  'dots',
};

// Device-bearing layouts auto-assigned in order across distinct shot ids when
// an entry omits `layout`. Excludes full_bleed (drops the device) and
// dual_device (renders the screenshot twice) — those are explicit opt-in only.
// Index 0 is centered_device so the hero/first shot stays the safe layout.
const _layoutRotation = <ComposeLayout>[
  ComposeLayout.centeredDevice,
  ComposeLayout.tiltedDevice,
  ComposeLayout.featureCallout,
  ComposeLayout.textBanner,
];

class _ComposeManifestCommand extends Command<int> {
  final StringSink _out;
  final StringSink _err;

  _ComposeManifestCommand(this._out, this._err) {
    argParser
      ..addOption('spec',
          mandatory: true, help: 'Agent-authored composition spec JSON')
      ..addOption('out-dir',
          defaultsTo: 'app_shots/outputs',
          help: 'Base output directory for composed PNGs')
      ..addOption('manifest',
          help: 'Normalized manifest output path; defaults to '
              '../renderer/.compose/manifest.json when run from tool/');
  }

  @override
  String get name => 'compose-manifest';

  @override
  String get description =>
      'Normalize an agent-authored composition spec into the renderer manifest.';

  @override
  Future<int> run() async {
    final a = argResults!;
    final specFile = File(a['spec'] as String);
    if (!specFile.existsSync()) {
      _err.writeln('Spec not found: ${specFile.path}');
      return 64;
    }

    final Map spec;
    try {
      spec = jsonDecode(specFile.readAsStringSync()) as Map;
    } on FormatException catch (e) {
      _err.writeln('Invalid JSON spec: ${e.message}');
      return 64;
    } on TypeError {
      _err.writeln('Invalid JSON spec: root must be an object');
      return 64;
    }

    final brandColor = spec['brandColor'] as String?;

    final toneName = spec['tone'] as String?;
    if (toneName == null) {
      _err.writeln('Spec is missing required tone');
      return 64;
    }
    final Tone tone;
    try {
      tone = Tone.values.byName(toneName);
    } on ArgumentError {
      _err.writeln('Unknown tone: $toneName');
      return 64;
    }

    final List<String> stores;
    try {
      stores = parseStores(spec['stores']);
    } on FormatException catch (e) {
      _err.writeln(e.message);
      return 64;
    }

    final inputEntries = spec['entries'];
    if (inputEntries is! List || inputEntries.isEmpty) {
      _err.writeln('Spec must contain at least one entry');
      return 64;
    }

    final outDir = File(a['out-dir'] as String).absolute.path;
    final manifestPath = (a['manifest'] as String?) ??
        File(path.join('..', 'renderer', '.compose', 'manifest.json'))
            .absolute
            .path;
    final normalized = <Map<String, dynamic>>[];
    final specDir = specFile.absolute.parent.path;

    // Distinct non-deviceless shot ids in first-appearance order — the key for
    // layout rotation. Explicit overrides do not consume or shift indices.
    final distinctShotIds = <String>[];
    for (final e in inputEntries) {
      if (e is! Map) continue;
      if ((e['deviceless'] as bool?) ?? false) continue;
      final eid = e['id'] as String?;
      if (eid == null || eid.isEmpty) continue;
      if (!distinctShotIds.contains(eid)) distinctShotIds.add(eid);
    }

    for (final rawEntry in inputEntries) {
      if (rawEntry is! Map) {
        _err.writeln('Every entry must be an object');
        return 64;
      }
      final id = rawEntry['id'] as String?;
      final deviceClass = rawEntry['deviceClass'] as String?;
      final headline = rawEntry['headline'] as String?;
      if (id == null || id.isEmpty) {
        _err.writeln('Entry is missing required id');
        return 64;
      }
      if (deviceClass == null || deviceClass.isEmpty) {
        _err.writeln('Entry $id is missing required deviceClass');
        return 64;
      }
      if (headline == null || headline.isEmpty) {
        _err.writeln('Entry $id is missing required headline');
        return 64;
      }

      final target =
          storeTargets.where((t) => t.deviceClass == deviceClass).toList();
      if (target.isEmpty) {
        _err.writeln('Unknown device class: $deviceClass');
        return 64;
      }
      final storeTarget = target.first;
      if (!stores.contains(storeTarget.store)) {
        _err.writeln('Entry $id deviceClass $deviceClass belongs to store '
            '"${storeTarget.store}", not in selected stores $stores');
        return 64;
      }
      final deviceless = (rawEntry['deviceless'] as bool?) ?? false;

      final rawPath = rawEntry['raw'] as String?;
      String? normalizedRaw;
      if (!deviceless) {
        if (rawPath == null || rawPath.isEmpty) {
          _err.writeln('Missing raw screenshot for entry $id');
          return 64;
        }
        final rawFile = _resolveSpecFile(specDir, rawPath);
        if (!rawFile.existsSync()) {
          _err.writeln('Missing raw screenshot for entry $id: $rawPath');
          return 64;
        }
        normalizedRaw = rawFile.absolute.path;
      } else if (rawPath != null && rawPath.isNotEmpty) {
        final rawFile = _resolveSpecFile(specDir, rawPath);
        if (!rawFile.existsSync()) {
          _err.writeln('Missing raw screenshot for entry $id: $rawPath');
          return 64;
        }
        normalizedRaw = rawFile.absolute.path;
      }

      final ComposeLayout requestedLayout;
      if (deviceless) {
        requestedLayout = ComposeLayout.fullBleed;
      } else {
        final explicitLayout = rawEntry['layout'] as String?;
        if (explicitLayout != null) {
          try {
            requestedLayout = ComposeLayout.fromWire(explicitLayout);
          } on StateError {
            _err.writeln('Unknown layout for entry $id: $explicitLayout');
            return 64;
          }
        } else {
          final idx = distinctShotIds.indexOf(id);
          requestedLayout = _layoutRotation[idx % _layoutRotation.length];
        }
      }

      final rawBg = rawEntry['background'];
      if (rawBg is! Map) {
        _err.writeln('Entry $id is missing required background '
            '(kind: auto | image | css)');
        return 64;
      }
      final bgKind = rawBg['kind'] as String?;
      final ComposeBackground background;
      final Palette palette;
      if (bgKind == 'auto') {
        if (normalizedRaw == null) {
          _err.writeln('Entry $id background kind "auto" requires a raw '
              'screenshot (a deviceless entry cannot use auto)');
          return 64;
        }
        final autoStyle = (rawBg['style'] as String?) ?? 'gradient';
        if (!_knownCssStyles.contains(autoStyle)) {
          _err.writeln('Entry $id has unknown css style "$autoStyle" '
              '(choices: ${_knownCssStyles.join(', ')})');
          return 64;
        }
        palette = extractPaletteFromScreenshot(normalizedRaw);
        background = ComposeBackground(kind: 'css', style: autoStyle);
      } else if (bgKind == 'css') {
        if (brandColor == null || brandColor.isEmpty) {
          _err.writeln('Entry $id background kind "css" requires '
              'top-level brandColor');
          return 64;
        }
        final cssStyle = (rawBg['style'] as String?) ?? 'gradient';
        if (!_knownCssStyles.contains(cssStyle)) {
          _err.writeln('Entry $id has unknown css style "$cssStyle" '
              '(choices: ${_knownCssStyles.join(', ')})');
          return 64;
        }
        palette = paletteFor(tone, brandColor);
        background = ComposeBackground(kind: 'css', style: cssStyle);
      } else if (bgKind == 'image') {
        if (brandColor == null || brandColor.isEmpty) {
          _err.writeln('Entry $id background kind "image" requires '
              'top-level brandColor');
          return 64;
        }
        final imagePath = rawBg['path'] as String?;
        if (imagePath == null || imagePath.isEmpty) {
          _err.writeln('Entry $id background kind "image" requires a path');
          return 64;
        }
        final bgFile = _resolveSpecFile(specDir, imagePath);
        if (!bgFile.existsSync()) {
          _err.writeln('Missing background image for entry $id: $imagePath');
          return 64;
        }
        palette = paletteFor(tone, brandColor);
        background =
            ComposeBackground(kind: 'image', path: bgFile.absolute.path);
      } else {
        _err.writeln('Entry $id has invalid background kind "$bgKind" '
            '(choices: auto, image, css)');
        return 64;
      }

      final logoPath = rawEntry['logo'] as String?;
      String? normalizedLogo;
      if (logoPath != null && logoPath.isNotEmpty) {
        final logoFile = _resolveSpecFile(specDir, logoPath);
        if (!logoFile.existsSync()) {
          _err.writeln('Missing logo for entry $id: $logoPath');
          return 64;
        }
        normalizedLogo = logoFile.absolute.path;
      }

      final subheadline = rawEntry['subheadline'] as String?;
      final entry = ComposeEntry(
        id: id,
        deviceClass: deviceClass,
        headline: headline,
        out: path.join(outDir, storeTarget.store, deviceClass, '$id.png'),
        subheadline: subheadline,
        raw: normalizedRaw,
        logo: normalizedLogo,
        tone: tone,
        layout: requestedLayout,
        brandColor: brandColor,
        background: background,
        deviceless: deviceless,
        palette: palette,
      );

      final lintIssues = <String>[
        ...lintCopy(headline, storeTarget.store).issues,
        if (subheadline != null)
          ...lintCopy(subheadline, storeTarget.store).issues,
      ];
      final entryJson = entry.toJson()
        ..['textOverlayFraction'] = textOverlayFraction(
          requestedLayout,
          hasSubheadline: subheadline != null,
        )
        ..['lint'] = {
          'ok': lintIssues.isEmpty,
          'issues': lintIssues,
        };
      normalized.add(entryJson);
    }

    final manifestFile = File(manifestPath);
    manifestFile.parent.createSync(recursive: true);
    manifestFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({'entries': normalized}));
    _out.writeln('Wrote ${manifestFile.path}');
    _out.writeln('Next: cd ../renderer && flutter test test/compose_test.dart');
    return 0;
  }

  File _resolveSpecFile(String specDir, String filePath) {
    if (path.isAbsolute(filePath)) return File(filePath);
    return File(path.join(specDir, filePath));
  }
}
