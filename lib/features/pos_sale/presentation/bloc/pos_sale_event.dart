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

/// Picking a discount (or clearing it, when [discountId] is null) from the
/// cart panel's picker.
class PosSaleDiscountSelected extends PosSaleEvent {
  const PosSaleDiscountSelected(this.discountId);

  final String? discountId;

  @override
  List<Object?> get props => [discountId];
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

/// The app switched online ↔ offline (dispatched by `PosSalePage` from
/// `AppModeCubit`). Reloads the catalog from the right source.
class PosSaleModeChanged extends PosSaleEvent {
  const PosSaleModeChanged(this.offline);

  final bool offline;

  @override
  List<Object?> get props => [offline];
}
