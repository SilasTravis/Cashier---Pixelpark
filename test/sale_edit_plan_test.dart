import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/sales_history/domain/sale_edit_plan.dart';
import 'package:cashier_app/features/sales_history/domain/sale_history.dart';
import 'package:flutter_test/flutter_test.dart';

SaleHistoryEntry sale({
  String type = 'ACCOUNT_TOPUP',
  int cash = 0,
  int card = 40000,
  int balanceUzs = 0,
  int refundedUzs = 0,
  bool canRefund = true,
  bool canCorrectPayment = true,
  int? customerBalance,
}) {
  final total = cash + card + balanceUzs;
  return SaleHistoryEntry(
    id: 'sale-1',
    type: type,
    totalUzs: total,
    cashUzs: cash,
    cardUzs: card,
    balanceUzs: balanceUzs,
    refundedUzs: refundedUzs,
    refundedCashUzs: 0,
    refundedCardUzs: refundedUzs,
    refundedBalanceUzs: 0,
    netUzs: total - refundedUzs,
    refundableUzs: total - refundedUzs,
    refundableCashUzs: cash,
    refundableCardUzs: card - refundedUzs,
    refundableBalanceUzs: balanceUzs,
    canRefund: canRefund,
    canCorrectPayment: canCorrectPayment,
    createdAt: DateTime(2026, 9, 7, 10),
    items: const [],
    refunds: const [],
    passes: const [],
    paymentCorrections: const [],
    customer: customerBalance == null
        ? null
        : Customer(
            id: 22,
            phoneNumber: '+998900000000',
            firstName: 'Ota',
            lastName: null,
            balance: customerBalance,
            children: const [],
          ),
  );
}

void main() {
  test('wrong method only: moves the columns, hands nothing back', () {
    final plan = planSaleEdit(
      sale: sale(cash: 0, card: 40000),
      targetTotalUzs: 40000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.isBlocked, isFalse);
    expect(plan.correctionUzs, 40000);
    expect(plan.correctionFrom, SalePaymentMoveMethod.card);
    expect(plan.needsRefund, isFalse);
  });

  test('wrong amount only: hands back the difference, no column move', () {
    final plan = planSaleEdit(
      sale: sale(cash: 40000, card: 0, customerBalance: 100000),
      targetTotalUzs: 25000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.needsCorrection, isFalse);
    expect(plan.cashRefundUzs, 15000);
    expect(plan.cardRefundUzs, 0);
  });

  test('both wrong: corrects first, then refunds out of the right method', () {
    // 40 000 rung up as card; the cashier actually took 30 000 in cash.
    final plan = planSaleEdit(
      sale: sale(cash: 0, card: 40000, customerBalance: 100000),
      targetTotalUzs: 30000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.correctionUzs, 40000);
    expect(plan.correctionFrom, SalePaymentMoveMethod.card);
    expect(plan.cashRefundUzs, 10000);
    expect(plan.cardRefundUzs, 0);
  });

  test('a mixed receipt is pulled onto one method before the refund', () {
    final plan = planSaleEdit(
      sale: sale(cash: 10000, card: 30000, customerBalance: 100000),
      targetTotalUzs: 25000,
      targetMethod: SalePaymentMoveMethod.card,
    );

    expect(plan.correctionUzs, 10000);
    expect(plan.correctionFrom, SalePaymentMoveMethod.cash);
    expect(plan.refundUzs, 15000);
  });

  test('nothing to do when the receipt already matches', () {
    final plan = planSaleEdit(
      sale: sale(cash: 40000, card: 0),
      targetTotalUzs: 40000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.isNoop, isTrue);
  });

  test('a higher total is refused — that is a new payment, not an edit', () {
    final plan = planSaleEdit(
      sale: sale(cash: 0, card: 40000),
      targetTotalUzs: 50000,
      targetMethod: SalePaymentMoveMethod.card,
    );

    expect(plan.blocker, SaleEditBlocker.increaseNotSupported);
  });

  test('the method is locked once money has been handed back', () {
    final plan = planSaleEdit(
      sale: sale(card: 40000, refundedUzs: 5000, canCorrectPayment: false),
      targetTotalUzs: 35000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.blocker, SaleEditBlocker.methodLockedByRefund);
  });

  test('a spent top-up cannot be reduced below what the balance holds', () {
    final plan = planSaleEdit(
      sale: sale(cash: 40000, card: 0, customerBalance: 5000),
      targetTotalUzs: 10000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.blocker, SaleEditBlocker.balanceTooLow);
  });

  test('a method change is not blamed on a refund that does not exist', () {
    // The flag is also false for a receipt that never sat in a drawer, and for
    // a server that has not shipped corrections yet.
    final plan = planSaleEdit(
      sale: sale(card: 40000, canCorrectPayment: false),
      targetTotalUzs: 40000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.blocker, SaleEditBlocker.notEditable);
  });

  test('a balance-paid receipt is not editable here', () {
    final plan = planSaleEdit(
      sale: sale(cash: 0, card: 0, balanceUzs: 60000),
      targetTotalUzs: 40000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    expect(plan.blocker, SaleEditBlocker.notEditable);
  });

  test('the two steps always land on the asked-for split', () {
    final input = sale(cash: 10000, card: 30000, customerBalance: 100000);
    final plan = planSaleEdit(
      sale: input,
      targetTotalUzs: 25000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    // Apply the plan by hand: move onto cash, then refund out of cash.
    var cash = input.cashUzs;
    var card = input.cardUzs;
    if (plan.correctionFrom == SalePaymentMoveMethod.card) {
      card -= plan.correctionUzs;
      cash += plan.correctionUzs;
    }
    cash -= plan.cashRefundUzs;
    card -= plan.cardRefundUzs;

    expect(cash, 25000);
    expect(card, 0);
  });

  group('mixed target', () {
    (int, int) apply(SaleHistoryEntry input, SaleEditPlan plan) {
      var cash = input.netCashUzs;
      var card = input.netCardUzs;
      if (plan.correctionFrom == SalePaymentMoveMethod.card) {
        card -= plan.correctionUzs;
        cash += plan.correctionUzs;
      } else if (plan.correctionFrom == SalePaymentMoveMethod.cash) {
        cash -= plan.correctionUzs;
        card += plan.correctionUzs;
      }
      return (cash - plan.cashRefundUzs, card - plan.cardRefundUzs);
    }

    test('a single-method receipt is split: only the difference moves', () {
      final input = sale(cash: 0, card: 40000);
      final plan = planSaleEditSplit(
        sale: input,
        targetCashUzs: 15000,
        targetCardUzs: 25000,
      );

      expect(plan.correctionUzs, 15000);
      expect(plan.correctionFrom, SalePaymentMoveMethod.card);
      expect(plan.correctionTo, SalePaymentMoveMethod.cash);
      expect(plan.needsRefund, isFalse);
      expect(apply(input, plan), (15000, 25000));
    });

    test('a wrong split with a lower total refunds out of each column', () {
      final input = sale(cash: 20000, card: 30000, customerBalance: 100000);
      final plan = planSaleEditSplit(
        sale: input,
        targetCashUzs: 15000,
        targetCardUzs: 25000,
      );

      expect(plan.needsCorrection, isFalse);
      expect(plan.cashRefundUzs, 5000);
      expect(plan.cardRefundUzs, 5000);
      expect(apply(input, plan), (15000, 25000));
    });

    test('move and refund together still land on the split', () {
      final input = sale(cash: 40000, card: 0, customerBalance: 100000);
      final plan = planSaleEditSplit(
        sale: input,
        targetCashUzs: 10000,
        targetCardUzs: 20000,
      );

      expect(plan.correctionFrom, SalePaymentMoveMethod.cash);
      expect(plan.correctionUzs, 20000);
      expect(plan.cashRefundUzs, 10000);
      expect(plan.cardRefundUzs, 0);
      expect(apply(input, plan), (10000, 20000));
    });

    test('a split above what was taken is refused', () {
      final plan = planSaleEditSplit(
        sale: sale(cash: 20000, card: 20000),
        targetCashUzs: 30000,
        targetCardUzs: 20000,
      );

      expect(plan.blocker, SaleEditBlocker.increaseNotSupported);
    });

    test('the split already on the receipt is a no-op', () {
      final plan = planSaleEditSplit(
        sale: sale(cash: 10000, card: 30000),
        targetCashUzs: 10000,
        targetCardUzs: 30000,
      );

      expect(plan.isNoop, isTrue);
    });

    test('a retry after one refund landed only does what is left', () {
      // 20k cash + 30k card → 15k + 25k; the cash refund already went through.
      final input = SaleHistoryEntry(
        id: 'sale-1',
        type: 'GOODS_CHECKOUT',
        totalUzs: 50000,
        cashUzs: 20000,
        cardUzs: 30000,
        balanceUzs: 0,
        refundedUzs: 5000,
        refundedCashUzs: 5000,
        refundedCardUzs: 0,
        refundedBalanceUzs: 0,
        netUzs: 45000,
        refundableUzs: 45000,
        refundableCashUzs: 15000,
        refundableCardUzs: 30000,
        refundableBalanceUzs: 0,
        canRefund: true,
        canCorrectPayment: false,
        createdAt: DateTime(2026, 9, 7, 10),
        items: const [],
        refunds: const [],
        passes: const [],
        paymentCorrections: const [],
        customer: null,
      );
      final plan = planSaleEditSplit(
        sale: input,
        targetCashUzs: 15000,
        targetCardUzs: 25000,
      );

      expect(plan.isBlocked, isFalse);
      expect(plan.needsCorrection, isFalse);
      expect(plan.cashRefundUzs, 0);
      expect(plan.cardRefundUzs, 5000);
    });
  });
}
