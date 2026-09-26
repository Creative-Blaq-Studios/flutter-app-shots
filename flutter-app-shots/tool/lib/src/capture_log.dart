import 'dart:convert';
import 'models.dart';

class CaptureLog {
  final List<CaptureResult> entries;
  CaptureLog(this.entries);

  static CaptureLog empty() => CaptureLog([]);

  CaptureResult? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  void upsert(CaptureResult r) {
    final index = entries.indexWhere((e) => e.id == r.id);
    if (index >= 0) {
      entries[index] = r;
    } else {
      entries.add(r);
    }
  }

  String toJsonString() => const JsonEncoder.withIndent('  ')
      .convert({'captures': entries.map((e) => e.toJson()).toList()});

  static CaptureLog fromJsonString(String text) {
    if (text.trim().isEmpty) return CaptureLog.empty();
    final root = jsonDecode(text) as Map<String, dynamic>;
    final list = (root['captures'] as List?) ?? const [];
    return CaptureLog(
        list.map((e) => CaptureResult.fromJson(e as Map)).toList());
  }
}
