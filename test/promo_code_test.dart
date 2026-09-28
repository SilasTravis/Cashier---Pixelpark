import 'package:cashier_app/core/utils/promo_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Luhn check digit — the same vectors as the backend', () {
    expect(luhnCheckDigit('7992739871'), 3);
    expect(luhnCheckDigit('411111111111111'), 1);
    expect(luhnCheckDigit('000000000000000'), 0);
  });

  test('accepts exactly 16 digits with a valid check digit', () {
    expect(isValidPromoCode('4111111111111111'), isTrue);
    expect(isValidPromoCode('4111111111111112'), isFalse);
    expect(isValidPromoCode('411111111111111'), isFalse);
    expect(isValidPromoCode('41111111111111111'), isFalse);
    expect(isValidPromoCode(''), isFalse);
  });

  group('normalizePromoCode', () {
    test('the partner display form and scanner suffixes', () {
      expect(normalizePromoCode('4111 1111-1111 1111\r\n'), '4111111111111111');
      expect(normalizePromoCode('\t4111111111111111\t'), '4111111111111111');
      expect(normalizePromoCode('4111.1111_1111 1111'), '4111111111111111');
      expect(normalizePromoCode('ALI.20'), 'ALI.20');
    });

    test(
      'Russian-layout Cyrillic maps to the Latin letter on the same key',
      () {
        expect(normalizePromoCode('ФДШ20'), 'ALI20');
        expect(normalizePromoCode('фдш20'), 'ALI20');
        expect(
          normalizePromoCode('ЙЦУКЕНГШЩЗФЫВАПРОЛДЯЧСМИТЬ'),
          'QWERTYUIOPASDFGHJKLZXCVBNM',
        );
        // Mixed layouts mid-word still land on the same code.
        expect(normalizePromoCode('AДi20'), 'ALI20');
      },
    );

    test('Ё is not mapped', () {
      expect(normalizePromoCode('ёALI'), 'ЁALI');
    });

    test('uppercases, strips whitespace and dashes', () {
      expect(normalizePromoCode('ali20'), 'ALI20');
      expect(normalizePromoCode('  al i-20 \n'), 'ALI20');
    });

    test('other characters are left for the classifier to refuse', () {
      expect(normalizePromoCode('ALI_20'), 'ALI_20');
      expect(normalizePromoCode('ALI.20'), 'ALI.20');
    });
  });

  group('classifyPromoCode', () {
    PromoCodeKind? classify(String raw) =>
        classifyPromoCode(normalizePromoCode(raw));

    test('16 digits with a valid Luhn digit are a partner code', () {
      expect(classify('4111 1111 1111 1111'), PromoCodeKind.partner);
    });

    test('digits-only with a bad check digit or length are invalid', () {
      expect(classify('4111111111111112'), isNull);
      expect(classify('411111111111111'), isNull);
      expect(classify('12345'), isNull);
    });

    test('letters + digits, 3–20 chars, ≥1 letter are a blogger code', () {
      expect(classify('ФДШ20'), PromoCodeKind.blogger);
      expect(classify('ali20'), PromoCodeKind.blogger);
      expect(classify('ABC'), PromoCodeKind.blogger);
      expect(classify('A1234567890123456789'), PromoCodeKind.blogger);
    });

    test('anything else is an invalid format', () {
      expect(classify(''), isNull);
      expect(classify('AB'), isNull);
      expect(classify('A12345678901234567890'), isNull);
      expect(classify('ALI_20'), isNull);
      expect(classify('ALI.20'), isNull);
      expect(classify('ЁЛКА'), isNull);
    });
  });

  test('formats in groups of four', () {
    expect(formatPromoCode('4821773019560342'), '4821 7730 1956 0342');
  });
}
