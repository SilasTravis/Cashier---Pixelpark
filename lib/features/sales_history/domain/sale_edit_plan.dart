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
/// correction moves the columns, the refunds hand money back. They run in
/// that order because the server refuses to move columns underneath a refund.
/// A retry re-derives the plan from the receipt's new state (net of what was
/// already handed back), so a half-applied edit converges rather than
/// doubling up.
class SaleEditPlan {
  const SaleEditPlan({
    required this.targetCashUzs,
    required this.targetCardUzs,
    required this.correctionUzs,
    required this.correctionFrom,
    required this.cashRefundUzs,
    required this.cardRefundUzs,
    this.blocker,
  });

  /// The split the receipt should end up with.
  final int targetCashUzs;
  final int targetCardUzs;

  /// Money to move out of [correctionFrom] into the other column before
  /// anything is handed back.
  final int correctionUzs;
  final SalePaymentMoveMethod? correctionFrom;

  /// Money to hand back out of each column, after the move.
  final int cashRefundUzs;
  final int cardRefundUzs;

  final SaleEditBlocker? blocker;

  SalePaymentMoveMethod? get correctionTo => switch (correctionFrom) {
    SalePaymentMoveMethod.cash => SalePaymentMoveMethod.card,
    SalePaymentMoveMethod.card => SalePaymentMoveMethod.cash,
    null => null,
  };

  int get refundUzs => cashRefundUzs + cardRefundUzs;

  bool get isBlocked => blocker != null;
  bool get needsCorrection => correctionUzs > 0;
  bool get needsRefund => refundUzs > 0;
  bool get isNoop => !isBlocked && !needsCorrection && !needsRefund;
}

/// Works out how to get [sale] to [targetTotalUzs] paid entirely by
/// [targetMethod] — the shape of most mis-entries at the desk: the cashier
/// typed the wrong number, picked the wrong method, or both.
SaleEditPlan planSaleEdit({
  required SaleHistoryEntry sale,
  required int targetTotalUzs,
  required SalePaymentMoveMethod targetMethod,
}) => planSaleEditSplit(
  sale: sale,
  targetCashUzs: targetMethod == SalePaymentMoveMethod.cash
      ? targetTotalUzs
      : 0,
  targetCardUzs: targetMethod == SalePaymentMoveMethod.card
      ? targetTotalUzs
      : 0,
);

/// Works out how to get [sale] to exactly [targetCashUzs] cash plus
/// [targetCardUzs] card — a mixed payment rung up with the wrong split.
///
/// A single-method target pulls the whole receipt onto that method and
/// refunds out of it, so the customer is refunded the way they paid. A mixed
/// target moves only as much as the split needs, then hands back whatever
/// each column still holds above its target.
SaleEditPlan planSaleEditSplit({
  required SaleHistoryEntry sale,
  required int targetCashUzs,
  required int targetCardUzs,
}) {
  SaleEditPlan blocked(SaleEditBlocker blocker) => SaleEditPlan(
    targetCashUzs: targetCashUzs,
    targetCardUzs: targetCardUzs,
    correctionUzs: 0,
    correctionFrom: null,
    cashRefundUzs: 0,
    cardRefundUzs: 0,
    blocker: blocker,
  );

  final cashUzs = sale.netCashUzs;
  final cardUzs = sale.netCardUzs;
  final physicalUzs = cashUzs + cardUzs;
  if (physicalUzs <= 0 || sale.balanceUzs > 0) {
    return blocked(SaleEditBlocker.notEditable);
  }
  if (targetCashUzs < 0 ||
      targetCardUzs < 0 ||
      targetCashUzs + targetCardUzs > physicalUzs) {
    return blocked(SaleEditBlocker.increaseNotSupported);
  }

  // Where the cash column must sit after the move: at least the target, and
  // low enough to leave the card target covered.
  final cashAfterMove = targetCardUzs == 0
      ? physicalUzs
      : targetCashUzs == 0
      ? 0
      : cashUzs.clamp(targetCashUzs, physicalUzs - targetCardUzs);
  final correctionUzs = (cashAfterMove - cashUzs).abs();
  final cashRefundUzs = cashAfterMove - targetCashUzs;
  final cardRefundUzs = physicalUzs - cashAfterMove - targetCardUzs;
  final refundUzs = cashRefundUzs + cardRefundUzs;

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
    targetCashUzs: targetCashUzs,
    targetCardUzs: targetCardUzs,
    correctionUzs: correctionUzs,
    correctionFrom: correctionUzs == 0
        ? null
        : (cashAfterMove > cashUzs
              ? SalePaymentMoveMethod.card
              : SalePaymentMoveMethod.cash),
    cashRefundUzs: cashRefundUzs,
    cardRefundUzs: cardRefundUzs,
  );
}
