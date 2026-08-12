import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../products/data/products_repository_impl.dart';
import '../../../products/domain/product.dart';
import '../../data/pos_account_repository_impl.dart';
import '../../domain/customer.dart';
import '../../domain/gate_pass.dart';

part 'pos_account_event.dart';
part 'pos_account_state.dart';

class PosAccountBloc extends Bloc<PosAccountEvent, PosAccountState> {
  PosAccountBloc(this._repository, this._products)
    : super(const PosAccountState()) {
    on<PosAccountDigitPressed>(_onDigitPressed);
    on<PosAccountBackspacePressed>(_onBackspacePressed);
    on<PosAccountSearchRequested>(_onSearchRequested);
    on<PosAccountCustomerSelected>(_onCustomerSelected);
    on<PosAccountSelectionCleared>(_onSelectionCleared);
    on<PosAccountNewCustomerRequested>(_onNewCustomerRequested);
    on<PosAccountChildAddRequested>(_onChildAddRequested);
    on<PosAccountTopupRequested>(_onTopupRequested);
    on<PosAccountProductsRequested>(_onProductsRequested);
    on<PosAccountPassesRequested>(_onPassesRequested);
    on<PosAccountIssuedPassesAcknowledged>(_onIssuedPassesAcknowledged);
  }

  final PosAccountRepository _repository;
  final ProductsRepository _products;

  static const _maxPhoneDigits = 9;

  void _onDigitPressed(
    PosAccountDigitPressed event,
    Emitter<PosAccountState> emit,
  ) {
    if (state.phoneDigits.length >= _maxPhoneDigits) return;
    emit(
      state.copyWith(
        phoneDigits: state.phoneDigits + event.digit,
        errorMessage: null,
      ),
    );
  }

  void _onBackspacePressed(
    PosAccountBackspacePressed event,
    Emitter<PosAccountState> emit,
  ) {
    if (state.phoneDigits.isEmpty) return;
    emit(
      state.copyWith(
        phoneDigits: state.phoneDigits.substring(
          0,
          state.phoneDigits.length - 1,
        ),
      ),
    );
  }

  Future<void> _onSearchRequested(
    PosAccountSearchRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.phoneDigits.length < 7) return;
    emit(
      state.copyWith(
        isSearching: true,
        errorMessage: null,
        results: [],
        selectedCustomer: null,
        clearSelected: true,
      ),
    );
    final result = await _repository.searchCustomers(state.phoneDigits);
    result.fold(
      (failure) => emit(
        state.copyWith(isSearching: false, errorMessage: _messageOf(failure)),
      ),
      (customers) =>
          emit(state.copyWith(isSearching: false, results: customers)),
    );
  }

  Future<void> _onCustomerSelected(
    PosAccountCustomerSelected event,
    Emitter<PosAccountState> emit,
  ) async {
    emit(state.copyWith(selectedCustomer: event.customer));
    add(const PosAccountProductsRequested());
  }

  void _onSelectionCleared(
    PosAccountSelectionCleared event,
    Emitter<PosAccountState> emit,
  ) {
    emit(const PosAccountState());
  }

  Future<void> _onNewCustomerRequested(
    PosAccountNewCustomerRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.createCustomer(
      phoneNumber: state.phoneDigits,
      fullName: event.fullName,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (customer) {
        emit(
          state.copyWith(
            isBusy: false,
            selectedCustomer: customer,
            results: [customer],
          ),
        );
        add(const PosAccountProductsRequested());
      },
    );
  }

  Future<void> _onChildAddRequested(
    PosAccountChildAddRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.addChild(
      customerId: customer.id,
      firstName: event.firstName,
      lastName: event.lastName,
      birthDate: event.birthDate,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (child) => emit(
        state.copyWith(
          isBusy: false,
          selectedCustomer: customer.copyWith(
            children: [...customer.children, child],
          ),
        ),
      ),
    );
  }

  Future<void> _onTopupRequested(
    PosAccountTopupRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.topup(
      customerId: customer.id,
      amountUzs: event.amountUzs,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (topup) => emit(
        state.copyWith(
          isBusy: false,
          selectedCustomer: customer.copyWith(balance: topup.balance),
        ),
      ),
    );
  }

  Future<void> _onProductsRequested(
    PosAccountProductsRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.products.isNotEmpty) return;
    emit(state.copyWith(isLoadingProducts: true));
    final result = await _products.listProducts();
    result.fold(
      (failure) => emit(state.copyWith(isLoadingProducts: false)),
      (products) =>
          emit(state.copyWith(isLoadingProducts: false, products: products)),
    );
  }

  Future<void> _onPassesRequested(
    PosAccountPassesRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.issuePasses(
      customerId: customer.id,
      productId: event.productId,
      childIds: event.childIds,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (issued) => emit(state.copyWith(isBusy: false, lastIssuedPasses: issued)),
    );
  }

  void _onIssuedPassesAcknowledged(
    PosAccountIssuedPassesAcknowledged event,
    Emitter<PosAccountState> emit,
  ) {
    emit(state.copyWith(clearLastIssuedPasses: true));
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => 'Xatolik yuz berdi',
    };
  }
}
