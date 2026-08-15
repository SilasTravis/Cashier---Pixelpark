import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../products/data/products_repository_impl.dart';
import '../../../products/domain/product.dart';
import '../../data/pos_sale_remote_data_source.dart';
import '../../data/pos_sale_repository_impl.dart';
import '../../domain/cart_line.dart';
import '../../domain/sale_receipt.dart';

part 'pos_sale_event.dart';
part 'pos_sale_state.dart';

class PosSaleBloc extends Bloc<PosSaleEvent, PosSaleState> {
  PosSaleBloc(this._repository, this._products) : super(const PosSaleState()) {
    on<PosSaleStarted>(_onStarted);
    on<PosSaleSearchChanged>(_onSearchChanged);
    on<PosSaleCategorySelected>(_onCategorySelected);
    on<PosSaleProductAdded>(_onProductAdded);
    on<PosSaleQtyChanged>(_onQtyChanged);
    on<PosSaleLineRemoved>(_onLineRemoved);
    on<PosSaleCartCleared>(_onCartCleared);
    on<PosSaleCheckoutRequested>(_onCheckoutRequested);
    on<PosSaleReceiptAcknowledged>(_onReceiptAcknowledged);
  }

  final PosSaleRepository _repository;
  final ProductsRepository _products;

  Future<void> _onStarted(
    PosSaleStarted event,
    Emitter<PosSaleState> emit,
  ) async {
    emit(state.copyWith(isLoadingProducts: true));
    final result = await _products.listProducts();
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoadingProducts: false,
          errorMessage: _messageOf(failure),
        ),
      ),
      (products) =>
          emit(state.copyWith(isLoadingProducts: false, products: products)),
    );
  }

  void _onSearchChanged(PosSaleSearchChanged event, Emitter<PosSaleState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onCategorySelected(
    PosSaleCategorySelected event,
    Emitter<PosSaleState> emit,
  ) {
    emit(
      state.copyWith(
        selectedCategory: event.category,
        clearCategory: event.category == null,
      ),
    );
  }

  void _onProductAdded(PosSaleProductAdded event, Emitter<PosSaleState> emit) {
    final cart = Map<String, int>.from(state.cart);
    cart[event.product.id] = (cart[event.product.id] ?? 0) + 1;
    emit(state.copyWith(cart: cart));
  }

  void _onQtyChanged(PosSaleQtyChanged event, Emitter<PosSaleState> emit) {
    final cart = Map<String, int>.from(state.cart);
    if (event.qty <= 0) {
      cart.remove(event.productId);
    } else {
      cart[event.productId] = event.qty;
    }
    emit(state.copyWith(cart: cart));
  }

  void _onLineRemoved(PosSaleLineRemoved event, Emitter<PosSaleState> emit) {
    final cart = Map<String, int>.from(state.cart)..remove(event.productId);
    emit(state.copyWith(cart: cart));
  }

  void _onCartCleared(PosSaleCartCleared event, Emitter<PosSaleState> emit) {
    emit(state.copyWith(cart: const {}));
  }

  Future<void> _onCheckoutRequested(
    PosSaleCheckoutRequested event,
    Emitter<PosSaleState> emit,
  ) async {
    if (state.cart.isEmpty) return;
    emit(state.copyWith(isCheckingOut: true, errorMessage: null));
    final lines = [
      for (final entry in state.cart.entries)
        CheckoutLine(productId: entry.key, qty: entry.value),
    ];
    final result = await _repository.checkout(
      lines: lines,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isCheckingOut: false, errorMessage: _messageOf(failure)),
      ),
      (receipt) => emit(
        state.copyWith(
          isCheckingOut: false,
          cart: const {},
          lastReceipt: receipt,
        ),
      ),
    );
  }

  void _onReceiptAcknowledged(
    PosSaleReceiptAcknowledged event,
    Emitter<PosSaleState> emit,
  ) {
    emit(state.copyWith(clearLastReceipt: true));
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => 'Xatolik yuz berdi',
    };
  }
}
