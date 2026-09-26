// Store screenshot size matrix — ported verbatim from compositor/src/storeSpecs.ts
// (verified 2026-06-23) and extended with golden-capture profiles.
// Refresh against Apple App Store Connect & Google Play specs when they change.
import 'models.dart';

/// How a store target is rendered by the golden capture harness.
class CaptureProfile {
  final double dpr;
  final double statusBarInsetPt;
  final bool isIos;
  const CaptureProfile({
    required this.dpr,
    required this.statusBarInsetPt,
    required this.isIos,
  });
}

class StoreTarget {
  final String store; // 'app_store' | 'play_store'
  final String deviceClass;
  final int width;
  final int height;
  final String orientation; // 'portrait' | 'landscape'
  final double textOverlayMaxFraction;
  final bool allowAlpha;

  /// null ⇒ composition-only target (feature_graphic): never captured.
  final CaptureProfile? capture;
  final FormFactor? formFactor;

  const StoreTarget({
    required this.store,
    required this.deviceClass,
    required this.width,
    required this.height,
    required this.orientation,
    required this.textOverlayMaxFraction,
    required this.allowAlpha,
    this.capture,
    this.formFactor,
  });

  double get logicalWidth => width / (capture?.dpr ?? 1);
  double get logicalHeight => height / (capture?.dpr ?? 1);

  /// JSON shape mirroring `TargetSpec` from storeSpecs.ts, plus the
  /// capture-profile fields (nested, optional — omitted for
  /// composition-only targets like `feature_graphic`).
  Map<String, dynamic> toJson() => {
        'store': store,
        'deviceClass': deviceClass,
        'width': width,
        'height': height,
        'orientation': orientation,
        'textOverlayMaxFraction': textOverlayMaxFraction,
        'allowAlpha': allowAlpha,
        if (capture != null)
          'capture': {
            'dpr': capture!.dpr,
            'statusBarInsetPt': capture!.statusBarInsetPt,
            'isIos': capture!.isIos,
          },
      };
}

const List<StoreTarget> storeTargets = [
  // Apple (expressive; no hard text cap). Insets: Dynamic Island 6.9" = 62pt,
  // notch 6.5" = 47pt, modern iPad = 24pt.
  StoreTarget(
    store: 'app_store',
    deviceClass: 'iphone_6_9',
    width: 1320,
    height: 2868,
    orientation: 'portrait',
    textOverlayMaxFraction: 1,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 3.0, statusBarInsetPt: 62, isIos: true),
    formFactor: FormFactor.iphone,
  ),
  StoreTarget(
    store: 'app_store',
    deviceClass: 'iphone_6_5',
    width: 1284,
    height: 2778,
    orientation: 'portrait',
    textOverlayMaxFraction: 1,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 3.0, statusBarInsetPt: 47, isIos: true),
    formFactor: FormFactor.iphone,
  ),
  StoreTarget(
    store: 'app_store',
    deviceClass: 'ipad_13',
    width: 2064,
    height: 2752,
    orientation: 'portrait',
    textOverlayMaxFraction: 1,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 2.0, statusBarInsetPt: 24, isIos: true),
    formFactor: FormFactor.ipad,
  ),
  // Google (conservative; 20% tagline cap). Android status bar = 24dp.
  StoreTarget(
    store: 'play_store',
    deviceClass: 'android_phone',
    width: 1080,
    height: 1920,
    orientation: 'portrait',
    textOverlayMaxFraction: 0.2,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 3.0, statusBarInsetPt: 24, isIos: false),
    formFactor: FormFactor.androidPhone,
  ),
  StoreTarget(
    store: 'play_store',
    deviceClass: 'android_tablet_7',
    width: 1440,
    height: 2560,
    orientation: 'portrait',
    textOverlayMaxFraction: 0.2,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 2.0, statusBarInsetPt: 24, isIos: false),
    formFactor: FormFactor.androidTablet,
  ),
  StoreTarget(
    store: 'play_store',
    deviceClass: 'android_tablet_10',
    width: 2560,
    height: 1440,
    orientation: 'landscape',
    textOverlayMaxFraction: 0.2,
    allowAlpha: true,
    capture: CaptureProfile(dpr: 2.0, statusBarInsetPt: 24, isIos: false),
    formFactor: FormFactor.androidTablet,
  ),
  // Google feature graphic — required, no alpha, composition-only.
  StoreTarget(
    store: 'play_store',
    deviceClass: 'feature_graphic',
    width: 1024,
    height: 500,
    orientation: 'landscape',
    textOverlayMaxFraction: 0.5,
    allowAlpha: false,
  ),
];

/// Capture targets for the given form factors, in table order, deduplicated.
List<StoreTarget> captureTargetsFor(Iterable<FormFactor> formFactors) {
  final wanted = formFactors.toSet();
  return storeTargets
      .where((t) => t.formFactor != null && wanted.contains(t.formFactor))
      .toList();
}

/// Resolves the exact capture matrix for one shot. Exact [deviceClasses] are
/// authoritative when provided; otherwise the legacy [formFactors] expansion
/// is used. Results follow the stable store-target table order.
List<StoreTarget> captureTargetsForSelection({
  required Iterable<FormFactor> formFactors,
  required Iterable<String> deviceClasses,
}) {
  final exact = deviceClasses.toSet();
  if (exact.isEmpty) return captureTargetsFor(formFactors);

  for (final deviceClass in exact) {
    final matches =
        storeTargets.where((target) => target.deviceClass == deviceClass);
    if (matches.isEmpty) {
      throw FormatException('Unknown capture deviceClass "$deviceClass"');
    }
    if (matches.single.capture == null) {
      throw FormatException(
          'deviceClass "$deviceClass" is composition-only, not a capture target');
    }
  }

  return storeTargets
      .where((target) =>
          target.capture != null && exact.contains(target.deviceClass))
      .toList();
}
