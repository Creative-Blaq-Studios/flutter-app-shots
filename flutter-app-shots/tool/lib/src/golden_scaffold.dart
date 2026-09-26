// flutter-app-shots/tool/lib/src/golden_scaffold.dart
import 'package:yaml/yaml.dart';

import 'golden_templates.dart';
import 'models.dart';
import 'store_specs.dart';

/// The rendered golden suite: [writeAlways] files are regenerated every run;
/// [writeIfAbsent] files (per-shot harnesses) are written once and then owned
/// by the developer. Keys are app-root-relative paths.
class GoldenSuite {
  final Map<String, String> writeAlways;
  final Map<String, String> writeIfAbsent;
  const GoldenSuite({required this.writeAlways, required this.writeIfAbsent});
}

/// Lowercases [raw] and maps every non `[a-z0-9_]` rune to `_`; prefixes
/// `s_` when the result starts with a digit. Used for harness file names and
/// import prefixes.
String dartIdentifier(String raw) {
  final cleaned = raw
      .toLowerCase()
      .split('')
      .map((ch) => RegExp(r'[a-z0-9_]').hasMatch(ch) ? ch : '_')
      .join();
  return RegExp(r'^[0-9]').hasMatch(cleaned) ? 's_$cleaned' : cleaned;
}

/// True when the app's pubspec declares a google_fonts dependency.
bool detectGoogleFonts(String pubspecYaml) {
  if (pubspecYaml.trim().isEmpty) return false;
  final Object? doc;
  try {
    doc = loadYaml(pubspecYaml);
  } catch (_) {
    // Malformed YAML (parse errors, unsupported constructs, etc.) means the
    // pubspec can't be trusted for dependency detection — treat as "no
    // google_fonts" rather than propagating a stack trace to the caller.
    return false;
  }
  if (doc is! Map) return false;
  for (final section in ['dependencies', 'dev_dependencies']) {
    final deps = doc[section];
    if (deps is Map && deps.containsKey('google_fonts')) return true;
  }
  return false;
}

/// Shot ids become file names, import prefixes, and are interpolated
/// directly into generated Dart source (as string literals and identifier
/// fragments), so they're restricted to a safe, predictable charset.
final RegExp _shotIdPattern = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

GoldenSuite renderGoldenSuite({
  required ScreenshotPlan plan,
  required String goldenDir,
  required String outDir,
  required bool useGoogleFonts,
}) {
  for (final s in plan.shots) {
    if (!_shotIdPattern.hasMatch(s.id)) {
      throw FormatException(
          'Invalid shot id "${s.id}": shot ids must match pattern '
          '${_shotIdPattern.pattern} (lowercase letters and digits, '
          'optionally followed by lowercase letters, digits, "_" or "-").');
    }
  }
  for (final MapEntry(key: name, value: value) in {
    'goldenDir': goldenDir,
    'outDir': outDir,
  }.entries) {
    if (value.contains('\\') || value.contains("'")) {
      throw FormatException(
          'Invalid $name "$value": must not contain backslashes or single '
          'quotes, since it is interpolated into generated Dart string '
          'literals.');
    }
  }

  final shotInfos = plan.shots
      .map((s) => (
            id: s.id,
            prefix: '${dartIdentifier(s.id)}_harness',
            deviceClasses: captureTargetsForSelection(
              formFactors: s.formFactors,
              deviceClasses: s.deviceClasses,
            ).map((t) => t.deviceClass).toList(),
          ))
      .toList();

  final seenPrefixes = <String, String>{};
  for (final s in shotInfos) {
    final firstId = seenPrefixes[s.prefix];
    if (firstId != null) {
      throw FormatException(
          'Shot ids "$firstId" and "${s.id}" both sanitize to the same '
          'harness prefix "${s.prefix}"; rename one of them to avoid a '
          'harness/import collision.');
    }
    seenPrefixes[s.prefix] = s.id;
  }

  final usedClasses = shotInfos.expand((s) => s.deviceClasses).toSet();
  final devices =
      storeTargets.where((t) => usedClasses.contains(t.deviceClass)).toList();

  return GoldenSuite(
    writeAlways: {
      '$goldenDir/flutter_test_config.dart': renderGoldenTestConfig(
          goldenDir: goldenDir, useGoogleFonts: useGoogleFonts),
      '$goldenDir/status_bar.dart': kGoldenStatusBarFile,
      '$goldenDir/capture_test.dart': renderGoldenCaptureTest(
        shots: shotInfos,
        devices: devices,
        outDir: outDir,
        selfPath: '$goldenDir/capture_test.dart',
      ),
    },
    writeIfAbsent: {
      for (final s in shotInfos)
        '$goldenDir/harness/${s.prefix}.dart':
            renderGoldenHarness(shotId: s.id),
    },
  );
}
