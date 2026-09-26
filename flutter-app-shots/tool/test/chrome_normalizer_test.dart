import 'package:app_shots/src/chrome_normalizer.dart';
import 'package:test/test.dart';

void main() {
  test('iosStatusBarArgv sets 9:41, full battery and signal', () {
    final argv = iosStatusBarArgv('U1');
    expect(argv.first, 'simctl');
    expect(argv, containsAllInOrder(['status_bar', 'U1', 'override']));
    expect(argv, containsAllInOrder(['--time', '9:41']));
    expect(argv, containsAllInOrder(['--batteryLevel', '100']));
    expect(argv, containsAllInOrder(['--cellularBars', '4']));
    expect(argv, containsAllInOrder(['--wifiBars', '3']));
  });

  test('androidDemoModeArgvs enables demo mode then sets clock/battery', () {
    final cmds = androidDemoModeArgvs();
    final joined = cmds.map((c) => c.join(' ')).toList();
    expect(joined.any((c) => c.contains('sysui_demo_allowed 1')), isTrue);
    expect(joined.any((c) => c.contains('command enter')), isTrue);
    expect(joined.any((c) => c.contains('hhmm 0941')), isTrue);
    expect(joined.any((c) => c.contains('level 100')), isTrue);
  });

  test('androidDisableAnimationsArgvs zeroes all three scales', () {
    final cmds = androidDisableAnimationsArgvs();
    final joined = cmds.map((c) => c.join(' ')).toList();
    expect(joined.any((c) => c.contains('window_animation_scale 0')), isTrue);
    expect(joined.any((c) => c.contains('transition_animation_scale 0')), isTrue);
    expect(joined.any((c) => c.contains('animator_duration_scale 0')), isTrue);
  });
}
