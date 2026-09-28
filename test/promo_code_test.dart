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

  test('normalises the display form and scanner suffixes', () {
    expect(normalizePromoCode('4111 1111-1111 1111\r\n'), '4111111111111111');
    expect(normalizePromoCode('\t4111111111111111\t'), '4111111111111111');
  });

  test('a gate-pass sticker scanned into the field is not a promo code', () {
    expect(isValidPromoCode(normalizePromoCode('AB2CD3EF4GH5')), isFalse);
  });

  test('formats in groups of four', () {
    expect(formatPromoCode('4821773019560342'), '4821 7730 1956 0342');
  });
}
