import 'package:app_shots/src/capture_log.dart';
import 'package:app_shots/src/models.dart';
import 'package:test/test.dart';

CaptureResult _result(String id, {String status = 'passed'}) => CaptureResult(
      id: id, file: 'raw/$id.png', platform: AppPlatform.ios,
      formFactor: FormFactor.iphone, device: 'U1', width: 1320, height: 2868,
      provider: CaptureProvider.maestroNative, tier: ReliabilityTier.t1,
      synthetic: false, status: status, warnings: const [],
      signature: 'sig-$id', appBuildHash: 'hash1',
    );

void main() {
  test('upsert appends new ids and replaces existing ones', () {
    final log = CaptureLog.empty();
    log.upsert(_result('hero'));
    log.upsert(_result('hero', status: 'warning')); // replace
    log.upsert(_result('budget'));
    expect(log.entries, hasLength(2));
    expect(log.byId('hero')!.status, 'warning');
  });

  test('round-trips through JSON', () {
    final log = CaptureLog.empty()..upsert(_result('hero'));
    final reloaded = CaptureLog.fromJsonString(log.toJsonString());
    expect(reloaded.byId('hero')!.signature, 'sig-hero');
  });

  test('fromJsonString tolerates an empty document', () {
    expect(CaptureLog.fromJsonString('').entries, isEmpty);
  });
}
