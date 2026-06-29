import 'package:flutter_test/flutter_test.dart';
import 'package:talky_flutter/core/utils/alanya_phone_formatter.dart';

void main() {
  group('AlanyaPhoneFormatter', () {
    test('normalize strips non-digits', () {
      expect(AlanyaPhoneFormatter.normalize('12 34'), '1234');
      expect(AlanyaPhoneFormatter.normalize('00 48 29 17'), '00482917');
    });

    test('formatDisplay by tier', () {
      expect(AlanyaPhoneFormatter.formatDisplay('007'), '007');
      expect(AlanyaPhoneFormatter.formatDisplay('1234'), '12 34');
      expect(AlanyaPhoneFormatter.formatDisplay('00482917'), '00 48 29 17');
    });

    test('formatLiveInput progressive', () {
      expect(AlanyaPhoneFormatter.formatLiveInput('1'), '1');
      expect(AlanyaPhoneFormatter.formatLiveInput('123'), '123');
      expect(AlanyaPhoneFormatter.formatLiveInput('1234'), '12 34');
      expect(AlanyaPhoneFormatter.formatLiveInput('12345678'), '12 34 56 78');
    });

    test('validate lengths', () {
      expect(AlanyaPhoneFormatter.validate('123'), isNull);
      expect(AlanyaPhoneFormatter.validate('1234'), isNull);
      expect(AlanyaPhoneFormatter.validate('12345678'), isNull);
      expect(AlanyaPhoneFormatter.validate('12345'), isNotNull);
    });
  });
}
