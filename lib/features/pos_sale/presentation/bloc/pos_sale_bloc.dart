import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../products/data/products_repository_impl.dart';
import '../../../products/domain/product.dart';
import '../../data/pos_sale_remote_data_source.dart';
import '../../data/pos_sale_repository_impl.dart';
import '../../domain/cart_line.dart';
import '../../domain/discount.dart';
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
    on<PosSaleDiscountSelected>(_onDiscountSelected);
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
    // Started concurrently — a slow/failing discount catalog must never
    // delay showing products.
    final productsFuture = _products.listProducts();
    final discountsFuture = _repository.fetchDiscounts();
    final productsResult = await productsFuture;
    final discountsResult = await discountsFuture;
    final discounts = discountsResult.fold(
      (_) => const <Discount>[],
      (list) => list,
    );
    productsResult.fold(
      (failure) => emit(
        state.copyWith(
          isLoadingProducts: false,
          errorMessage: _messageOf(failure),
          discounts: discounts,
        ),
      ),
      (products) => emit(
        state.copyWith(
          isLoadingProducts: false,
          products: products,
          discounts: discounts,
        ),
      ),
    );
  }

  void _onSearchChanged(
    PosSaleSearchChanged event,
    Emitter<PosSaleState> emit,
  ) {
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
    // Clearing the cart drops the discount pick too — it must never survive
    // to be silently re-applied to a brand new cart.
    emit(state.copyWith(cart: const {}, clearSelectedDiscountId: true));
  }

  void _onDiscountSelected(
    PosSaleDiscountSelected event,
    Emitter<PosSaleState> emit,
  ) {
    emit(
      state.copyWith(
        selectedDiscountId: event.discountId,
        clearSelectedDiscountId: event.discountId == null,
      ),
    );
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
      discountId: state.selectedDiscountId,
    );
    await result.fold(
      (failure) async {
        // The picked discount was disabled/deleted between fetch and
        // checkout — never silently charge full price. Clear the stale
        // pick and refetch so the cashier re-selects from a fresh catalog.
        if (failure is ServerFailure &&
            failure.code == 'DISCOUNT_NOT_AVAILABLE') {
          final refreshed = await _repository.fetchDiscounts();
          emit(
            state.copyWith(
              isCheckingOut: false,
              errorMessage: _messageOf(failure),
              errorCode: failure.code,
              clearSelectedDiscountId: true,
              discounts: refreshed.fold((_) => state.discounts, (list) => list),
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: _messageOf(failure),
          ),
        );
      },
      (receipt) async => emit(
        state.copyWith(
          isCheckingOut: false,
          cart: const {},
          clearSelectedDiscountId: true,
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
