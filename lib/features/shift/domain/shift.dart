import 'package:equatable/equatable.dart';

class ShiftTotals extends Equatable {
  const ShiftTotals({
    required this.salesCount,
    required this.subtotalUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.topupUzs,
  });

  final int salesCount;
  final int subtotalUzs;
  final int cashUzs;
  final int cardUzs;
  final int topupUzs;

  /// "Smena tushumi" — product/pass sales plus balance top-ups rung up
  /// during the shift.
  int get grandTotalUzs => subtotalUzs + topupUzs;

  static const zero = ShiftTotals(
    salesCount: 0,
    subtotalUzs: 0,
    cashUzs: 0,
    cardUzs: 0,
    topupUzs: 0,
  );

  @override
  List<Object?> get props => [salesCount, subtotalUzs, cashUzs, cardUzs, topupUzs];
}

class Shift extends Equatable {
  const Shift({
    required this.id,
    required this.openedAt,
    required this.closedAt,
    required this.status,
    required this.totals,
  });

  final String id;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String status;
  final ShiftTotals totals;

  bool get isOpen => status == 'open';

  @override
  List<Object?> get props => [id, openedAt, closedAt, status, totals];
}
