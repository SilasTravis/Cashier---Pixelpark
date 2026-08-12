part of 'products_bloc.dart';

sealed class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class ProductsStarted extends ProductsEvent {
  const ProductsStarted();
}

class ProductsSearchChanged extends ProductsEvent {
  const ProductsSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

class ProductsCategorySelected extends ProductsEvent {
  const ProductsCategorySelected(this.category);

  final String? category;

  @override
  List<Object?> get props => [category];
}
