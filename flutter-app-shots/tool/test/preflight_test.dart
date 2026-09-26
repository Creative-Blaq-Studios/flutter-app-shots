import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/preflight.dart';
import 'package:test/test.dart';

Device _ios(String id, int width, int height, {bool booted = false}) => Device(
      id: id,
      name: id,
      platform: AppPlatform.ios,
      formFactor: FormFactor.iphone,
      widthPx: width,
      heightPx: height,
      isBooted: booted,
    );

void main() {
  test('AppShotsMode parses stable wire values', () {
    expect(AppShotsMode.fromWire('golden'), AppShotsMode.golden);
    expect(AppShotsMode.fromWire('live'), AppShotsMode.live);
  });

  test('golden preflight ignores Xcode, simulators, Maestro, and Node', () {
    final verdict = buildGoldenPreflight(
      hasFlutter: true,
      toolResolved: true,
      rendererResolved: true,
      targetAppPubspec: true,
    );

    expect(verdict.mode, AppShotsMode.golden);
    expect(verdict.ready, true);
    expect(verdict.nextStep, 'run-golden-scaffold');
    expect((verdict.toJson()['checks'] as Map).keys, isNot(contains('xcode')));
    expect(
        (verdict.toJson()['checks'] as Map).keys, isNot(contains('maestro')));
    expect((verdict.toJson()['checks'] as Map).keys, isNot(contains('node')));
  });

  test('golden preflight reports setup gaps', () {
    final verdict = buildGoldenPreflight(
      hasFlutter: true,
      toolResolved: false,
      rendererResolved: true,
      targetAppPubspec: false,
    );

    expect(verdict.ready, false);
    expect(verdict.setupGaps, contains('tool: run `dart pub get` in tool/'));
    expect(verdict.setupGaps, contains('target app: pubspec.yaml not found'));
    expect(verdict.nextStep, 'fix-setup-gaps');
  });

  test('live device decision reuses highest resolution booted simulator', () {
    final decision = decideLiveDevice(
      isMacos: true,
      hasXcode: true,
      iosDevices: [
        _ios('small', 1170, 2532, booted: true),
        _ios('large', 1320, 2868, booted: true),
      ],
      boot: false,
    );

    expect(decision.action, LiveDeviceAction.reuseBooted);
    expect(decision.udid, 'large');
  });

  test('live preflight requires macOS, Xcode, a simulator, and Maestro', () {
    final verdict = buildLivePreflight(
      hasFlutter: true,
      toolResolved: true,
      rendererResolved: true,
      targetAppPubspec: true,
      isMacos: true,
      hasXcode: true,
      maestroPresent: false,
      deviceDecision: const LiveDeviceDecision(
        action: LiveDeviceAction.needsBoot,
        udid: 'U1',
      ),
    );

    expect(verdict.ready, false);
    expect(
      verdict.setupGaps,
      contains(
        'maestro: install with `curl -Ls https://get.maestro.mobile.dev | bash`',
      ),
    );
    expect(verdict.nextStep, 'install-maestro');
  });
}
