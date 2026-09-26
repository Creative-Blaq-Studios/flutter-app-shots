// flutter-app-shots/tool/test/store_specs_test.dart
import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/store_specs.dart';
import 'package:test/test.dart';

void main() {
  test('storeTargets carries the verbatim store dimensions', () {
    StoreTarget byClass(String c) =>
        storeTargets.firstWhere((t) => t.deviceClass == c);
    expect(byClass('iphone_6_9').width, 1320);
    expect(byClass('iphone_6_9').height, 2868);
    expect(byClass('iphone_6_5').width, 1284);
    expect(byClass('iphone_6_5').height, 2778);
    expect(byClass('ipad_13').width, 2064);
    expect(byClass('ipad_13').height, 2752);
    expect(byClass('android_phone').width, 1080);
    expect(byClass('android_phone').height, 1920);
    expect(byClass('android_tablet_7').width, 1440);
    expect(byClass('android_tablet_10').width, 2560);
    expect(byClass('android_tablet_10').height, 1440);
    expect(byClass('feature_graphic').width, 1024);
    expect(byClass('feature_graphic').height, 500);
  });

  test('capture profiles give whole logical sizes and sane insets', () {
    for (final t in storeTargets.where((t) => t.capture != null)) {
      final c = t.capture!;
      expect(t.width / c.dpr, equals((t.width / c.dpr).roundToDouble()),
          reason: '${t.deviceClass} logical width must be whole');
      expect(t.height / c.dpr, equals((t.height / c.dpr).roundToDouble()),
          reason: '${t.deviceClass} logical height must be whole');
      expect(c.statusBarInsetPt, greaterThan(0));
    }
    final iphone69 =
        storeTargets.firstWhere((t) => t.deviceClass == 'iphone_6_9');
    expect(iphone69.capture!.dpr, 3.0);
    expect(iphone69.capture!.isIos, isTrue);
    expect(iphone69.capture!.statusBarInsetPt, 62);
  });

  test('feature_graphic is composition-only (no capture profile)', () {
    final fg =
        storeTargets.firstWhere((t) => t.deviceClass == 'feature_graphic');
    expect(fg.capture, isNull);
    expect(fg.formFactor, isNull);
    expect(fg.allowAlpha, isFalse);
  });

  test('captureTargetsFor maps form factors to device classes in order', () {
    expect(
      captureTargetsFor([FormFactor.iphone, FormFactor.ipad])
          .map((t) => t.deviceClass),
      ['iphone_6_9', 'iphone_6_5', 'ipad_13'],
    );
    expect(
      captureTargetsFor([FormFactor.androidPhone, FormFactor.androidTablet])
          .map((t) => t.deviceClass),
      ['android_phone', 'android_tablet_7', 'android_tablet_10'],
    );
    expect(captureTargetsFor([]), isEmpty);
  });

  test('captureTargetsFor deduplicates repeated form factors', () {
    expect(captureTargetsFor([FormFactor.iphone, FormFactor.iphone]).length, 2);
  });

  test('captureTargetsForSelection honors an exact device-class subset', () {
    expect(
      captureTargetsForSelection(
        formFactors: [FormFactor.iphone, FormFactor.androidTablet],
        deviceClasses: ['iphone_6_9', 'android_tablet_10'],
      ).map((t) => t.deviceClass),
      ['iphone_6_9', 'android_tablet_10'],
    );
  });

  test('captureTargetsForSelection falls back to form-factor expansion', () {
    expect(
      captureTargetsForSelection(
        formFactors: [FormFactor.iphone],
        deviceClasses: const [],
      ).map((t) => t.deviceClass),
      ['iphone_6_9', 'iphone_6_5'],
    );
  });
}
