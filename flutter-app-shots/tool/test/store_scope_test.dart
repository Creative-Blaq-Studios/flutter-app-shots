import 'package:app_shots/src/models.dart';
import 'package:app_shots/src/store_scope.dart';
import 'package:test/test.dart';

void main() {
  group('parseStores', () {
    test('returns a deduped list for valid input', () {
      expect(parseStores(['app_store', 'play_store', 'app_store']),
          ['app_store', 'play_store']);
    });

    test('throws for a non-list', () {
      expect(() => parseStores('app_store'), throwsFormatException);
    });

    test('throws for an empty list', () {
      expect(() => parseStores(<String>[]), throwsFormatException);
    });

    test('throws for an unknown store value', () {
      expect(() => parseStores(['app_store', 'amazon']), throwsFormatException);
    });
  });

  group('store mapping', () {
    test('maps form factors to their store', () {
      expect(storeForFormFactor(FormFactor.iphone), 'app_store');
      expect(storeForFormFactor(FormFactor.ipad), 'app_store');
      expect(storeForFormFactor(FormFactor.androidPhone), 'play_store');
      expect(storeForFormFactor(FormFactor.androidTablet), 'play_store');
    });

    test('maps device classes to their store', () {
      expect(storeForDeviceClass('iphone_6_9'), 'app_store');
      expect(storeForDeviceClass('android_phone'), 'play_store');
      expect(storeForDeviceClass('feature_graphic'), 'play_store');
      expect(storeForDeviceClass('not_a_device'), isNull);
    });

    test('checks form-factor membership in a store set', () {
      expect(formFactorAllowedByStores(FormFactor.ipad, {'app_store'}), isTrue);
      expect(formFactorAllowedByStores(FormFactor.androidPhone, {'app_store'}),
          isFalse);
    });
  });
}
