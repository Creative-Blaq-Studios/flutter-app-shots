import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'device_auditor.dart';
import 'models.dart';

ScreenshotPlan loadPlan(String yamlText) {
  final doc = loadYaml(yamlText);
  if (doc is! Map || doc['plan'] == null) {
    return const ScreenshotPlan(shots: []);
  }
  final stores = (doc['stores'] as YamlList?)
          ?.map((s) => s.toString())
          .toList() ??
      const <String>[];
  final shots = (doc['plan'] as YamlList)
      .map((s) => ShotSpec.fromJson(_deepToMap(s) as Map))
      .toList();
  return ScreenshotPlan(stores: stores, shots: shots);
}

String writeDevices(String yamlText, DeviceMap map) {
  final editor = YamlEditor(_ensureRootMap(yamlText));
  final block = <String, dynamic>{};
  for (final entry in map.selected.entries) {
    final d = entry.value;
    block[entry.key.wire] = {
      'device_id': d.id,
      'name': d.name,
      'platform': d.platform.wire,
      'native_size': [d.widthPx, d.heightPx],
      'enabled': true,
    };
  }
  editor.update(['devices'], block);
  return editor.toString();
}

String writePlan(String yamlText, ScreenshotPlan plan) {
  final editor = YamlEditor(_ensureRootMap(yamlText));
  editor.update(['stores'], plan.stores);
  editor.update(['plan'], plan.shots.map((s) => s.toJson()).toList());
  return editor.toString();
}

String _ensureRootMap(String yamlText) {
  final trimmed = yamlText.trim();
  if (trimmed.isEmpty) return '{}\n';
  final doc = loadYaml(yamlText);
  if (doc is Map) return yamlText;
  throw ArgumentError('app_shots.yaml root must be a YAML map');
}

/// Recursively converts YamlMap/YamlList into plain Map/List.
dynamic _deepToMap(dynamic node) {
  if (node is YamlMap) {
    return node.map((k, v) => MapEntry(k.toString(), _deepToMap(v)));
  }
  if (node is YamlList) {
    return node.map(_deepToMap).toList();
  }
  return node;
}
