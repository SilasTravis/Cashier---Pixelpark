import 'package:cashier_app/features/birthday_parties/presentation/model/cancel_refund_form.dart';
import 'package:flutter_test/flutter_test.dart';

String? _v({
  bool refund = true,
  int balance = 0,
  int cash = 0,
  int net = 1000000,
  int maxCash = 400000,
}) => CancelRefundForm.validate(
  netUzs: net,
  maxCashRefundUzs: maxCash,
  refund: refund,
  balanceUzs: balance,
  cashUzs: cash,
);

void main() {
  test('cash above the cash that was collected is refused', () {
    expect(_v(cash: 500000), CancelRefundForm.cashTooLarge);
  });

  test('balance + cash above the net paid is refused', () {
    expect(_v(balance: 700000, cash: 400000), CancelRefundForm.totalTooLarge);
  });

  test('a refund of nothing is refused', () {
    expect(_v(), CancelRefundForm.empty);
  });

  test('valid refunds and keeping the money pass', () {
    expect(_v(balance: 600000, cash: 400000), isNull);
    expect(_v(balance: 1000000), isNull);
    expect(_v(refund: false, balance: 9, cash: 9), isNull);
  });
}
