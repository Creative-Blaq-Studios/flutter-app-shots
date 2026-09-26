import 'capture_log.dart';
import 'models.dart';

List<String> shotsNeedingRecapture({
  required ScreenshotPlan plan,
  required CaptureLog log,
  required String appBuildHash,
  required bool Function(String path) fileExists,
}) {
  final needed = <String>[];
  for (final shot in plan.shots) {
    final prior = log.byId(shot.id);
    if (prior == null ||
        prior.appBuildHash != appBuildHash ||
        prior.signature != shot.signature() ||
        !fileExists(prior.file)) {
      needed.add(shot.id);
    }
  }
  return needed;
}
