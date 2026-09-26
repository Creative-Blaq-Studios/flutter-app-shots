import 'dart:convert';
import 'dart:math' as math;

import 'ios_resolutions.dart';
import 'models.dart';

class DeviceMap {
  final Map<FormFactor, Device> selected;
  final List<FormFactor> gaps;
  const DeviceMap({required this.selected, required this.gaps});
}

List<Device> parseSimctl(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  final devicesByRuntime = (root['devices'] as Map).cast<String, dynamic>();
  final out = <Device>[];
  for (final entry in devicesByRuntime.entries) {
    if (!entry.key.contains('iOS')) continue;
    for (final raw in (entry.value as List).cast<Map>()) {
      try {
        if (raw['isAvailable'] != true) continue;
        final udid = raw['udid'] as String?;
        final name = raw['name'] as String?;
        if (udid == null || name == null) continue;
        final res = lookupIosResolution(name);
        if (res == null) continue; // unknown / unsupported form-factor
        final isPad = name.contains('iPad');
        out.add(Device(
          id: udid,
          name: name,
          platform: AppPlatform.ios,
          formFactor: isPad ? FormFactor.ipad : FormFactor.iphone,
          widthPx: res[0],
          heightPx: res[1],
          isBooted: raw['state'] == 'Booted',
        ));
      } catch (_) {
        continue; // skip bad entry, don't abort the whole parse
      }
    }
  }
  return out;
}

({int width, int height, int density})? parseAvdConfig(String iniText) {
  int? read(String key) {
    for (final line in iniText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('$key=')) {
        return int.tryParse(trimmed.substring(key.length + 1).trim());
      }
    }
    return null;
  }

  final w = read('hw.lcd.width');
  final h = read('hw.lcd.height');
  final d = read('hw.lcd.density');
  if (w == null || h == null || d == null) return null;
  return (width: w, height: h, density: d);
}

FormFactor androidFormFactor(int width, int height, int density) {
  final diagonalPx = math.sqrt(width * width + height * height);
  final diagonalInches = diagonalPx / density;
  return diagonalInches >= 7.0
      ? FormFactor.androidTablet
      : FormFactor.androidPhone;
}

List<String> parseEmulatorList(String stdout) => stdout
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();

List<int>? parseWmSize(String stdout) {
  final match = RegExp(r'Physical size:\s*(\d+)x(\d+)').firstMatch(stdout);
  if (match == null) return null;
  return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
}

DeviceMap selectBest(List<Device> devices, List<FormFactor> requested) {
  final selected = <FormFactor, Device>{};
  for (final ff in requested) {
    final candidates = devices.where((d) => d.formFactor == ff).toList();
    if (candidates.isEmpty) continue;
    candidates.sort((a, b) => b.pixelCount.compareTo(a.pixelCount));
    selected[ff] = candidates.first;
  }
  final gaps = requested.where((ff) => !selected.containsKey(ff)).toList();
  return DeviceMap(selected: selected, gaps: gaps);
}
