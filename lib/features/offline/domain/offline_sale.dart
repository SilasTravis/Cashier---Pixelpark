import 'package:equatable/equatable.dart';

import '../../../core/utils/receipt_id.dart';
import '../../pos_sale/domain/discount.dart';
import '../../pos_sale/domain/sale_receipt.dart';

enum OfflineSaleStatus { pending, failed }

class OfflineSaleLine extends Equatable {
  const OfflineSaleLine({
    required this.productId,
    required this.name,
    required this.priceUzs,
    required this.qty,
  });

  final String productId;
  final String name;

  /// The unit price printed on the receipt — the server records exactly this.
  final int priceUzs;
  final int qty;

  int get lineTotalUzs => priceUzs * qty;

  factory OfflineSaleLine.fromJson(Map<String, dynamic> json) =>
      OfflineSaleLine(
        productId: json['productId'] as String,
        name: json['name'] as String,
        priceUzs: json['priceUzs'] as int,
        qty: json['qty'] as int,
      );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'name': name,
    'priceUzs': priceUzs,
    'qty': qty,
  };

  @override
  List<Object?> get props => [productId, name, priceUzs, qty];
}

/// One sale rung up while the terminal was offline, waiting to reach
/// `POST /v1/pos/offline/sync`. [offlineRequestId] is minted when the sale is
/// rung up and is the server's idempotency key, so any retry is safe.
class OfflineSale extends Equatable {
  const OfflineSale({
    required this.offlineRequestId,
    required this.cashierId,
    required this.createdAt,
    this.shiftId,
    this.shiftOfflineRequestId,
    required this.lines,
    this.discount,
    required this.cashUzs,
    required this.cardUzs,
    this.status = OfflineSaleStatus.pending,
    this.failureCode,
    this.failureMessage,
    this.attempts = 0,
    this.lastAttemptAt,
  });

  final String offlineRequestId;
  final String cashierId;
  final DateTime createdAt;

  /// The server shift it was rung under, when the terminal had one cached…
  final String? shiftId;

  /// …or the shift this terminal opened offline (see `OfflineShift`).
  final String? shiftOfflineRequestId;
  final List<OfflineSaleLine> lines;

  /// The discount exactly as the terminal applied it. The server honours
  /// these kind/value numbers even if the discount was disabled since.
  final Discount? discount;
  final int cashUzs;
  final int cardUzs;
  final OfflineSaleStatus status;
  final String? failureCode;
  final String? failureMessage;
  final int attempts;
  final DateTime? lastAttemptAt;

  int get grossUzs => lines.fold(0, (sum, line) => sum + line.lineTotalUzs);
  int get discountUzs => discount?.appliedDiscountUzs(grossUzs) ?? 0;
  int get totalUzs => grossUzs - discountUzs;
  bool get isFailed => status == OfflineSaleStatus.failed;

  /// What the cashier reads to support — the same 8 characters printed as
  /// the receipt number.
  String get supportCode => formatReceiptId(offlineRequestId);

  OfflineSale markFailed({
    required String? code,
    required String message,
    required DateTime at,
  }) => OfflineSale(
    offlineRequestId: offlineRequestId,
    cashierId: cashierId,
    createdAt: createdAt,
    shiftId: shiftId,
    shiftOfflineRequestId: shiftOfflineRequestId,
    lines: lines,
    discount: discount,
    cashUzs: cashUzs,
    cardUzs: cardUzs,
    status: OfflineSaleStatus.failed,
    failureCode: code,
    failureMessage: message,
    attempts: attempts + 1,
    lastAttemptAt: at,
  );

  SaleReceipt toReceipt() => SaleReceipt(
    id: offlineRequestId,
    subtotalUzs: totalUzs,
    grossUzs: grossUzs,
    discountUzs: discountUzs,
    discount: discount == null
        ? null
        : DiscountSnapshot(
            id: discount!.id,
            name: discount!.name,
            kind: discount!.kind,
            value: discount!.value,
          ),
    cashUzs: cashUzs,
    cardUzs: cardUzs,
    createdAt: createdAt,
    isOffline: true,
    items: [
      for (final line in lines)
        SaleReceiptItem(
          productId: line.productId,
          nameSnapshot: line.name,
          priceSnapshotUzs: line.priceUzs,
          qty: line.qty,
          lineTotalUzs: line.lineTotalUzs,
        ),
    ],
  );

  /// One entry of the `sales` array in `POST /v1/pos/offline/sync`. Once the
  /// offline shift has a server id, pass it so a retry doesn't depend on
  /// the server resolving the offline id again.
  Map<String, dynamic> toSyncJson({String? serverShiftIdForOfflineShift}) => {
    'offlineRequestId': offlineRequestId,
    if (shiftId != null)
      'shiftId': shiftId
    else if (serverShiftIdForOfflineShift != null)
      'shiftId': serverShiftIdForOfflineShift
    else if (shiftOfflineRequestId != null)
      'shiftOfflineRequestId': shiftOfflineRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lines': [
      for (final line in lines)
        {
          'productId': line.productId,
          'qty': line.qty,
          'priceSnapshotUzs': line.priceUzs,
        },
    ],
    if (discount != null)
      'discount': {
        'id': discount!.id,
        'kind': discount!.kind.name,
        'value': discount!.value,
      },
    'cashUzs': cashUzs,
    'cardUzs': cardUzs,
  };

  Map<String, dynamic> toJson() => {
    'offlineRequestId': offlineRequestId,
    'cashierId': cashierId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'shiftId': shiftId,
    'shiftOfflineRequestId': shiftOfflineRequestId,
    'lines': [for (final line in lines) line.toJson()],
    'discount': discount?.toJson(),
    'cashUzs': cashUzs,
    'cardUzs': cardUzs,
    'status': status.name,
    'failureCode': failureCode,
    'failureMessage': failureMessage,
    'attempts': attempts,
    'lastAttemptAt': lastAttemptAt?.toUtc().toIso8601String(),
  };

  factory OfflineSale.fromJson(Map<String, dynamic> json) => OfflineSale(
    offlineRequestId: json['offlineRequestId'] as String,
    cashierId: json['cashierId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    shiftId: json['shiftId'] as String?,
    shiftOfflineRequestId: json['shiftOfflineRequestId'] as String?,
    lines: [
      for (final line in json['lines'] as List)
        OfflineSaleLine.fromJson(Map<String, dynamic>.from(line as Map)),
    ],
    discount: json['discount'] == null
        ? null
        : Discount.fromJson(Map<String, dynamic>.from(json['discount'] as Map)),
    cashUzs: json['cashUzs'] as int,
    cardUzs: json['cardUzs'] as int,
    status: json['status'] == 'failed'
        ? OfflineSaleStatus.failed
        : OfflineSaleStatus.pending,
    failureCode: json['failureCode'] as String?,
    failureMessage: json['failureMessage'] as String?,
    attempts: json['attempts'] as int? ?? 0,
    lastAttemptAt: json['lastAttemptAt'] == null
        ? null
        : DateTime.parse(json['lastAttemptAt'] as String),
  );

  @override
  List<Object?> get props => [
    offlineRequestId,
    cashierId,
    createdAt,
    shiftId,
    shiftOfflineRequestId,
    lines,
    discount,
    cashUzs,
    cardUzs,
    status,
    failureCode,
    failureMessage,
    attempts,
    lastAttemptAt,
  ];
}
