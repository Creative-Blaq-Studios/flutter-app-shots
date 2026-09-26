import 'package:app_shots/src/config_store.dart';
import 'package:app_shots/src/device_auditor.dart';
import 'package:app_shots/src/models.dart';
import 'package:test/test.dart';

const _yaml = '''
version: 1
plan:
  - id: hero
    description: Wallet list
    route: /wallets
    requiredState:
      auth: true
      seeded: true
    selectors:
      - step: open wallets
        selector: 'tapOn: "Wallets"'
        tier: T1
    formFactors:
      - iphone
''';

void main() {
  test('loadPlan reads shots with selectors and form-factors', () {
    final plan = loadPlan(_yaml);
    expect(plan.shots, hasLength(1));
    final shot = plan.shots.single;
    expect(shot.id, 'hero');
    expect(shot.route, '/wallets');
    expect(shot.requiredState.auth, isTrue);
    expect(shot.selectors.single.tier, ReliabilityTier.t1);
    expect(shot.formFactors, [FormFactor.iphone]);
  });

  test('writeDevices upserts a devices block that round-trips', () {
    const device = Device(
        id: 'U1',
        name: 'iPhone 16 Pro Max',
        platform: AppPlatform.ios,
        formFactor: FormFactor.iphone,
        widthPx: 1320,
        heightPx: 2868,
        isBooted: false);
    final map =
        DeviceMap(selected: {FormFactor.iphone: device}, gaps: const []);
    final updated = writeDevices('version: 1\n', map);
    expect(updated, contains('devices:'));
    expect(updated, contains('iphone:'));
    expect(updated, contains('1320'));
    // Re-loading the plan from the updated YAML must not throw.
    expect(loadPlan(updated).shots, isEmpty);
  });

  test('writeDevices throws ArgumentError if YAML root is a list, not a map',
      () {
    const device = Device(
        id: 'U1',
        name: 'iPhone 16 Pro Max',
        platform: AppPlatform.ios,
        formFactor: FormFactor.iphone,
        widthPx: 1320,
        heightPx: 2868,
        isBooted: false);
    final map =
        DeviceMap(selected: {FormFactor.iphone: device}, gaps: const []);
    expect(
      () => writeDevices('- a\n- b\n', map),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('writeDevices succeeds on empty input', () {
    const device = Device(
        id: 'U1',
        name: 'iPhone 16 Pro Max',
        platform: AppPlatform.ios,
        formFactor: FormFactor.iphone,
        widthPx: 1320,
        heightPx: 2868,
        isBooted: false);
    final map =
        DeviceMap(selected: {FormFactor.iphone: device}, gaps: const []);
    final result = writeDevices('', map);
    expect(result, contains('devices:'));
  });

  test('writeDevices succeeds on valid map input', () {
    const device = Device(
        id: 'U1',
        name: 'iPhone 16 Pro Max',
        platform: AppPlatform.ios,
        formFactor: FormFactor.iphone,
        widthPx: 1320,
        heightPx: 2868,
        isBooted: false);
    final map =
        DeviceMap(selected: {FormFactor.iphone: device}, gaps: const []);
    final result = writeDevices('version: 1\n', map);
    expect(result, contains('devices:'));
  });

  test('writePlan upserts a plan block readable by loadPlan', () {
    const shot = ShotSpec(
        id: 'budget',
        description: 'Budgets',
        route: '/budget',
        requiredState: RequiredState(auth: true, seeded: false, notes: null),
        selectors: [],
        formFactors: [FormFactor.androidPhone],
        deviceClasses: ['android_phone']);
    final updated = writePlan('version: 1\n', ScreenshotPlan(shots: [shot]));
    final reloaded = loadPlan(updated);
    expect(reloaded.shots.single.id, 'budget');
    expect(reloaded.shots.single.formFactors, [FormFactor.androidPhone]);
    expect(reloaded.shots.single.deviceClasses, ['android_phone']);
  });
}
