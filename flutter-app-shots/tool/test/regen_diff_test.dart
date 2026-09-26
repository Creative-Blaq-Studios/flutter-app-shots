import 'package:app_shots/src/capture_log.dart';
import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/regen_diff.dart';
import 'package:test/test.dart';

ShotSpec _shot(String id, {String route = '/x'}) => ShotSpec(
      id: id, description: id, route: route,
      requiredState: const RequiredState(auth: false, seeded: false, notes: null),
      selectors: const [], formFactors: const [FormFactor.iphone],
    );

CaptureResult _result(ShotSpec shot, {String hash = 'h1', String? file}) =>
    CaptureResult(
      id: shot.id, file: file ?? 'raw/${shot.id}.png', platform: AppPlatform.ios,
      formFactor: FormFactor.iphone, device: 'U1', width: 1320, height: 2868,
      provider: CaptureProvider.maestroNative, tier: ReliabilityTier.t1,
      synthetic: false, status: 'passed', warnings: const [],
      signature: shot.signature(), appBuildHash: hash,
    );

void main() {
  test('recaptures shots with no prior result', () {
    final plan = ScreenshotPlan(shots: [_shot('a')]);
    final ids = shotsNeedingRecapture(
        plan: plan, log: CaptureLog.empty(), appBuildHash: 'h1',
        fileExists: (_) => true);
    expect(ids, ['a']);
  });

  test('skips unchanged shots with the same hash, signature and existing file', () {
    final shot = _shot('a');
    final log = CaptureLog.empty()..upsert(_result(shot, hash: 'h1'));
    final ids = shotsNeedingRecapture(
        plan: ScreenshotPlan(shots: [shot]), log: log, appBuildHash: 'h1',
        fileExists: (_) => true);
    expect(ids, isEmpty);
  });

  test('recaptures when the app build hash changes', () {
    final shot = _shot('a');
    final log = CaptureLog.empty()..upsert(_result(shot, hash: 'old'));
    final ids = shotsNeedingRecapture(
        plan: ScreenshotPlan(shots: [shot]), log: log, appBuildHash: 'new',
        fileExists: (_) => true);
    expect(ids, ['a']);
  });

  test('recaptures when the plan signature changes', () {
    final old = _shot('a', route: '/old');
    final log = CaptureLog.empty()..upsert(_result(old, hash: 'h1'));
    final changed = _shot('a', route: '/new');
    final ids = shotsNeedingRecapture(
        plan: ScreenshotPlan(shots: [changed]), log: log, appBuildHash: 'h1',
        fileExists: (_) => true);
    expect(ids, ['a']);
  });

  test('recaptures when the raw file is missing', () {
    final shot = _shot('a');
    final log = CaptureLog.empty()..upsert(_result(shot, hash: 'h1'));
    final ids = shotsNeedingRecapture(
        plan: ScreenshotPlan(shots: [shot]), log: log, appBuildHash: 'h1',
        fileExists: (_) => false);
    expect(ids, ['a']);
  });
}
