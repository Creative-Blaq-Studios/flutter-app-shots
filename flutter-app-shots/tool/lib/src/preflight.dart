import 'models.dart';

const String kMaestroInstallCmd =
    'curl -Ls https://get.maestro.mobile.dev | bash';

enum AppShotsMode {
  golden('golden'),
  live('live');

  final String wire;
  const AppShotsMode(this.wire);

  static AppShotsMode fromWire(String wire) =>
      AppShotsMode.values.firstWhere((mode) => mode.wire == wire);
}

enum LiveDeviceAction {
  unavailable('unavailable'),
  noDevice('no_device'),
  reuseBooted('reuse_booted'),
  needsBoot('needs_boot'),
  bootDevice('boot_device');

  final String wire;
  const LiveDeviceAction(this.wire);
}

class LiveDeviceDecision {
  final LiveDeviceAction action;
  final String? udid;

  const LiveDeviceDecision({required this.action, this.udid});

  bool get ready =>
      action == LiveDeviceAction.reuseBooted ||
      action == LiveDeviceAction.bootDevice;

  Map<String, dynamic> toJson() => {
        'action': action.wire,
        if (udid != null) 'udid': udid,
      };
}

class PreflightVerdict {
  final AppShotsMode mode;
  final bool ready;
  final Map<String, bool> checks;
  final List<String> setupGaps;
  final String nextStep;
  final LiveDeviceDecision? liveDevice;

  const PreflightVerdict({
    required this.mode,
    required this.ready,
    required this.checks,
    required this.setupGaps,
    required this.nextStep,
    this.liveDevice,
  });

  Map<String, dynamic> toJson() => {
        'mode': mode.wire,
        'ready': ready,
        'checks': checks,
        'setupGaps': setupGaps,
        'nextStep': nextStep,
        if (liveDevice != null) 'liveDevice': liveDevice!.toJson(),
      };
}

PreflightVerdict buildGoldenPreflight({
  required bool hasFlutter,
  required bool toolResolved,
  required bool rendererResolved,
  required bool targetAppPubspec,
}) {
  final checks = {
    'flutter': hasFlutter,
    'toolResolved': toolResolved,
    'rendererResolved': rendererResolved,
    'targetAppPubspec': targetAppPubspec,
  };
  final setupGaps = _goldenSetupGaps(
    hasFlutter: hasFlutter,
    toolResolved: toolResolved,
    rendererResolved: rendererResolved,
    targetAppPubspec: targetAppPubspec,
  );
  return PreflightVerdict(
    mode: AppShotsMode.golden,
    ready: setupGaps.isEmpty,
    checks: checks,
    setupGaps: setupGaps,
    nextStep: setupGaps.isEmpty ? 'run-golden-scaffold' : 'fix-setup-gaps',
  );
}

LiveDeviceDecision decideLiveDevice({
  required bool isMacos,
  required bool hasXcode,
  required List<Device> iosDevices,
  required bool boot,
}) {
  if (!isMacos || !hasXcode) {
    return const LiveDeviceDecision(action: LiveDeviceAction.unavailable);
  }
  final booted = iosDevices.where((device) => device.isBooted).toList()
    ..sort((a, b) => b.pixelCount.compareTo(a.pixelCount));
  if (booted.isNotEmpty) {
    return LiveDeviceDecision(
      action: LiveDeviceAction.reuseBooted,
      udid: booted.first.id,
    );
  }
  if (iosDevices.isEmpty) {
    return const LiveDeviceDecision(action: LiveDeviceAction.noDevice);
  }
  final best = ([...iosDevices]
        ..sort((a, b) => b.pixelCount.compareTo(a.pixelCount)))
      .first;
  return LiveDeviceDecision(
    action: boot ? LiveDeviceAction.bootDevice : LiveDeviceAction.needsBoot,
    udid: best.id,
  );
}

PreflightVerdict buildLivePreflight({
  required bool hasFlutter,
  required bool toolResolved,
  required bool rendererResolved,
  required bool targetAppPubspec,
  required bool isMacos,
  required bool hasXcode,
  required bool maestroPresent,
  required LiveDeviceDecision deviceDecision,
}) {
  final checks = {
    'flutter': hasFlutter,
    'toolResolved': toolResolved,
    'rendererResolved': rendererResolved,
    'targetAppPubspec': targetAppPubspec,
    'macos': isMacos,
    'xcode': hasXcode,
    'maestro': maestroPresent,
    'iosDeviceReady': deviceDecision.ready,
  };
  final setupGaps = [
    ..._goldenSetupGaps(
      hasFlutter: hasFlutter,
      toolResolved: toolResolved,
      rendererResolved: rendererResolved,
      targetAppPubspec: targetAppPubspec,
    ),
    if (!isMacos) 'live mode: macOS is required for iOS simulator capture',
    if (isMacos && !hasXcode) 'live mode: Xcode command line tools not found',
    if (deviceDecision.action == LiveDeviceAction.noDevice)
      'live mode: no available iOS simulators found',
    if (deviceDecision.action == LiveDeviceAction.needsBoot)
      'live mode: boot a simulator or rerun with --boot',
    if (!maestroPresent) 'maestro: install with `$kMaestroInstallCmd`',
  ];
  final ready = setupGaps.isEmpty && deviceDecision.ready;
  return PreflightVerdict(
    mode: AppShotsMode.live,
    ready: ready,
    checks: checks,
    setupGaps: setupGaps,
    nextStep: _liveNextStep(
      setupGaps: setupGaps,
      maestroPresent: maestroPresent,
      deviceDecision: deviceDecision,
      ready: ready,
    ),
    liveDevice: deviceDecision,
  );
}

List<String> _goldenSetupGaps({
  required bool hasFlutter,
  required bool toolResolved,
  required bool rendererResolved,
  required bool targetAppPubspec,
}) =>
    [
      if (!hasFlutter) 'flutter: install Flutter or add it to PATH',
      if (!toolResolved) 'tool: run `dart pub get` in tool/',
      if (!rendererResolved) 'renderer: run `flutter pub get` in renderer/',
      if (!targetAppPubspec) 'target app: pubspec.yaml not found',
    ];

String _liveNextStep({
  required List<String> setupGaps,
  required bool maestroPresent,
  required LiveDeviceDecision deviceDecision,
  required bool ready,
}) {
  if (ready) return 'run-live-capture';
  if (!maestroPresent) return 'install-maestro';
  if (deviceDecision.action == LiveDeviceAction.needsBoot ||
      deviceDecision.action == LiveDeviceAction.noDevice) {
    return 'boot-simulator';
  }
  if (setupGaps.isNotEmpty) return 'fix-setup-gaps';
  return 'fallback-required';
}
