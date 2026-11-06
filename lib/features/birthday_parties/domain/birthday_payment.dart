import 'dart:math' as math;

import '../../../core/widgets/payment_method_selector.dart';
import 'birthday_party.dart';

/// Quick deposit amounts (so'm) offered in the birthday sale sheet.
const birthdayDepositChips = <int>[100000, 200000, 300000, 500000];

/// How a birthday payment (full or deposit) is funded: balance first, the rest
/// in cash / card. A deposit larger than what is due is capped to the due.
class BirthdayPayment {
  const BirthdayPayment._({
    required this.targetUzs,
    required this.fromBalanceUzs,
    required this.collectUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.remainingAfterUzs,
    required this.isValid,
  });

  final int targetUzs;
  final int fromBalanceUzs;
  final int collectUzs;
  final int cashUzs;
  final int cardUzs;
  final int remainingAfterUzs;
  final bool isValid;

  BirthdayMoney get money =>
      (fromBalanceUzs: fromBalanceUzs, cashUzs: cashUzs, cardUzs: cardUzs);

  factory BirthdayPayment.compute({
    required int dueUzs,
    required int balanceUzs,
    required bool deposit,
    required int depositUzs,
    required bool payFromBalance,
    required PaymentMethod method,
    String cashInput = '',
    String cardInput = '',
  }) {
    final target = deposit ? math.min(depositUzs, dueUzs) : dueUzs;
    final fromBalance = payFromBalance ? math.min(balanceUzs, target) : 0;
    final collect = target - fromBalance;
    final split = PaymentSplit.compute(
      method: method,
      totalUzs: collect,
      cashInput: cashInput,
      cardInput: cardInput,
      allowZeroTotal: true,
    );
    return BirthdayPayment._(
      targetUzs: target,
      fromBalanceUzs: fromBalance,
      collectUzs: collect,
      cashUzs: split.cashUzs,
      cardUzs: split.cardUzs,
      remainingAfterUzs: dueUzs - target,
      isValid: split.isValid,
    );
  }
}
