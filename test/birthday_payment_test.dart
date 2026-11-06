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

  test('full payment, balance on, split cash + card', () {
    final p = BirthdayPayment.compute(
      dueUzs: 2240000,
      balanceUzs: 600000,
      deposit: false,
      depositUzs: 0,
      payFromBalance: true,
      method: PaymentMethod.split,
      cashInput: '1 000 000',
      cardInput: '640 000',
    );
    expect(p.fromBalanceUzs, 600000);
    expect(p.collectUzs, 1640000);
    expect(p.cashUzs, 1000000);
    expect(p.cardUzs, 640000);
    expect(p.isValid, isTrue);
    expect(p.money, (
      fromBalanceUzs: 600000,
      cashUzs: 1000000,
      cardUzs: 640000,
    ));
  });

  test('split that does not add up to what is collected is invalid', () {
    final p = BirthdayPayment.compute(
      dueUzs: 2240000,
      balanceUzs: 600000,
      deposit: false,
      depositUzs: 0,
      payFromBalance: true,
      method: PaymentMethod.split,
      cashInput: '1 000 000',
      cardInput: '100 000',
    );
    expect(p.collectUzs, 1640000);
    expect(p.isValid, isFalse);
  });

  test('deposit with balance: balance first, the rest in cash', () {
    final p = BirthdayPayment.compute(
      dueUzs: 2240000,
      balanceUzs: 150000,
      deposit: true,
      depositUzs: 500000,
      payFromBalance: true,
      method: PaymentMethod.cash,
    );
    expect(p.targetUzs, 500000);
    expect(p.fromBalanceUzs, 150000);
    expect(p.collectUzs, 350000);
    expect(p.cashUzs, 350000);
    expect(p.remainingAfterUzs, 1740000);
  });

  test('deposit smaller than the balance takes only the deposit from it', () {
    final p = BirthdayPayment.compute(
      dueUzs: 2240000,
      balanceUzs: 600000,
      deposit: true,
      depositUzs: 200000,
      payFromBalance: true,
      method: PaymentMethod.cash,
    );
    expect(p.fromBalanceUzs, 200000);
    expect(p.collectUzs, 0);
    expect(p.isValid, isTrue);
  });
}
