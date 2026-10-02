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
    this.discountUzs = 0,
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

  /// How much was given away via POS discounts this shift — informational
  /// only. [subtotalUzs]/[cashUzs]/[cardUzs] already reflect the discounted
  /// (net) amounts, so this never needs subtracting from them again; it
  /// just explains the gap for whoever counts the drawer.
  final int discountUzs;

  /// Money physically collected by this cashier in the current shift.
  /// Account-funded sales are reported separately and never added here.
  int get grandTotalUzs => cashUzs + cardUzs;

  Map<String, dynamic> toCacheJson() => {
    'salesCount': salesCount,
    'subtotalUzs': subtotalUzs,
    'cashUzs': cashUzs,
    'cardUzs': cardUzs,
    'topupUzs': topupUzs,
    'balanceSalesUzs': balanceSalesUzs,
    'refundedUzs': refundedUzs,
    'discountUzs': discountUzs,
  };

  /// Every field defaults to 0, so an older or partial cache entry parses.
  factory ShiftTotals.fromCacheJson(Map<String, dynamic> json) {
    int read(String key) => (json[key] as num?)?.toInt() ?? 0;
    return ShiftTotals(
      salesCount: read('salesCount'),
      subtotalUzs: read('subtotalUzs'),
      cashUzs: read('cashUzs'),
      cardUzs: read('cardUzs'),
      topupUzs: read('topupUzs'),
      balanceSalesUzs: read('balanceSalesUzs'),
      refundedUzs: read('refundedUzs'),
      discountUzs: read('discountUzs'),
    );
  }

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
    discountUzs,
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

  /// Offline-mode cache of the shift, totals included (as of the last
  /// online load) so the header's takings don't drop to 0 offline.
  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'closedAt': closedAt?.toUtc().toIso8601String(),
    'status': status,
    'totals': totals.toCacheJson(),
  };

  /// Entries cached before totals were stored come back with zero totals.
  factory Shift.fromCacheJson(Map<String, dynamic> json) {
    final totals = json['totals'];
    return Shift(
      id: json['id'] as String,
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      status: json['status'] as String,
      totals: totals is Map
          ? ShiftTotals.fromCacheJson(Map<String, dynamic>.from(totals))
          : ShiftTotals.zero,
    );
  }

  Shift copyWith({ShiftTotals? totals}) => Shift(
    id: id,
    openedAt: openedAt,
    closedAt: closedAt,
    status: status,
    totals: totals ?? this.totals,
  );

  @override
  List<Object?> get props => [id, openedAt, closedAt, status, totals];
}
