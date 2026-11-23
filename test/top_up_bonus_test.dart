import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_app/features/pos_account/domain/top_up_bonus.dart';

void main() {
  test('matches the backend ladder', () {
    expect(topUpBonusFor(299999), 0);
    expect(topUpBonusFor(300000), 50000);
    expect(topUpBonusFor(499999), 50000);
    expect(topUpBonusFor(600000), 200000);
    expect(topUpBonusFor(1000000), 500000);
    expect(topUpBonusFor(2500000), 2000000);
  });
}
