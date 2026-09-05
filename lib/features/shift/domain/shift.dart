import 'package:equatable/equatable.dart';

class ShiftTotals extends Equatable {
  const ShiftTotals({
    required this.salesCount,
    required this.subtotalUzs,
    required this.cashUzs,
    required this.cardUzs,
    required this.topupUzs,
    required this.balanceSalesUzs,
    this.refundedUzs = 0,
  });

  final int salesCount;

  /// Gross takings before refunds. [cashUzs] and [cardUzs] are already net of
  /// [refundedUzs]; keeping the gross lets the cash-up screen show the drop.
  final int subtotalUzs;
  final int cashUzs;
  final int cardUzs;
  final int topupUzs;
  final int balanceSalesUzs;

  /// Physical money handed back during the shift. Money credited to a stored
  /// balance is not counted — it never left the drawer.
  final int refundedUzs;

  /// Money physically collected by this cashier in the current shift.
  /// Account-funded sales are reported separately and never added here.
  int get grandTotalUzs => cashUzs + cardUzs;

  static const zero = ShiftTotals(
    salesCount: 0,
    subtotalUzs: 0,
    cashUzs: 0,
    cardUzs: 0,
    topupUzs: 0,
    balanceSalesUzs: 0,
  );

  @override
  List<Object?> get props => [
    salesCount,
    subtotalUzs,
    cashUzs,
    cardUzs,
    topupUzs,
    balanceSalesUzs,
    refundedUzs,
  ];
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
