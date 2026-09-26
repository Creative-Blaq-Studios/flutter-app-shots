// All functions return argv (the first element is the executable's first arg
// after `xcrun`/`adb` where relevant). Callers run them via a ProcessRunner.

List<String> iosStatusBarArgv(String udid) => [
      'simctl', 'status_bar', udid, 'override',
      '--time', '9:41',
      '--dataNetwork', 'wifi',
      '--wifiMode', 'active',
      '--wifiBars', '3',
      '--cellularMode', 'active',
      '--cellularBars', '4',
      '--batteryState', 'charged',
      '--batteryLevel', '100',
    ];

List<String> iosDisableAnimationsArgv(String udid) =>
    ['simctl', 'spawn', udid, 'defaults', 'write', 'com.apple.UIKit',
     'UIAnimationDragCoefficient', '0'];

List<List<String>> androidDemoModeArgvs() => [
      ['shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1'],
      ['shell', 'am', 'broadcast', '-a',
       'com.android.systemui.demo', '-e', 'command', 'enter'],
      ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo',
       '-e', 'command', 'clock', '-e', 'hhmm', '0941'],
      ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo',
       '-e', 'command', 'battery', '-e', 'level', '100', '-e', 'plugged', 'false'],
      ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo',
       '-e', 'command', 'network', '-e', 'wifi', 'show', '-e', 'level', '4'],
      ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo',
       '-e', 'command', 'network', '-e', 'mobile', 'show', '-e', 'level', '4',
       '-e', 'datatype', 'none'],
      ['shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo',
       '-e', 'command', 'notifications', '-e', 'visible', 'false'],
    ];

List<List<String>> androidDisableAnimationsArgvs() => [
      ['shell', 'settings', 'put', 'global', 'window_animation_scale', '0'],
      ['shell', 'settings', 'put', 'global', 'transition_animation_scale', '0'],
      ['shell', 'settings', 'put', 'global', 'animator_duration_scale', '0'],
    ];
