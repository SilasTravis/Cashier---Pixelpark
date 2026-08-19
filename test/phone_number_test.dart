import 'package:cashier_app/core/utils/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats Uzbekistan phone numbers consistently', () {
    expect(formatPhoneNumber('+998939170731'), '+998 93 917 07 31');
    expect(formatPhoneNumber('998 93 917-07-31'), '+998 93 917 07 31');
    expect(formatPhoneNumber('939170731'), '+998 93 917 07 31');
  });

  test('keeps an unknown phone format readable without guessing', () {
    expect(formatPhoneNumber(' 12345 '), '12345');
  });
}
