import 'package:app_shots/src/flow_template.dart';
import 'package:test/test.dart';

void main() {
  test('substitutes all tokens', () {
    final out = renderFlow(
      'appId: {{appId}}\n---\n- tapOn: "{{label}}"\n',
      {'appId': 'com.example.app', 'label': 'Log in'},
    );
    expect(out, contains('appId: com.example.app'));
    expect(out, contains('tapOn: "Log in"'));
  });

  test('throws when a token is left unsubstituted', () {
    expect(
      () => renderFlow('appId: {{appId}}\n', {'wrong': 'x'}),
      throwsA(isA<FormatException>()),
    );
  });
}
