import 'package:cashier_app/features/pos_account/domain/free_reason.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('birthday eligibility follows the Tashkent calendar day', () {
    final birthday = DateTime.utc(2018, 8, 20);
    expect(
      isBirthdayInTashkent(birthday, now: DateTime.utc(2026, 8, 19, 20, 30)),
      isTrue,
    );
    expect(
      isBirthdayInTashkent(birthday, now: DateTime.utc(2026, 8, 18, 20, 30)),
      isFalse,
    );
  });
}
