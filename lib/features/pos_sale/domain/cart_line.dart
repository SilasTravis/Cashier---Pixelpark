import 'package:equatable/equatable.dart';

import '../../products/domain/product.dart';

class CartLine extends Equatable {
  const CartLine({required this.product, required this.qty});

  final Product product;
  final int qty;

  int get lineTotalUzs => product.priceUzs * qty;

  @override
  List<Object?> get props => [product, qty];
}
