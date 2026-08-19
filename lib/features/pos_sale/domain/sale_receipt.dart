import 'package:equatable/equatable.dart';

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

  @override
  List<Object?> get props => [
    productId,
    nameSnapshot,
    priceSnapshotUzs,
    qty,
    lineTotalUzs,
  ];
}

class SaleReceipt extends Equatable {
  const SaleReceipt({
    required this.id,
    required this.subtotalUzs,
    required this.cashUzs,
    required this.cardUzs,
    this.balanceUzs = 0,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final int subtotalUzs;
  final int cashUzs;
  final int cardUzs;
  final int balanceUzs;
  final DateTime createdAt;
  final List<SaleReceiptItem> items;

  @override
  List<Object?> get props => [
    id,
    subtotalUzs,
    cashUzs,
    cardUzs,
    balanceUzs,
    createdAt,
    items,
  ];
}
