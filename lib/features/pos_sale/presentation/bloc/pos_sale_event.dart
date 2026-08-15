part of 'pos_sale_bloc.dart';

sealed class PosSaleEvent extends Equatable {
  const PosSaleEvent();

  @override
  List<Object?> get props => [];
}

class PosSaleStarted extends PosSaleEvent {
  const PosSaleStarted();
}

class PosSaleSearchChanged extends PosSaleEvent {
  const PosSaleSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class PosSaleCategorySelected extends PosSaleEvent {
  const PosSaleCategorySelected(this.category);

  final String? category;

  @override
  List<Object?> get props => [category];
}

class PosSaleProductAdded extends PosSaleEvent {
  const PosSaleProductAdded(this.product);

  final Product product;

  @override
  List<Object?> get props => [product];
}

class PosSaleQtyChanged extends PosSaleEvent {
  const PosSaleQtyChanged({required this.productId, required this.qty});

  final String productId;
  final int qty;

  @override
  List<Object?> get props => [productId, qty];
}

class PosSaleLineRemoved extends PosSaleEvent {
  const PosSaleLineRemoved(this.productId);

  final String productId;

  @override
  List<Object?> get props => [productId];
}

class PosSaleCartCleared extends PosSaleEvent {
  const PosSaleCartCleared();
}

class PosSaleCheckoutRequested extends PosSaleEvent {
  const PosSaleCheckoutRequested({
    required this.cashUzs,
    required this.cardUzs,
  });

  final int cashUzs;
  final int cardUzs;

  @override
  List<Object?> get props => [cashUzs, cardUzs];
}

class PosSaleReceiptAcknowledged extends PosSaleEvent {
  const PosSaleReceiptAcknowledged();
}
