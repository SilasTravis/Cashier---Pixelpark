import 'package:equatable/equatable.dart';

import 'discount.dart';

class SaleReceiptItem extends Equatable {
  const SaleReceiptItem({
    required this.productId,
    required this.nameSnapshot,
    required this.priceSnapshotUzs,
    required this.qty,
    required this.lineTotalUzs,
  });

  final String productId;
  final String nameSnapshot;
  final int priceSnapshotUzs;
  final int qty;
  final int lineTotalUzs;

  factory SaleReceiptItem.fromJson(Map<String, dynamic> json) =>
      SaleReceiptItem(
        productId: json['productId'] as String,
        nameSnapshot: json['nameSnapshot'] as String,
        priceSnapshotUzs: json['priceSnapshotUzs'] as int,
        qty: json['qty'] as int,
        lineTotalUzs: json['lineTotalUzs'] as int,
      );

  @override
  List<Object?> get props => [
    productId,
    nameSnapshot,
    priceSnapshotUzs,
    qty,
    lineTotalUzs,
  ];
}

/// The cashback QR the server minted for an online goods sale — printed on
/// the receipt for the parent to scan in the Pixel Park app. Only the
/// checkout response carries it (the plaintext [code] is never returned
/// again), so a reprint from history has none.
class SaleCashback extends Equatable {
  const SaleCashback({
    required this.code,
    required this.qrPayload,
    required this.amountUzs,
    required this.percent,
    required this.expiresAt,
  });

  final String code;

  /// Exactly what goes into the QR, e.g. `PXCB:ABCD2345EFGH`.
  final String qrPayload;
  final int amountUzs;

  /// Snapshotted at sale time, e.g. `3` or `1.5`.
  final double percent;
  final DateTime expiresAt;

  /// Null for an absent/null field, and also for a malformed one: the sale
  /// itself already succeeded server-side, so a bad cashback block must
  /// never turn the checkout into a parse error — it just prints no QR.
  static SaleCashback? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final expiresAt = json['expiresAt'] is String
        ? DateTime.tryParse(json['expiresAt'] as String)
        : null;
    final amountUzs = _wholeUzs(json['amountUzs']);
    if (code is! String || code.isEmpty || expiresAt == null) return null;
    if (amountUzs == null || amountUzs < 1) return null;
    final payload = json['qrPayload'];
    return SaleCashback(
      code: code,
      qrPayload: payload is String && payload.isNotEmpty
          ? payload
          : 'PXCB:$code',
      amountUzs: amountUzs,
      percent: _number(json['percent']) ?? 0,
      expiresAt: expiresAt,
    );
  }

  static int? _wholeUzs(Object? value) => switch (value) {
    int number => number,
    num number => number.toInt(),
    String text => int.tryParse(text.trim()),
    _ => null,
  };

  static double? _number(Object? value) => switch (value) {
    num number => number.toDouble(),
    String text => double.tryParse(text.trim()),
    _ => null,
  };

  @override
  List<Object?> get props => [code, qrPayload, amountUzs, percent, expiresAt];
}

class SaleReceipt extends Equatable {
  const SaleReceipt({
    required this.id,
    required this.subtotalUzs,
    int? grossUzs,
    this.discountUzs = 0,
    this.discount,
    required this.cashUzs,
    required this.cardUzs,
    this.balanceUzs = 0,
    required this.createdAt,
    this.isOffline = false,
    required this.items,
    this.cashback,
  }) : grossUzs = grossUzs ?? subtotalUzs;

  final String id;

  /// NET of [discountUzs] — "what the receipt totalled / what must be paid".
  /// Unchanged meaning from before this feature existed.
  final int subtotalUzs;

  /// Undiscounted sum of line totals. Defaults to [subtotalUzs] when the
  /// server response (or a hand-built receipt, e.g. the plan-entry
  /// legacy-backend fallback) omits it — i.e. "no discount happened".
  final int grossUzs;

  /// How much [discountUzs] was taken off — 0 when no discount applied.
  final int discountUzs;

  /// The discount actually applied, snapshotted by the server — null when
  /// none was. Server truth only; never re-derived client-side.
  final DiscountSnapshot? discount;
  final int cashUzs;
  final int cardUzs;
  final int balanceUzs;
  final DateTime createdAt;

  /// Rung up while the terminal was offline — not on the server yet. The
  /// printer marks the paper; [id] is the offline request id.
  final bool isOffline;
  final List<SaleReceiptItem> items;

  /// Null unless the server minted a cashback code for this sale (online
  /// GOODS_CHECKOUT with cashback enabled) — see [SaleCashback].
  final SaleCashback? cashback;

  factory SaleReceipt.fromJson(Map<String, dynamic> json) => SaleReceipt(
    id: json['id'] as String,
    subtotalUzs: json['subtotalUzs'] as int,
    grossUzs: json['grossUzs'] as int?,
    discountUzs: (json['discountUzs'] as int?) ?? 0,
    discount: json['discount'] == null
        ? null
        : DiscountSnapshot.fromJson(json['discount'] as Map<String, dynamic>),
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    balanceUzs: (json['balanceUzs'] as int?) ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    items: (json['items'] as List)
        .map((item) => SaleReceiptItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    cashback: SaleCashback.tryFromJson(json['cashback']),
  );

  @override
  List<Object?> get props => [
    id,
    subtotalUzs,
    grossUzs,
    discountUzs,
    discount,
    cashUzs,
    cardUzs,
    balanceUzs,
    createdAt,
    isOffline,
    items,
    cashback,
  ];
}
