// Store scope helpers: validation of user-selected stores and the derivation
// of store membership from the hardcoded store matrix in store_specs.dart.
import 'models.dart';
import 'store_specs.dart';

const List<String> validStores = ['app_store', 'play_store'];

/// Validates a raw `stores` value (from a plan or compose-spec). Returns the
/// deduped list preserving first-seen order. Throws [FormatException] with an
/// actionable message on any invalid input.
List<String> parseStores(Object? raw) {
  if (raw is! List || raw.isEmpty) {
    throw const FormatException(
        'stores must be a non-empty list (choices: app_store, play_store)');
  }
  final result = <String>[];
  for (final s in raw) {
    if (s is! String || !validStores.contains(s)) {
      throw FormatException(
          'invalid store "$s" (choices: app_store, play_store)');
    }
    if (!result.contains(s)) result.add(s);
  }
  return result;
}

/// The store a [ff] belongs to, per the store matrix. Every [FormFactor] has
/// exactly one store target.
String storeForFormFactor(FormFactor ff) =>
    storeTargets.firstWhere((t) => t.formFactor == ff).store;

/// The store a [deviceClass] belongs to, or null if it is unknown.
String? storeForDeviceClass(String deviceClass) {
  for (final t in storeTargets) {
    if (t.deviceClass == deviceClass) return t.store;
  }
  return null;
}

/// Whether [ff] is captured for at least one of [stores].
bool formFactorAllowedByStores(FormFactor ff, Set<String> stores) =>
    stores.contains(storeForFormFactor(ff));
