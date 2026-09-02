import 'package:equatable/equatable.dart';
import '../../pos_account/domain/customer.dart';

enum SaleHistoryPeriod { today, sevenDays, thirtyDays, year }

enum SaleRefundMethod { cash, card }

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
    required this.netUzs,
    required this.refundableUzs,
    required this.refundableCashUzs,
    required this.refundableCardUzs,
    required this.canRefund,
    required this.createdAt,
    required this.items,
    required this.refunds,
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
  final int netUzs;
  final int refundableUzs;
  final int refundableCashUzs;
  final int refundableCardUzs;
  final bool canRefund;
  final DateTime createdAt;
  final List<SaleHistoryItem> items;
  final List<SaleHistoryRefund> refunds;
  final Customer? customer;

  bool get hasRefunds => refundedUzs > 0;
  bool get isFullyRefunded => refundableUzs == 0 && hasRefunds;

  int refundableFor(SaleRefundMethod method) => switch (method) {
    SaleRefundMethod.cash => refundableCashUzs,
    SaleRefundMethod.card => refundableCardUzs,
  };

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
    netUzs,
    refundableUzs,
    refundableCashUzs,
    refundableCardUzs,
    canRefund,
    createdAt,
    items,
    refunds,
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
  });

  static const zero = SalesHistorySummary(
    count: 0,
    totalUzs: 0,
    cashUzs: 0,
    cardUzs: 0,
    balanceUzs: 0,
  );

  final int count;
  final int totalUzs;
  final int cashUzs;
  final int cardUzs;
  final int balanceUzs;

  @override
  List<Object?> get props => [count, totalUzs, cashUzs, cardUzs, balanceUzs];
}

class SalesHistoryPageData {
  const SalesHistoryPageData({required this.items, required this.total});
  final List<SaleHistoryEntry> items;
  final int total;
}
