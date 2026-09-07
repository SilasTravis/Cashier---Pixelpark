import 'sale_history.dart';

/// Why an edit cannot be carried out as asked.
enum SaleEditBlocker {
  /// The receipt is not a cashier-desk cash/card one — nothing to edit here.
  notEditable,

  /// The new total is higher than what was rung up. Money cannot be added to
  /// a settled receipt: the extra has to arrive as its own operation, so the
  /// books show two payments because two payments happened.
  increaseNotSupported,

  /// The method has to move, but something has already been handed back on
  /// this receipt — refunds are recorded per method, so the columns can no
  /// longer be shifted underneath them.
  methodLockedByRefund,

  /// Reversing a top-up takes the money back off the balance, and the
  /// customer has already spent part of it.
  balanceTooLow,
}

/// What editing a receipt actually costs, derived from where it is now and
/// where the cashier says it should be.
///
/// Both halves are existing, separately audited operations: the method
/// correction moves the columns, the refund hands money back. They run in
/// that order because the server refuses to move columns underneath a refund.
/// A retry re-derives the plan from the receipt's new state, so a half-applied
/// edit converges rather than doubling up.
class SaleEditPlan {
  const SaleEditPlan({
    required this.correctionUzs,
    required this.correctionFrom,
    required this.refundUzs,
    required this.targetMethod,
    this.blocker,
  });

  /// Money to move into [targetMethod] before anything is handed back.
  final int correctionUzs;
  final SalePaymentMoveMethod? correctionFrom;

  /// Money to hand back, always out of [targetMethod] — by then the whole
  /// receipt sits there, so the customer is refunded the way they paid.
  final int refundUzs;
  final SalePaymentMoveMethod targetMethod;

  final SaleEditBlocker? blocker;

  bool get isBlocked => blocker != null;
  bool get needsCorrection => correctionUzs > 0;
  bool get needsRefund => refundUzs > 0;
  bool get isNoop => !isBlocked && !needsCorrection && !needsRefund;

  SaleRefundMethod get refundMethod =>
      targetMethod == SalePaymentMoveMethod.cash
      ? SaleRefundMethod.cash
      : SaleRefundMethod.card;
}

/// Works out how to get [sale] to [targetTotalUzs] paid entirely by
/// [targetMethod].
///
/// The receipt ends up with everything under the correct method and the
/// correct total, which is the shape of every real mis-entry at the desk:
/// the cashier typed the wrong number, picked the wrong method, or both. A
/// genuinely mixed payment that was split wrong is left to the two
/// operations on their own, where the exact split can be dialled in.
SaleEditPlan planSaleEdit({
  required SaleHistoryEntry sale,
  required int targetTotalUzs,
  required SalePaymentMoveMethod targetMethod,
}) {
  SaleEditPlan blocked(SaleEditBlocker blocker) => SaleEditPlan(
    correctionUzs: 0,
    correctionFrom: null,
    refundUzs: 0,
    targetMethod: targetMethod,
    blocker: blocker,
  );

  final physicalUzs = sale.cashUzs + sale.cardUzs;
  if (physicalUzs <= 0 || sale.balanceUzs > 0) {
    return blocked(SaleEditBlocker.notEditable);
  }
  if (targetTotalUzs > physicalUzs) {
    return blocked(SaleEditBlocker.increaseNotSupported);
  }

  final underTarget = sale.movableFor(targetMethod);
  final correctionUzs = physicalUzs - underTarget;
  final refundUzs = physicalUzs - targetTotalUzs;

  if (correctionUzs > 0 && !sale.canCorrectPayment) {
    // Only blame a refund when there actually is one. The same flag is also
    // false for money that never sat in a drawer — and for a server that does
    // not support corrections yet — where that message would be a lie.
    return blocked(
      sale.hasRefunds
          ? SaleEditBlocker.methodLockedByRefund
          : SaleEditBlocker.notEditable,
    );
  }
  if (refundUzs > 0 && !sale.canRefund) {
    return blocked(SaleEditBlocker.notEditable);
  }
  // A top-up reversal comes off the balance, so it can only give back what
  // the balance still holds — the same ceiling the refund dialog shows.
  if (refundUzs > 0 && sale.isTopup) {
    final balance = sale.customer?.balance;
    if (balance != null && refundUzs > balance) {
      return blocked(SaleEditBlocker.balanceTooLow);
    }
  }

  return SaleEditPlan(
    correctionUzs: correctionUzs,
    correctionFrom: correctionUzs > 0
        ? (targetMethod == SalePaymentMoveMethod.cash
              ? SalePaymentMoveMethod.card
              : SalePaymentMoveMethod.cash)
        : null,
    refundUzs: refundUzs,
    targetMethod: targetMethod,
  );
}
