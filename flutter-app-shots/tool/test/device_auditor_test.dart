import 'package:app_shots/src/device_auditor.dart';
import 'package:app_shots/src/models.dart';
import 'package:test/test.dart';

const _simctlJson = '''
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
      {"udid": "U1", "name": "iPhone 16 Pro Max", "state": "Shutdown", "isAvailable": true},
      {"udid": "U2", "name": "iPad Pro 13-inch (M4)", "state": "Booted", "isAvailable": true}
    ],
    "com.apple.CoreSimulator.SimRuntime.watchOS-11-0": [
      {"udid": "U3", "name": "Apple Watch Ultra 2", "state": "Shutdown", "isAvailable": true}
    ]
  }
}
''';

void main() {
  test('parseSimctl returns iPhone/iPad devices with resolution', () {
    final devices = parseSimctl(_simctlJson);
    expect(devices.length, 2); // watch entry dropped (no resolution / not iPhone/iPad)
    final phone = devices.firstWhere((d) => d.formFactor == FormFactor.iphone);
    expect(phone.id, 'U1');
    expect(phone.widthPx, 1320);
    expect(phone.heightPx, 2868);
    final pad = devices.firstWhere((d) => d.formFactor == FormFactor.ipad);
    expect(pad.isBooted, isTrue);
    expect(pad.platform, AppPlatform.ios);
  });

  test('parseAvdConfig extracts width/height/density', () {
    const ini = 'hw.lcd.width=1080\nhw.lcd.height=2400\nhw.lcd.density=420\n';
    final cfg = parseAvdConfig(ini);
    expect(cfg!.width, 1080);
    expect(cfg.height, 2400);
    expect(cfg.density, 420);
  });

  test('androidFormFactor classifies phone vs tablet by diagonal inches', () {
    // 1080x2400 @420dpi ~6.3" -> phone
    expect(androidFormFactor(1080, 2400, 420), FormFactor.androidPhone);
    // 1600x2560 @213dpi ~14" -> tablet
    expect(androidFormFactor(1600, 2560, 213), FormFactor.androidTablet);
  });

  test('parseEmulatorList returns trimmed AVD names', () {
    expect(parseEmulatorList('Pixel_7\nPixel_Tablet\n\n'),
        ['Pixel_7', 'Pixel_Tablet']);
  });

  test('parseWmSize reads physical size', () {
    expect(parseWmSize('Physical size: 1080x2400\n'), [1080, 2400]);
    expect(parseWmSize('garbage'), isNull);
  });

  test('parseSimctl tolerates malformed entries — returns only the valid one', () {
    const malformedSimctl = '''
{
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-18-0": [
      {"udid": "U1", "name": "iPhone 16 Pro Max", "state": "Shutdown", "isAvailable": true},
      {"name": "No UDID Device", "state": "Shutdown", "isAvailable": true},
      {"udid": "U3", "state": "Shutdown", "isAvailable": true},
      {"udid": "U4", "name": "iPhone SE (3rd generation)", "state": "Shutdown", "isAvailable": false}
    ]
  }
}
''';
    final devices = parseSimctl(malformedSimctl);
    expect(devices.length, 1);
    expect(devices.single.id, 'U1');
    expect(devices.single.name, 'iPhone 16 Pro Max');
  });

  test('selectBest picks highest pixel count and reports gaps', () {
    const small = Device(id: 'a', name: 'iPhone SE', platform: AppPlatform.ios,
        formFactor: FormFactor.iphone, widthPx: 750, heightPx: 1334, isBooted: false);
    const big = Device(id: 'b', name: 'iPhone 16 Pro Max', platform: AppPlatform.ios,
        formFactor: FormFactor.iphone, widthPx: 1320, heightPx: 2868, isBooted: false);
    final map = selectBest([small, big],
        [FormFactor.iphone, FormFactor.androidPhone]);
    expect(map.selected[FormFactor.iphone]!.id, 'b');
    expect(map.gaps, [FormFactor.androidPhone]);
  });
}
