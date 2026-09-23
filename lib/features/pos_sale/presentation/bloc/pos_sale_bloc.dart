import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../offline/application/offline_checkout.dart';
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
  PosSaleBloc(
    this._repository,
    this._products,
    this._offlineCheckout, {
    bool offlineMode = false,
  }) : super(PosSaleState(offlineMode: offlineMode)) {
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
    on<PosSaleModeChanged>(_onModeChanged);
  }

  final PosSaleRepository _repository;
  final ProductsRepository _products;
  final OfflineCheckout _offlineCheckout;

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
    if (state.cart.isEmpty || state.isCheckingOut) return;
    emit(state.copyWith(isCheckingOut: true, errorMessage: null));
    if (state.offlineMode) {
      try {
        final sale = await _offlineCheckout.record(
          lines: state.cartLines,
          discount: state.selectedDiscount,
          cashUzs: event.cashUzs,
          cardUzs: event.cardUzs,
        );
        emit(
          state.copyWith(
            isCheckingOut: false,
            cart: const {},
            clearSelectedDiscountId: true,
            lastReceipt: sale.toReceipt(),
          ),
        );
      } on NoShiftForOfflineSaleException {
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: "Offline savdo uchun ochiq smena yo'q",
          ),
        );
      } on OfflinePaymentShortException {
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: "To'lov summasi yetarli emas",
          ),
        );
      } catch (_) {
        emit(
          state.copyWith(
            isCheckingOut: false,
            errorMessage: "Savdo saqlanmadi. Qayta urinib ko'ring.",
          ),
        );
      }
      return;
    }
    final lines = [
      for (final entry in state.cart.entries)
        CheckoutLine(productId: entry.key, qty: entry.value),
    ];
    try {
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
                discounts: refreshed.fold(
                  (_) => state.discounts,
                  (list) => list,
                ),
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
    } catch (_) {
      // The request may already have reached the server and committed the
      // sale before the response body failed to parse (a malformed
      // SaleReceipt/ServerException JSON) — never invite a blind retry that
      // could double-charge. Leave the cart untouched so the cashier can
      // check sales history first.
      emit(
        state.copyWith(
          isCheckingOut: false,
          errorMessage:
              "Server javobini o'qib bo'lmadi. Savdo tarixini tekshiring, keyin qayta urining.",
        ),
      );
    }
  }

  void _onReceiptAcknowledged(
    PosSaleReceiptAcknowledged event,
    Emitter<PosSaleState> emit,
  ) {
    emit(state.copyWith(clearLastReceipt: true));
  }

  Future<void> _onModeChanged(
    PosSaleModeChanged event,
    Emitter<PosSaleState> emit,
  ) async {
    if (event.offline == state.offlineMode) return;
    final byId = {for (final product in state.products) product.id: product};
    final cart = event.offline
        ? state.cart
        : {
            for (final entry in state.cart.entries)
              if (!(byId[entry.key]?.offlineOnly ?? false))
                entry.key: entry.value,
          };
    emit(state.copyWith(offlineMode: event.offline, cart: cart));
    await _onStarted(const PosSaleStarted(), emit);
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      CacheFailure(:final message) => message,
      _ => 'Xatolik yuz berdi',
    };
  }
}
