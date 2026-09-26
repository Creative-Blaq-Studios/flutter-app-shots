import 'package:app_shots/src/process_runner.dart';
import 'package:test/test.dart';

void main() {
  test('FakeProcessRunner returns the configured response', () async {
    final runner = FakeProcessRunner(responses: {
      'echo hi': ProcessResultData(exitCode: 0, stdout: 'hi\n', stderr: ''),
    });
    final result = await runner.run('echo', ['hi']);
    expect(result.exitCode, 0);
    expect(result.stdout, 'hi\n');
  });

  test('FakeProcessRunner throws on an unconfigured command', () {
    final runner = FakeProcessRunner(responses: const {});
    expect(() => runner.run('ls', ['-a']), throwsStateError);
  });
}
