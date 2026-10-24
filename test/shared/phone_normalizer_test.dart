import 'package:crystal_messenger/shared/utils/phone_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalPhoneDigits', () {
    test('strips +, spaces, dashes and parens', () {
      expect(canonicalPhoneDigits('+92 324 094 1091'), '923240941091');
      expect(canonicalPhoneDigits('+1 (212) 555-1234'), '12125551234');
    });

    test('maps a leading local 0 onto the default country code', () {
      expect(canonicalPhoneDigits('03240941091'), '923240941091');
    });

    test('maps the 00 international prefix onto the default country code', () {
      expect(canonicalPhoneDigits('00923240941091'), '923240941091');
    });

    test('keeps unmatched digits as-is', () {
      expect(canonicalPhoneDigits('18005551234'), '18005551234');
    });
  });

  group('phoneMatchVariants', () {
    test('different renderings of the same number share a variant', () {
      final stored = phoneMatchVariants('+923240941091').toSet();
      final typed = phoneMatchVariants('03240941091').toSet();
      expect(stored.intersection(typed), isNotEmpty);
      expect(typed.contains('+923240941091'), isTrue);
      expect(typed.contains('923240941091'), isTrue);
    });

    test('empty input yields no variants', () {
      expect(phoneMatchVariants(''), isEmpty);
      expect(phoneMatchVariants('   '), isEmpty);
    });
  });
}
