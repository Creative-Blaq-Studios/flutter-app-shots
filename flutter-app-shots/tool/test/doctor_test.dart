import 'package:app_shots/src/doctor.dart';
import 'package:test/test.dart';

void main() {
  test(
      'doctor report is pure Dart/Flutter and contains no node compositor flags',
      () {
    final report = buildDoctorReport(
      const DoctorFacts(
        hasFlutter: true,
        toolResolved: true,
        rendererResolved: true,
        targetAppPubspec: true,
        targetAppPath: '/tmp/app',
        imageGeneration: true,
      ),
    );

    final json = report.toJson();
    expect(json.keys, isNot(contains('node')));
    expect(json.keys, isNot(contains('compositor')));
    expect(json['flutter'], true);
    expect(json['tool'], {'resolved': true});
    expect(json['renderer'], {'resolved': true});
    expect(json['targetApp'], {'path': '/tmp/app', 'pubspec': true});
    expect(json['imageGeneration'], true);
    expect(json['readyForGolden'], true);
    expect(json['notes'], isEmpty);
  });

  test('doctor report explains missing golden-mode prerequisites', () {
    final report = buildDoctorReport(
      const DoctorFacts(
        hasFlutter: false,
        toolResolved: false,
        rendererResolved: false,
        targetAppPubspec: false,
        targetAppPath: '/tmp/missing',
        imageGeneration: false,
      ),
    );

    expect(report.readyForGolden, false);
    expect(report.notes.join('\n'), contains('flutter not found'));
    expect(report.notes.join('\n'), contains('tool packages unresolved'));
    expect(report.notes.join('\n'), contains('renderer packages unresolved'));
    expect(report.notes.join('\n'), contains('target app pubspec not found'));
    expect(report.notes.join('\n'), contains('CSS backgrounds will be used'));
  });
}
