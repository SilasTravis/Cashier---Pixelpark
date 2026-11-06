import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_app/core/widgets/payment_method_selector.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_payment.dart';

void main() {
  test('full payment, balance on', () {
    final p = BirthdayPayment.compute(
      dueUzs: 1000000,
      balanceUzs: 600000,
      deposit: false,
      depositUzs: 0,
      payFromBalance: true,
      method: PaymentMethod.cash,
    );
    expect(p.fromBalanceUzs, 600000);
    expect(p.collectUzs, 400000);
    expect(p.cashUzs, 400000);
    expect(p.remainingAfterUzs, 0);
    expect(p.isValid, isTrue);
  });

  test('deposit, balance off', () {
    final p = BirthdayPayment.compute(
      dueUzs: 2200000,
      balanceUzs: 600000,
      deposit: true,
      depositUzs: 200000,
      payFromBalance: false,
      method: PaymentMethod.card,
    );
    expect(p.fromBalanceUzs, 0);
    expect(p.collectUzs, 200000);
    expect(p.cardUzs, 200000);
    expect(p.remainingAfterUzs, 2000000);
  });

  test('deposit larger than due is capped to due', () {
    final p = BirthdayPayment.compute(
      dueUzs: 250000,
      balanceUzs: 0,
      deposit: true,
      depositUzs: 300000,
      payFromBalance: false,
      method: PaymentMethod.cash,
    );
    expect(p.targetUzs, 250000);
    expect(p.remainingAfterUzs, 0);
  });

  test('zero deposit is a valid booking with no money now', () {
    final p = BirthdayPayment.compute(
      dueUzs: 1000000,
      balanceUzs: 0,
      deposit: true,
      depositUzs: 0,
      payFromBalance: false,
      method: PaymentMethod.cash,
    );
    expect(p.isValid, isTrue);
    expect(p.targetUzs, 0);
    expect(p.collectUzs, 0);
    expect(p.remainingAfterUzs, 1000000);
  });

  test('split cash + card', () {
    final p = BirthdayPayment.compute(
      dueUzs: 200000,
      balanceUzs: 0,
      deposit: false,
      depositUzs: 0,
      payFromBalance: false,
      method: PaymentMethod.split,
      cashInput: '150 000',
      cardInput: '50 000',
    );
    expect(p.isValid, isTrue);
    expect(p.cashUzs, 150000);
    expect(p.cardUzs, 50000);
    expect(p.money, (fromBalanceUzs: 0, cashUzs: 150000, cardUzs: 50000));
  });
}
