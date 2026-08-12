import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../data/products_repository_impl.dart';
import '../../domain/product.dart';

part 'products_event.dart';
part 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc(this._repository) : super(const ProductsState()) {
    on<ProductsStarted>(_onStarted);
    on<ProductsSearchChanged>(_onSearchChanged);
    on<ProductsCategorySelected>(_onCategorySelected);
  }

  final ProductsRepository _repository;

  Future<void> _onStarted(
    ProductsStarted event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    final result = await _repository.listProducts();
    result.fold(
      (failure) => emit(
        state.copyWith(isLoading: false, errorMessage: _messageOf(failure)),
      ),
      (products) => emit(state.copyWith(isLoading: false, products: products)),
    );
  }

  void _onSearchChanged(
    ProductsSearchChanged event,
    Emitter<ProductsState> emit,
  ) {
    emit(state.copyWith(query: event.query));
  }

  void _onCategorySelected(
    ProductsCategorySelected event,
    Emitter<ProductsState> emit,
  ) {
    emit(
      state.copyWith(
        selectedCategory: event.category,
        clearCategory: event.category == null,
      ),
    );
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => 'Xatolik yuz berdi',
    };
  }
}
