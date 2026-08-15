import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../products/domain/product.dart';
import '../../data/pos_account_remote_data_source.dart' show CheckoutLine;
import '../../data/pos_account_repository_impl.dart';
import '../../domain/customer.dart';
import '../../domain/kids_plan.dart';
import '../../domain/playing_child.dart';
import '../../domain/pos_entry.dart';

part 'pos_account_event.dart';
part 'pos_account_state.dart';

class PosAccountBloc extends Bloc<PosAccountEvent, PosAccountState> {
  PosAccountBloc(this._repository) : super(const PosAccountState()) {
    on<PosAccountDigitPressed>(_onDigitPressed);
    on<PosAccountBackspacePressed>(_onBackspacePressed);
    on<PosAccountSearchRequested>(_onSearchRequested);
    on<PosAccountRecentCustomersRequested>(_onRecentCustomersRequested);
    on<PosAccountCustomerSelected>(_onCustomerSelected);
    on<PosAccountSelectionCleared>(_onSelectionCleared);
    on<PosAccountNewCustomerRequested>(_onNewCustomerRequested);
    on<PosAccountChildAddRequested>(_onChildAddRequested);
    on<PosAccountTopupRequested>(_onTopupRequested);
    on<PosAccountPlansRequested>(_onPlansRequested);
    on<PosAccountPlanEntryRequested>(_onPlanEntryRequested);
    on<PosAccountEntryAcknowledged>(_onEntryAcknowledged);
    on<PosAccountProductsRequested>(_onProductsRequested);
    on<PosAccountPlayingRequested>(_onPlayingRequested);
    on<PosAccountCheckoutRequested>(_onCheckoutRequested);
  }

  final PosAccountRepository _repository;

  static const _maxPhoneDigits = 9;
  static const _minSearchDigits = 7;
  static const _searchDebounce = Duration(milliseconds: 350);

  Timer? _debounce;

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
    _scheduleAutoSearch();
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
    _scheduleAutoSearch();
  }

  /// Live search — fires shortly after the cashier stops typing, once there
  /// are enough digits to search on. Debounced rather than firing on every
  /// keystroke so a quick run of digit presses doesn't queue up one request
  /// per digit.
  void _scheduleAutoSearch() {
    _debounce?.cancel();
    if (state.phoneDigits.length < _minSearchDigits) return;
    _debounce = Timer(
      _searchDebounce,
      () => add(const PosAccountSearchRequested()),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onSearchRequested(
    PosAccountSearchRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.phoneDigits.length < _minSearchDigits) return;
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

  /// Populates the browsable default list shown before any digits are
  /// typed. Best-effort — searching with an empty phone is expected to
  /// return the backend's own "most recent" ordering; a failure here just
  /// leaves the plain hint in place rather than surfacing an error.
  Future<void> _onRecentCustomersRequested(
    PosAccountRecentCustomersRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    try {
      final result = await _repository.searchCustomers('');
      result.fold((failure) {}, (customers) {
        emit(state.copyWith(recentCustomers: customers.take(10).toList()));
      });
    } catch (_) {
      // Best-effort — an unexpected response shape here must never surface
      // to the cashier or break the rest of the page.
    }
  }

  Future<void> _onCustomerSelected(
    PosAccountCustomerSelected event,
    Emitter<PosAccountState> emit,
  ) async {
    emit(state.copyWith(selectedCustomer: event.customer, playing: []));
    add(const PosAccountPlayingRequested());
  }

  void _onSelectionCleared(
    PosAccountSelectionCleared event,
    Emitter<PosAccountState> emit,
  ) {
    emit(
      PosAccountState(recentCustomers: state.recentCustomers, plans: state.plans),
    );
  }

  Future<void> _onNewCustomerRequested(
    PosAccountNewCustomerRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.createCustomer(
      // Existing customers are stored as `+998XXXXXXXXX` — sending the bare
      // 9 digits here created a second, unprefixed record for the same
      // number instead of matching it.
      phoneNumber: '+998${state.phoneDigits}',
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

  Future<void> _onPlansRequested(
    PosAccountPlansRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.plans.isNotEmpty) return;
    emit(state.copyWith(isLoadingPlans: true));
    final result = await _repository.listPlans();
    result.fold(
      (failure) => emit(state.copyWith(isLoadingPlans: false)),
      (plans) => emit(state.copyWith(isLoadingPlans: false, plans: plans)),
    );
  }

  Future<void> _onPlanEntryRequested(
    PosAccountPlanEntryRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.issuePlanEntry(
      customerId: customer.id,
      planKey: event.planKey,
      childIds: event.childIds,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (entryResult) => emit(
        state.copyWith(isBusy: false, lastEntryResult: entryResult),
      ),
    );
  }

  void _onEntryAcknowledged(
    PosAccountEntryAcknowledged event,
    Emitter<PosAccountState> emit,
  ) {
    emit(state.copyWith(clearLastEntryResult: true));
  }

  Future<void> _onPlayingRequested(
    PosAccountPlayingRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    final result = await _repository.listPlaying(customer.id);
    // Best-effort: a failed refresh keeps the previous list rather than
    // surfacing an error over the whole page.
    result.fold((failure) {}, (playing) {
      if (state.selectedCustomer?.id == customer.id) {
        emit(state.copyWith(playing: playing));
      }
    });
  }

  Future<void> _onProductsRequested(
    PosAccountProductsRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.products.isNotEmpty) return;
    final result = await _repository.listProducts();
    // Best-effort like plans: a failure just leaves the product section
    // empty rather than blocking the whole page.
    result.fold((failure) {}, (products) {
      emit(state.copyWith(products: products));
    });
  }

  Future<void> _onCheckoutRequested(
    PosAccountCheckoutRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.planEntryCheckout(
      customerId: customer.id,
      planKey: event.planKey,
      childIds: event.childIds,
      products: event.products,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (entryResult) {
        emit(
          state.copyWith(
            isBusy: false,
            lastEntryResult: entryResult,
            selectedCustomer: entryResult.balance == null
                ? customer
                : customer.copyWith(balance: entryResult.balance!),
          ),
        );
        // Fresh entries mean fresh inside-children rows.
        add(const PosAccountPlayingRequested());
      },
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
