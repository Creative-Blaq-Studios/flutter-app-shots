import 'package:app_shots/src/models.dart';
import 'package:test/test.dart';

void main() {
  test('enum wire values are stable', () {
    expect(FormFactor.androidPhone.wire, 'androidPhone');
    expect(FormFactor.fromWire('ipad'), FormFactor.ipad);
    expect(ReliabilityTier.t4.wire, 'T4');
    expect(ReliabilityTier.fromWire('T1'), ReliabilityTier.t1);
    expect(CaptureProvider.maestroNative.wire, 'maestro_native');
  });

  test('Device JSON round-trips', () {
    const d = Device(
      id: 'UDID-1',
      name: 'iPhone 16 Pro Max',
      platform: AppPlatform.ios,
      formFactor: FormFactor.iphone,
      widthPx: 1320,
      heightPx: 2868,
      isBooted: true,
    );
    expect(Device.fromJson(d.toJson()).toJson(), d.toJson());
    expect(d.pixelCount, 1320 * 2868);
  });

  test('ShotSpec signature changes when route/state/selectors change', () {
    const base = ShotSpec(
      id: 'hero',
      description: 'wallets',
      route: '/wallets',
      requiredState: RequiredState(auth: true, seeded: true, notes: null),
      selectors: [
        SelectorStep(
            step: 'open',
            selector: 'tapOn: "Wallets"',
            tier: ReliabilityTier.t1)
      ],
      formFactors: [FormFactor.iphone],
    );
    final changedRoute = ShotSpec(
      id: base.id,
      description: base.description,
      route: '/home',
      requiredState: base.requiredState,
      selectors: base.selectors,
      formFactors: base.formFactors,
    );
    expect(base.signature(), isNot(changedRoute.signature()));
  });

  test('ShotSpec exact device classes round-trip and affect its signature', () {
    const exact = ShotSpec(
      id: 'hero',
      description: 'wallets',
      route: '/wallets',
      requiredState: RequiredState(auth: true, seeded: true),
      selectors: [],
      formFactors: [FormFactor.iphone],
      deviceClasses: ['iphone_6_9'],
    );
    final roundTrip = ShotSpec.fromJson(exact.toJson());
    expect(roundTrip.deviceClasses, ['iphone_6_9']);

    const otherSize = ShotSpec(
      id: 'hero',
      description: 'wallets',
      route: '/wallets',
      requiredState: RequiredState(auth: true, seeded: true),
      selectors: [],
      formFactors: [FormFactor.iphone],
      deviceClasses: ['iphone_6_5'],
    );
    expect(exact.signature(), isNot(otherSize.signature()));
  });

  test('CaptureResult JSON round-trips', () {
    const r = CaptureResult(
      id: 'hero',
      file: 'raw/hero_iphone_raw.png',
      platform: AppPlatform.ios,
      formFactor: FormFactor.iphone,
      device: 'UDID-1',
      width: 1320,
      height: 2868,
      provider: CaptureProvider.maestroNative,
      tier: ReliabilityTier.t1,
      synthetic: false,
      status: 'passed',
      warnings: [],
      signature: 'sig',
      appBuildHash: 'abc',
    );
    expect(CaptureResult.fromJson(r.toJson()).toJson(), r.toJson());
  });
}
