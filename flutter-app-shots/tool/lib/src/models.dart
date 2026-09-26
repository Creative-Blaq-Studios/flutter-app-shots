enum AppPlatform {
  ios('ios'),
  android('android');

  final String wire;
  const AppPlatform(this.wire);
  static AppPlatform fromWire(String w) =>
      AppPlatform.values.firstWhere((e) => e.wire == w);
}

enum FormFactor {
  iphone('iphone'),
  ipad('ipad'),
  androidPhone('androidPhone'),
  androidTablet('androidTablet');

  final String wire;
  const FormFactor(this.wire);
  static FormFactor fromWire(String w) =>
      FormFactor.values.firstWhere((e) => e.wire == w);
}

enum ReliabilityTier {
  t1('T1'),
  t2('T2'),
  t3('T3'),
  t4('T4'),
  t5('T5'),
  t6('T6');

  final String wire;
  const ReliabilityTier(this.wire);
  static ReliabilityTier fromWire(String w) =>
      ReliabilityTier.values.firstWhere((e) => e.wire == w);
}

enum CaptureProvider {
  maestroNative('maestro_native'),
  manualUpload('manual_upload'),
  syntheticGolden('synthetic_golden'),
  webViewport('web_viewport');

  final String wire;
  const CaptureProvider(this.wire);
  static CaptureProvider fromWire(String w) =>
      CaptureProvider.values.firstWhere((e) => e.wire == w);
}

class Device {
  final String id;
  final String name;
  final AppPlatform platform;
  final FormFactor formFactor;
  final int widthPx;
  final int heightPx;
  final bool isBooted;

  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.formFactor,
    required this.widthPx,
    required this.heightPx,
    required this.isBooted,
  });

  int get pixelCount => widthPx * heightPx;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform.wire,
        'formFactor': formFactor.wire,
        'widthPx': widthPx,
        'heightPx': heightPx,
        'isBooted': isBooted,
      };

  static Device fromJson(Map json) => Device(
        id: json['id'] as String,
        name: json['name'] as String,
        platform: AppPlatform.fromWire(json['platform'] as String),
        formFactor: FormFactor.fromWire(json['formFactor'] as String),
        widthPx: json['widthPx'] as int,
        heightPx: json['heightPx'] as int,
        isBooted: json['isBooted'] as bool,
      );
}

class SelectorStep {
  final String step;
  final String selector;
  final ReliabilityTier tier;
  const SelectorStep(
      {required this.step, required this.selector, required this.tier});

  Map<String, dynamic> toJson() =>
      {'step': step, 'selector': selector, 'tier': tier.wire};

  static SelectorStep fromJson(Map json) => SelectorStep(
        step: json['step'] as String,
        selector: json['selector'] as String,
        tier: ReliabilityTier.fromWire(json['tier'] as String),
      );
}

class RequiredState {
  final bool auth;
  final bool seeded;
  final String? notes;
  const RequiredState({required this.auth, required this.seeded, this.notes});

  Map<String, dynamic> toJson() =>
      {'auth': auth, 'seeded': seeded, if (notes != null) 'notes': notes};

  static RequiredState fromJson(Map json) => RequiredState(
        auth: (json['auth'] as bool?) ?? false,
        seeded: (json['seeded'] as bool?) ?? false,
        notes: json['notes'] as String?,
      );
}

class ShotSpec {
  final String id;
  final String description;
  final String? route;
  final RequiredState requiredState;
  final List<SelectorStep> selectors;
  final List<FormFactor> formFactors;

  /// Exact store capture targets selected by the user, such as
  /// `iphone_6_9` or `android_tablet_10`. When non-empty, this narrows the
  /// broader [formFactors] selection. Older plans may omit it and keep the
  /// form-factor expansion behavior.
  final List<String> deviceClasses;

  const ShotSpec({
    required this.id,
    required this.description,
    required this.route,
    required this.requiredState,
    required this.selectors,
    required this.formFactors,
    this.deviceClasses = const [],
  });

  String signature() {
    final sel = selectors
        .map((s) => '${s.step}=${s.selector}@${s.tier.wire}')
        .join('|');
    final ff = formFactors.map((f) => f.wire).join(',');
    final dc = deviceClasses.join(',');
    return 'route=${route ?? ''};auth=${requiredState.auth};'
        'seeded=${requiredState.seeded};sel=$sel;ff=$ff;dc=$dc';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        if (route != null) 'route': route,
        'requiredState': requiredState.toJson(),
        'selectors': selectors.map((s) => s.toJson()).toList(),
        'formFactors': formFactors.map((f) => f.wire).toList(),
        if (deviceClasses.isNotEmpty) 'deviceClasses': deviceClasses,
      };

  static ShotSpec fromJson(Map json) => ShotSpec(
        id: json['id'] as String,
        description: json['description'] as String,
        route: json['route'] as String?,
        requiredState:
            RequiredState.fromJson((json['requiredState'] as Map?) ?? const {}),
        selectors: ((json['selectors'] as List?) ?? const [])
            .map((s) => SelectorStep.fromJson(s as Map))
            .toList(),
        formFactors: ((json['formFactors'] as List?) ?? const [])
            .map((f) => FormFactor.fromWire(f as String))
            .toList(),
        deviceClasses: ((json['deviceClasses'] as List?) ?? const [])
            .map((d) => d as String)
            .toList(),
      );
}

class ScreenshotPlan {
  final List<String> stores;
  final List<ShotSpec> shots;
  const ScreenshotPlan({this.stores = const [], required this.shots});

  Map<String, dynamic> toJson() => {
        'stores': stores,
        'shots': shots.map((s) => s.toJson()).toList(),
      };

  static ScreenshotPlan fromJson(Map json) => ScreenshotPlan(
        stores: ((json['stores'] as List?) ?? const [])
            .map((s) => s as String)
            .toList(),
        shots: ((json['shots'] as List?) ?? const [])
            .map((s) => ShotSpec.fromJson(s as Map))
            .toList(),
      );
}

class CaptureResult {
  final String id;
  final String file;
  final AppPlatform platform;
  final FormFactor formFactor;
  final String device;
  final int width;
  final int height;
  final CaptureProvider provider;
  final ReliabilityTier tier;
  final bool synthetic;
  final String status;
  final List<String> warnings;
  final String signature;
  final String appBuildHash;

  const CaptureResult({
    required this.id,
    required this.file,
    required this.platform,
    required this.formFactor,
    required this.device,
    required this.width,
    required this.height,
    required this.provider,
    required this.tier,
    required this.synthetic,
    required this.status,
    required this.warnings,
    required this.signature,
    required this.appBuildHash,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'file': file,
        'platform': platform.wire,
        'formFactor': formFactor.wire,
        'device': device,
        'size': [width, height],
        'format': 'png',
        'provider': provider.wire,
        'tier': tier.wire,
        'synthetic': synthetic,
        'status': status,
        'warnings': warnings,
        'signature': signature,
        'appBuildHash': appBuildHash,
      };

  static CaptureResult fromJson(Map json) {
    final size = (json['size'] as List).cast<int>();
    return CaptureResult(
      id: json['id'] as String,
      file: json['file'] as String,
      platform: AppPlatform.fromWire(json['platform'] as String),
      formFactor: FormFactor.fromWire(json['formFactor'] as String),
      device: json['device'] as String,
      width: size[0],
      height: size[1],
      provider: CaptureProvider.fromWire(json['provider'] as String),
      tier: ReliabilityTier.fromWire(json['tier'] as String),
      synthetic: json['synthetic'] as bool,
      status: json['status'] as String,
      warnings: ((json['warnings'] as List?) ?? const []).cast<String>(),
      signature: json['signature'] as String,
      appBuildHash: json['appBuildHash'] as String,
    );
  }
}
