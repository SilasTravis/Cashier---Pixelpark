import 'package:equatable/equatable.dart';
import '../../pos_account/domain/customer.dart';

enum SaleHistoryPeriod { today, sevenDays, thirtyDays, year }

/// How the money goes back. [cash] and [card] hand it over at the desk;
/// [balance] credits the customer's stored balance again, for a sale that was
/// paid from it in the first place.
enum SaleRefundMethod { cash, card, balance }

extension SaleRefundMethodApi on SaleRefundMethod {
  String get apiValue => name;
}

extension SaleHistoryPeriodApi on SaleHistoryPeriod {
  String get apiValue => switch (this) {
    SaleHistoryPeriod.today => 'today',
    SaleHistoryPeriod.sevenDays => '7d',
    SaleHistoryPeriod.thirtyDays => '30d',
    SaleHistoryPeriod.year => 'year',
  };

  String get label => switch (this) {
    SaleHistoryPeriod.today => 'Bugun',
    SaleHistoryPeriod.sevenDays => '7 kun',
    SaleHistoryPeriod.thirtyDays => '30 kun',
    SaleHistoryPeriod.year => 'Bu yil',
  };
}

/// One entrance sticker printed by a gate-pass sale, with whether it can
/// still be handed back — a pass the child already walked in on cannot.
class SaleGatePass extends Equatable {
  const SaleGatePass({
    required this.id,
    required this.childId,
    required this.code,
    required this.planLabel,
    required this.priceUzs,
    required this.refundable,
    this.enteredAt,
  });

  final String id;
  final String childId;
  final String code;
  final String planLabel;
  final int priceUzs;
  final bool refundable;
  final DateTime? enteredAt;

  @override
  List<Object?> get props => [
    id,
    childId,
    code,
    planLabel,
    priceUzs,
    refundable,
    enteredAt,
  ];
}

class SaleHistoryItem extends Equatable {
  const SaleHistoryItem({
    required this.name,
    required this.priceUzs,
    required this.qty,
    required this.totalUzs,
  });

  final String name;
  final int priceUzs;
  final int qty;
  final int totalUzs;

  @override
  List<Object?> get props => [name, priceUzs, qty, totalUzs];
}

class SaleHistoryEntry extends Equatable {
  const SaleHistoryEntry({
    required this.id,
    required this.type,
    required this.totalUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.balanceUzs,
    required this.refundedUzs,
    required this.refundedCashUzs,
    required this.refundedCardUzs,
    required this.refundedBalanceUzs,
    required this.netUzs,
    required this.refundableUzs,
    required this.refundableCashUzs,
    required this.refundableCardUzs,
    required this.refundableBalanceUzs,
    required this.canRefund,
    required this.createdAt,
    required this.items,
    required this.refunds,
    required this.passes,
    this.customer,
  });

  final String id;
  final String type;
  final int totalUzs;
  final int cashUzs;
  final int cardUzs;
  final int balanceUzs;
  final int refundedUzs;
  final int refundedCashUzs;
  final int refundedCardUzs;
  final int refundedBalanceUzs;
  final int netUzs;
  final int refundableUzs;
  final int refundableCashUzs;
  final int refundableCardUzs;
  final int refundableBalanceUzs;
  final bool canRefund;
  final DateTime createdAt;
  final List<SaleHistoryItem> items;
  final List<SaleHistoryRefund> refunds;
  final List<SaleGatePass> passes;
  final Customer? customer;

  bool get hasRefunds => refundedUzs > 0;
  bool get isFullyRefunded => refundableUzs == 0 && hasRefunds;
  bool get isTopup => type == 'ACCOUNT_TOPUP';
  bool get isGatePass => type == 'GATE_PASS';

  /// Stickers this receipt can still take back.
  List<SaleGatePass> get refundablePasses =>
      passes.where((pass) => pass.refundable).toList();

  int refundableFor(SaleRefundMethod method) => switch (method) {
    SaleRefundMethod.cash => refundableCashUzs,
    SaleRefundMethod.card => refundableCardUzs,
    SaleRefundMethod.balance => refundableBalanceUzs,
  };

  /// Reversing a top-up takes the money back off the balance, so it can never
  /// return more than the balance still holds.
  int refundCeilingFor(SaleRefundMethod method) {
    final byMethod = refundableFor(method);
    if (!isTopup) return byMethod;
    final balance = customer?.balance;
    if (balance == null) return byMethod;
    return balance < byMethod ? (balance < 0 ? 0 : balance) : byMethod;
  }

  String get typeLabel => switch (type) {
    'GOODS_CHECKOUT' => 'Mahsulot savdosi',
    'GATE_PASS' => 'Kirish chiptasi',
    'ACCOUNT_TOPUP' => 'Hisob to‘ldirish',
    _ => 'Sotuv',
  };

  @override
  List<Object?> get props => [
    id,
    type,
    totalUzs,
    cashUzs,
    cardUzs,
    balanceUzs,
    refundedUzs,
    refundedCashUzs,
    refundedCardUzs,
    refundedBalanceUzs,
    netUzs,
    refundableUzs,
    refundableCashUzs,
    refundableCardUzs,
    refundableBalanceUzs,
    canRefund,
    createdAt,
    items,
    refunds,
    passes,
    customer,
  ];
}

class SaleHistoryRefund extends Equatable {
  const SaleHistoryRefund({
    required this.id,
    required this.amountUzs,
    required this.method,
    required this.reason,
    required this.refundedByType,
    required this.refundedByName,
    required this.createdAt,
  });

  final String id;
  final int amountUzs;
  final SaleRefundMethod method;
  final String reason;
  final String refundedByType;
  final String refundedByName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    amountUzs,
    method,
    reason,
    refundedByType,
    refundedByName,
    createdAt,
  ];
}

class SalesHistorySummary extends Equatable {
  const SalesHistorySummary({
    required this.count,
    required this.totalUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.balanceUzs,
    required this.refundedUzs,
  });

  static const zero = SalesHistorySummary(
    count: 0,
    totalUzs: 0,
    cashUzs: 0,
    cardUzs: 0,
    balanceUzs: 0,
    refundedUzs: 0,
  );

  final int count;
  final int totalUzs;
  final int cashUzs;
  final int cardUzs;
  final int balanceUzs;

  /// Physical money handed back over the period. The cash and card figures
  /// above are already net of it; this is shown so the drop is explained.
  final int refundedUzs;

  @override
  List<Object?> get props => [
    count,
    totalUzs,
    cashUzs,
    cardUzs,
    balanceUzs,
    refundedUzs,
  ];
}

class SalesHistoryPageData {
  const SalesHistoryPageData({required this.items, required this.total});
  final List<SaleHistoryEntry> items;
  final int total;
}
