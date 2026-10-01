import 'package:equatable/equatable.dart';

/// Pixel Market order lifecycle, mirroring the backend's
/// `MARKET_ORDER_STATUSES`. The till only acts on two moves:
/// [handedOver] → [atBranch] ("Qabul qildim") and [atBranch] → [pickedUp]
/// ("Topshirildi"). An unknown future status parses as [unknown] instead of
/// crashing the list.
enum MarketOrderStatus {
  placed('placed'),
  confirmed('confirmed'),
  handedOver('handed_over'),
  atBranch('at_branch'),
  pickedUp('picked_up'),
  cancelled('cancelled'),
  unknown('');

  const MarketOrderStatus(this.wire);

  final String wire;

  static MarketOrderStatus parse(Object? raw) => values.firstWhere(
    (status) => status != unknown && status.wire == raw,
    orElse: () => unknown,
  );
}

/// The parent's 6-digit pickup code, from whatever the scanner gun or the
/// keyboard typed: the QR's content is just the digits, so anything else (a
/// scanner's prefix byte, trailing CR/LF/Tab, spaces) is dropped. Digits are
/// keyboard-layout independent, so a Russian layout can't garble a scan.
/// Null when the result isn't exactly 6 digits — no request is made then.
String? normalizePickupCode(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == pickupCodeLength ? digits : null;
}

const pickupCodeLength = 6;

class MarketOrderItem extends Equatable {
  const MarketOrderItem({
    required this.productName,
    required this.variantLabel,
    required this.imageUrl,
    required this.quantity,
    required this.unitPriceUzs,
    required this.lineTotalUzs,
  });

  factory MarketOrderItem.fromJson(Map<String, dynamic> json) =>
      MarketOrderItem(
        productName: json['productName'] as String? ?? '',
        variantLabel: json['variantLabel'] as String? ?? '',
        imageUrl: json['imageUrl'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitPriceUzs: (json['unitPriceUzs'] as num?)?.toInt() ?? 0,
        lineTotalUzs: (json['lineTotalUzs'] as num?)?.toInt() ?? 0,
      );

  final String productName;

  /// "Pushti · M"; empty for a product without variants.
  final String variantLabel;
  final String? imageUrl;
  final int quantity;
  final int unitPriceUzs;
  final int lineTotalUzs;

  @override
  List<Object?> get props => [
    productName,
    variantLabel,
    imageUrl,
    quantity,
    unitPriceUzs,
    lineTotalUzs,
  ];
}

/// One shop's part of a parent's market checkout, as the backend's
/// `toOrderResponse` returns it to the cashier.
class MarketOrder extends Equatable {
  const MarketOrder({
    required this.id,
    required this.checkoutId,
    required this.status,
    required this.shopName,
    required this.shopLogoUrl,
    required this.branchName,
    required this.pickupCode,
    required this.customerName,
    required this.customerPhone,
    required this.itemsTotalUzs,
    required this.items,
    required this.createdAt,
  });

  factory MarketOrder.fromJson(Map<String, dynamic> json) {
    final seller = _map(json['seller']);
    final branch = _map(json['branch']);
    final customer = _map(json['customer']);
    final items = json['items'];
    return MarketOrder(
      id: json['id'] as String,
      checkoutId: json['checkoutId'] as String? ?? '',
      status: MarketOrderStatus.parse(json['status']),
      shopName: seller['shopName'] as String? ?? '',
      shopLogoUrl: seller['logoUrl'] as String?,
      branchName: branch['name'] as String? ?? '',
      pickupCode: json['pickupCode'] as String?,
      customerName: customer['name'] as String?,
      customerPhone: customer['phone'] as String?,
      itemsTotalUzs: (json['itemsTotalUzs'] as num?)?.toInt() ?? 0,
      items: items is List
          ? [for (final raw in items) MarketOrderItem.fromJson(_map(raw))]
          : const [],
      createdAt: DateTime.tryParse(
        json['createdAt'] as String? ?? '',
      )?.toLocal(),
    );
  }

  static Map<String, dynamic> _map(Object? raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : const {};

  final String id;

  /// Shared by every shop's order of one parent checkout.
  final String checkoutId;
  final MarketOrderStatus status;
  final String shopName;
  final String? shopLogoUrl;
  final String branchName;

  /// Null on the incoming list on purpose — the cashier sees it only after
  /// the parent shows it.
  final String? pickupCode;
  final String? customerName;
  final String? customerPhone;
  final int itemsTotalUzs;
  final List<MarketOrderItem> items;
  final DateTime? createdAt;

  /// The number the parent sees in the app: the checkout id's first 8
  /// characters, uppercased.
  String get orderNumber {
    final head = checkoutId.length > 8
        ? checkoutId.substring(0, 8)
        : checkoutId;
    return head.toUpperCase();
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  MarketOrder copyWith({MarketOrderStatus? status}) => MarketOrder(
    id: id,
    checkoutId: checkoutId,
    status: status ?? this.status,
    shopName: shopName,
    shopLogoUrl: shopLogoUrl,
    branchName: branchName,
    pickupCode: pickupCode,
    customerName: customerName,
    customerPhone: customerPhone,
    itemsTotalUzs: itemsTotalUzs,
    items: items,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    checkoutId,
    status,
    shopName,
    shopLogoUrl,
    branchName,
    pickupCode,
    customerName,
    customerPhone,
    itemsTotalUzs,
    items,
    createdAt,
  ];
}
