import 'package:app_shots/src/ios_resolutions.dart';
import 'package:test/test.dart';

void main() {
  test('matches the 6.9" iPhone to 1320x2868', () {
    expect(lookupIosResolution('iPhone 16 Pro Max'), [1320, 2868]);
  });

  test('matches the 13" iPad Pro', () {
    expect(lookupIosResolution('iPad Pro 13-inch (M4)'), [2064, 2752]);
  });

  test('returns null for unknown devices', () {
    expect(lookupIosResolution('Apple Watch Ultra'), isNull);
  });

  test('prefers the longest matching model name', () {
    // "iPhone 16 Pro Max" must win over a shorter "iPhone 16" entry.
    expect(lookupIosResolution('iPhone 16 Pro Max'),
        isNot(lookupIosResolution('iPhone 16')));
  });
}
