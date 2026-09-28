import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/local_source/local_source.dart';
import '../../../products/domain/product.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../data/pos_account_remote_data_source.dart' show CheckoutLine;
import '../../data/pos_account_repository_impl.dart';
import '../../domain/active_pass.dart';
import '../../domain/customer.dart';
import '../../domain/kids_plan.dart';
import '../../domain/parent_pass.dart';
import '../../domain/playing_child.dart';
import '../../domain/pos_entry.dart';
import '../../domain/promo_code_check.dart';
import '../../../../core/utils/promo_code.dart';

part 'pos_account_event.dart';
part 'pos_account_state.dart';

class PosAccountBloc extends Bloc<PosAccountEvent, PosAccountState> {
  PosAccountBloc(this._repository, [this._localSource])
    : super(const PosAccountState()) {
    on<PosAccountDigitPressed>(_onDigitPressed);
    on<PosAccountBackspacePressed>(_onBackspacePressed);
    on<PosAccountSearchRequested>(_onSearchRequested);
    on<PosAccountQueryChanged>(_onQueryChanged);
    on<PosAccountRecentCustomersRequested>(_onRecentCustomersRequested);
    on<PosAccountMoreCustomersRequested>(_onMoreCustomersRequested);
    on<PosAccountCustomerSelected>(_onCustomerSelected);
    on<PosAccountSelectionCleared>(_onSelectionCleared);
    on<PosAccountCustomerRefreshRequested>(_onCustomerRefreshRequested);
    on<PosAccountNewCustomerRequested>(_onNewCustomerRequested);
    on<PosAccountChildAddRequested>(_onChildAddRequested);
    on<PosAccountCustomerNameUpdateRequested>(_onCustomerNameUpdateRequested);
    on<PosAccountChildNameUpdateRequested>(_onChildNameUpdateRequested);
    on<PosAccountTopupRequested>(_onTopupRequested);
    on<PosAccountParentQrRequested>(_onParentQrRequested);
    on<PosAccountParentQrAcknowledged>(_onParentQrAcknowledged);
    on<PosAccountPlansRequested>(_onPlansRequested);
    on<PosAccountPlanEntryRequested>(_onPlanEntryRequested);
    on<PosAccountEntryAcknowledged>(_onEntryAcknowledged);
    on<PosAccountProductsRequested>(_onProductsRequested);
    on<PosAccountPlayingRequested>(_onPlayingRequested);
    on<PosAccountActivePassesRequested>(_onActivePassesRequested);
    on<PosAccountCheckoutRequested>(_onCheckoutRequested);
    on<PosAccountConfigRequested>(_onConfigRequested);
    on<PosAccountDiscountsRequested>(_onDiscountsRequested);
    on<PosAccountPromoCodeSubmitted>(_onPromoCodeSubmitted);
    on<_PosAccountPromoCodeRechecked>(_onPromoCodeRechecked);
    on<PosAccountPromoCodeCleared>(
      (event, emit) =>
          emit(state.copyWith(clearPromo: true, clearPromoError: true)),
    );
  }

  final PosAccountRepository _repository;
  final LocalSource? _localSource;

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
        searchQuery: state.phoneDigits + event.digit,
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
        searchQuery: state.phoneDigits.substring(
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

  void _onQueryChanged(
    PosAccountQueryChanged event,
    Emitter<PosAccountState> emit,
  ) {
    _debounce?.cancel();
    final query = event.query.trimLeft();
    emit(state.copyWith(searchQuery: query));
    if (query.trim().length < 2) {
      emit(state.copyWith(results: const [], isSearching: false));
      return;
    }
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
    final query = state.searchQuery.trim();
    if (query.length < 2) return;
    emit(
      state.copyWith(
        isSearching: true,
        errorMessage: null,
        results: [],
        selectedCustomer: null,
        clearSelected: true,
      ),
    );
    final result = await _repository.searchCustomers(query);
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
    final cached = _readCustomerHistory();
    if (cached.isNotEmpty) {
      emit(state.copyWith(customerHistory: cached));
      await _refreshCachedHistory(cached, emit);
    }
    try {
      final result = await _repository.searchCustomers('');
      result.fold((failure) {}, (customers) {
        emit(
          state.copyWith(
            recentCustomers: customers,
            customerPage: 1,
            hasMoreCustomers: customers.length == 50,
          ),
        );
      });
    } catch (_) {
      // Best-effort — an unexpected response shape here must never surface
      // to the cashier or break the rest of the page.
    }
  }

  Future<void> _onMoreCustomersRequested(
    PosAccountMoreCustomersRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isLoadingMoreCustomers || !state.hasMoreCustomers) return;
    final nextPage = state.customerPage + 1;
    emit(state.copyWith(isLoadingMoreCustomers: true));
    final result = await _repository.searchCustomers('', page: nextPage);
    result.fold(
      (_) => emit(state.copyWith(isLoadingMoreCustomers: false)),
      (customers) => emit(
        state.copyWith(
          recentCustomers: [...state.recentCustomers, ...customers],
          customerPage: nextPage,
          hasMoreCustomers: customers.length == 50,
          isLoadingMoreCustomers: false,
        ),
      ),
    );
  }

  Future<void> _onCustomerSelected(
    PosAccountCustomerSelected event,
    Emitter<PosAccountState> emit,
  ) async {
    final history = [
      event.customer,
      ...state.customerHistory.where((item) => item.id != event.customer.id),
    ].take(10).toList();
    final keepPromo = _keepsPromoFor(event.customer);
    emit(
      state.copyWith(
        selectedCustomer: event.customer,
        customerHistory: history,
        playing: [],
        activePasses: [],
        clearPromo: !keepPromo,
        clearPromoError: !keepPromo,
      ),
    );
    unawaited(_persistCustomerHistory(history));
    add(const PosAccountPlayingRequested());
    add(const PosAccountActivePassesRequested());
    if (keepPromo && state.promo!.isBlogger) {
      add(const _PosAccountPromoCodeRechecked());
    }
  }

  /// Whether `state.promo` survives opening [customer]. A partner code
  /// belongs to exactly one customer — kept only when that customer is the
  /// one being opened (the scan-to-open path). A blogger code has no owner:
  /// one accepted on the search screen rides into whichever customer is
  /// opened (or created) next; switching from one customer to another
  /// drops it, like a partner code.
  bool _keepsPromoFor(Customer customer) {
    final promo = state.promo;
    if (promo == null) return false;
    if (promo.isBlogger) {
      final current = state.selectedCustomer;
      return current == null || current.id == customer.id;
    }
    return promo.owner?.id == customer.id;
  }

  List<Customer> _readCustomerHistory() {
    try {
      return (_localSource?.getCustomerSearchHistory() ?? const [])
          .map(_customerFromJson)
          .whereType<Customer>()
          .take(10)
          .toList(growable: false);
    } catch (_) {
      // A record written by an older app version must never break the page.
      return const [];
    }
  }

  Future<void> _persistCustomerHistory(List<Customer> customers) async {
    try {
      await _localSource?.setCustomerSearchHistory(
        customers.take(10).map(_customerToJson).toList(growable: false),
      );
    } catch (_) {
      // Search remains fully usable if local disk/Hive is unavailable.
    }
  }

  Future<void> _refreshCachedHistory(
    List<Customer> cached,
    Emitter<PosAccountState> emit,
  ) async {
    final refreshedById = <int, Customer>{};
    await Future.wait(
      cached.map((snapshot) async {
        final result = await _repository.searchCustomers(snapshot.phoneNumber);
        result.fold((_) {}, (customers) {
          for (final customer in customers) {
            if (customer.id == snapshot.id) {
              refreshedById[snapshot.id] = customer;
              break;
            }
          }
        });
      }),
    );
    if (refreshedById.isEmpty || emit.isDone) return;

    // Preserve any selection made while refresh calls were in flight and
    // only replace matching snapshots with their fresh server versions.
    final history = state.customerHistory
        .map((item) => refreshedById[item.id] ?? item)
        .toList(growable: false);
    emit(state.copyWith(customerHistory: history));
    await _persistCustomerHistory(history);
  }

  Map<String, dynamic> _customerToJson(Customer customer) => {
    'id': customer.id,
    'phoneNumber': customer.phoneNumber,
    'firstName': customer.firstName,
    'lastName': customer.lastName,
    'balance': customer.balance,
    'children': [
      for (final child in customer.children)
        {
          'id': child.id,
          'firstName': child.firstName,
          'lastName': child.lastName,
          'birthDate': child.birthDate.toIso8601String(),
        },
    ],
  };

  Customer? _customerFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final phone = json['phoneNumber'];
    final firstName = json['firstName'];
    final balance = json['balance'];
    final rawChildren = json['children'];
    if (id is! int ||
        phone is! String ||
        firstName is! String ||
        balance is! int ||
        rawChildren is! List) {
      return null;
    }
    final children = <Child>[];
    for (final raw in rawChildren.whereType<Map>()) {
      final child = Map<String, dynamic>.from(raw);
      final childId = child['id'];
      final childFirstName = child['firstName'];
      final birthDate = DateTime.tryParse(child['birthDate']?.toString() ?? '');
      if (childId is! String ||
          childFirstName is! String ||
          birthDate == null) {
        continue;
      }
      children.add(
        Child(
          id: childId,
          firstName: childFirstName,
          lastName: child['lastName'] as String?,
          birthDate: birthDate,
        ),
      );
    }
    return Customer(
      id: id,
      phoneNumber: phone,
      firstName: firstName,
      lastName: json['lastName'] as String?,
      balance: balance,
      children: children,
    );
  }

  void _onSelectionCleared(
    PosAccountSelectionCleared event,
    Emitter<PosAccountState> emit,
  ) {
    emit(
      PosAccountState(
        recentCustomers: state.recentCustomers,
        customerHistory: state.customerHistory,
        customerPage: state.customerPage,
        hasMoreCustomers: state.hasMoreCustomers,
        plans: state.plans,
        companionPriceUzs: state.companionPriceUzs,
        discounts: state.discounts,
        entryDiscounts: state.entryDiscounts,
      ),
    );
  }

  Future<void> _onCustomerRefreshRequested(
    PosAccountCustomerRefreshRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
    final current = state.selectedCustomer;
    if (current == null || state.isBusy) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.searchCustomers(current.phoneNumber);
    await result.fold(
      (failure) async => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (customers) async {
        Customer? refreshed;
        for (final customer in customers) {
          if (customer.id == current.id) {
            refreshed = customer;
            break;
          }
        }
        if (refreshed == null) {
          emit(state.copyWith(isBusy: false));
          return;
        }
        await _replaceCustomer(refreshed, emit);
        add(const PosAccountPlayingRequested());
        add(const PosAccountActivePassesRequested());
      },
    );
  }

  Future<void> _onNewCustomerRequested(
    PosAccountNewCustomerRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
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
        final keepPromo = _keepsPromoFor(customer);
        emit(
          state.copyWith(
            isBusy: false,
            selectedCustomer: customer,
            results: [customer],
            clearPromo: !keepPromo,
            clearPromoError: !keepPromo,
          ),
        );
        if (keepPromo && state.promo!.isBlogger) {
          add(const _PosAccountPromoCodeRechecked());
        }
      },
    );
  }

  Future<void> _onChildAddRequested(
    PosAccountChildAddRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
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

  Future<void> _onCustomerNameUpdateRequested(
    PosAccountCustomerNameUpdateRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
    final current = state.selectedCustomer;
    if (current == null || event.fullName.trim().isEmpty) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.updateCustomerName(
      customerId: current.id,
      fullName: event.fullName,
    );
    await result.fold(
      (failure) async => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (updated) async => _replaceCustomer(updated, emit),
    );
  }

  Future<void> _onChildNameUpdateRequested(
    PosAccountChildNameUpdateRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
    final current = state.selectedCustomer;
    if (current == null || event.fullName.trim().isEmpty) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.updateChildName(
      customerId: current.id,
      childId: event.childId,
      fullName: event.fullName,
    );
    await result.fold(
      (failure) async => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (child) async {
        final updated = current.copyWith(
          children: [
            for (final item in current.children)
              if (item.id == child.id) child else item,
          ],
        );
        await _replaceCustomer(updated, emit);
      },
    );
  }

  Future<void> _replaceCustomer(
    Customer updated,
    Emitter<PosAccountState> emit,
  ) async {
    List<Customer> replace(List<Customer> values) => [
      for (final item in values)
        if (item.id == updated.id) updated else item,
    ];
    final history = replace(state.customerHistory);
    emit(
      state.copyWith(
        isBusy: false,
        selectedCustomer: updated,
        results: replace(state.results),
        recentCustomers: replace(state.recentCustomers),
        customerHistory: history,
      ),
    );
    await _persistCustomerHistory(history);
  }

  Future<void> _onTopupRequested(
    PosAccountTopupRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    // Two taps in one frame both reached the repository, so a
    // balance top-up went through several times. The button is
    // disabled by `isBusy`, but only from the NEXT rebuild — the
    // guard has to live here, where the state is already set.
    if (state.isBusy) return;
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.topup(
      customerId: customer.id,
      amountUzs: event.amountUzs,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
      requestId: event.requestId,
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

  Future<void> _onParentQrRequested(
    PosAccountParentQrRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isBusy) return;
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.issueParentPass(customer.id);
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (pass) => emit(state.copyWith(isBusy: false, lastParentPass: pass)),
    );
  }

  void _onParentQrAcknowledged(
    PosAccountParentQrAcknowledged event,
    Emitter<PosAccountState> emit,
  ) {
    emit(state.copyWith(clearLastParentPass: true));
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
    if (state.isBusy) return;
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(state.copyWith(isBusy: true, errorMessage: null));
    final result = await _repository.issuePlanEntry(
      customerId: customer.id,
      planKey: event.planKey,
      childIds: event.childIds,
      replacePlan: event.replacePlan,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isBusy: false, errorMessage: _messageOf(failure)),
      ),
      (entryResult) {
        emit(state.copyWith(isBusy: false, lastEntryResult: entryResult));
        if (entryResult.entries.isNotEmpty) {
          // A confirmed switch changes both who is inside and the badges.
          add(const PosAccountPlayingRequested());
          add(const PosAccountActivePassesRequested());
        }
      },
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

  Future<void> _onActivePassesRequested(
    PosAccountActivePassesRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final customer = state.selectedCustomer;
    if (customer == null) return;
    final result = await _repository.listActivePasses(customer.id);
    // Best-effort like `playing`: a failed badge refresh keeps the previous
    // badges rather than erroring the page.
    result.fold((failure) {}, (passes) {
      if (state.selectedCustomer?.id == customer.id) {
        emit(state.copyWith(activePasses: passes));
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
    if (state.isBusy) return;
    final customer = state.selectedCustomer;
    if (customer == null) return;
    emit(
      state.copyWith(
        isBusy: true,
        errorMessage: null,
        errorCode: null,
        clearPromoError: true,
      ),
    );
    final result = await _repository.planEntryCheckout(
      customerId: customer.id,
      planKey: event.planKey,
      childIds: event.childIds,
      products: event.products,
      cashUzs: event.cashUzs,
      cardUzs: event.cardUzs,
      entryDiscounts: event.entryDiscounts,
      companions: event.companions,
      discountId: event.discountId,
      promoCode: event.promoCode,
    );
    result.fold(
      (failure) {
        final code = failure is ServerFailure ? failure.code : null;
        final promoError = code?.startsWith('PROMO_CODE_') ?? false;
        // The code itself was refused (used, expired, someone else's…):
        // drop it so the cashier rescans. A `PROMO_CODE_CHILD_*` refusal is
        // about the picked child — the code stays for another child.
        // Nothing was charged either way — the claim runs first.
        final promoRefused =
            promoError && !(code?.startsWith('PROMO_CODE_CHILD_') ?? false);
        emit(
          state.copyWith(
            isBusy: false,
            errorMessage: _messageOf(failure),
            errorCode: code,
            clearPromo: promoRefused,
            promoErrorCode: promoError ? code : null,
            promoErrorMessage: promoError ? _messageOf(failure) : null,
          ),
        );
        // The picked GOODS discount was disabled/deleted between fetch and
        // checkout — never silently charge full price. The widget clears
        // its local selection on this code; refetch so it has a fresh
        // catalog to re-pick from. (This is the only discount check that
        // can fail the WHOLE request — an entry discount is resolved
        // per-child instead, see the `failures` branch below.)
        if (code == 'DISCOUNT_NOT_AVAILABLE') {
          add(const PosAccountDiscountsRequested(force: true));
        }
      },
      (entryResult) {
        // `released` = no pass took the code (the promo child failed, e.g.
        // already had a pass today) and the server made it usable again —
        // keep it on screen for another child, with the reason under it.
        final promoOutcome = entryResult.promoCode;
        final promoReleased = promoOutcome != null && !promoOutcome.applied;
        final releaseReason = promoReleased
            ? entryResult.failures
                      .where((f) => f.childId == promoOutcome.childId)
                      .firstOrNull
                      ?.message ??
                  promoOutcome.reasonCode
            : null;
        emit(
          state.copyWith(
            isBusy: false,
            clearPromo: !promoReleased,
            clearPromoError: true,
            promoErrorCode: promoReleased ? 'PROMO_CODE_RELEASED' : null,
            promoErrorMessage: releaseReason,
            lastEntryResult: entryResult,
            selectedCustomer: entryResult.balance == null
                ? customer
                : customer.copyWith(balance: entryResult.balance!),
          ),
        );
        // A child's entry discount was unavailable/mismatched (per-child
        // failure, not a whole-request error) — refetch so the catalog is
        // fresh next time the cashier picks one.
        if (entryResult.failures.any(
          (f) =>
              f.code == 'DISCOUNT_NOT_AVAILABLE' ||
              f.code == 'GATE_PASS_DISCOUNT_CONFLICT',
        )) {
          add(
            const PosAccountDiscountsRequested(
              scope: DiscountScope.entry,
              force: true,
            ),
          );
        }
        // Fresh entries mean fresh inside-children rows and badges.
        add(const PosAccountPlayingRequested());
        add(const PosAccountActivePassesRequested());
        // The free parent sticker rides along with the checkout print —
        // never the other way around: a parent-pass hiccup must not undo
        // an already-settled checkout, so it only surfaces as an error.
        if (event.withParentQr && entryResult.entries.isNotEmpty) {
          add(const PosAccountParentQrRequested());
        }
      },
    );
  }

  Future<void> _onConfigRequested(
    PosAccountConfigRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final result = await _repository.fetchCompanionPriceUzs();
    // Best-effort like plans/products: on failure (or an older backend
    // without the endpoint) the compiled-in default price stays.
    result.fold((failure) {}, (price) {
      emit(state.copyWith(companionPriceUzs: price));
    });
  }

  Future<void> _onDiscountsRequested(
    PosAccountDiscountsRequested event,
    Emitter<PosAccountState> emit,
  ) async {
    final held = event.scope == DiscountScope.entry
        ? state.entryDiscounts
        : state.discounts;
    if (held.isNotEmpty && !event.force) return;
    final result = await _repository.fetchDiscounts(scope: event.scope);
    // Best-effort like plans/products/config: on failure (or an older
    // backend without the endpoint) the picker just stays hidden.
    result.fold((failure) {}, (discounts) {
      emit(
        event.scope == DiscountScope.entry
            ? state.copyWith(entryDiscounts: discounts)
            : state.copyWith(discounts: discounts),
      );
    });
  }

  Future<void> _onPromoCodeSubmitted(
    PosAccountPromoCodeSubmitted event,
    Emitter<PosAccountState> emit,
  ) async {
    if (state.isCheckingPromo) return;
    final code = normalizePromoCode(event.rawCode);
    // A re-scan of the code already applied is a no-op, not a new request.
    if (state.promo?.code == code) return;
    final kind = classifyPromoCode(code);
    if (kind == null) {
      // Rejected locally — a mistyped partner code (Luhn) or anything that
      // is neither shape never costs a request.
      emit(
        state.copyWith(
          clearPromoError: true,
          promoErrorCode: 'PROMO_CODE_INVALID_FORMAT',
        ),
      );
      return;
    }
    emit(state.copyWith(isCheckingPromo: true, clearPromoError: true));
    // A blogger code is once per customer — with one open, the server says
    // up front if they already redeemed it. Partner codes are matched to
    // their owner here instead (and the owner opened).
    final verified = await _repository.verifyPromoCode(
      code,
      customerId: kind == PromoCodeKind.blogger
          ? state.selectedCustomer?.id
          : null,
    );
    await verified.fold(
      (failure) async => emit(
        state.copyWith(
          isCheckingPromo: false,
          promoErrorCode: failure is ServerFailure ? failure.code : null,
          promoErrorMessage: _messageOf(failure),
        ),
      ),
      (check) async {
        if (check.isBlogger) {
          // No owner to open: applied to the open customer, or held on the
          // search screen until the cashier opens/creates one (then
          // re-checked for that customer — see _keepsPromoFor).
          emit(state.copyWith(isCheckingPromo: false, promo: check));
          return;
        }
        final owner = check.owner;
        if (owner == null) {
          emit(
            state.copyWith(
              isCheckingPromo: false,
              promoErrorCode: 'PROMO_CODE_WRONG_CUSTOMER',
            ),
          );
          return;
        }
        if (state.selectedCustomer?.id == owner.id) {
          emit(state.copyWith(isCheckingPromo: false, promo: check));
          return;
        }
        // The code is someone else's (or nobody is open yet): open its
        // owner — only their children can use it.
        final found = await _repository.searchCustomers(owner.phoneNumber);
        found.fold(
          (failure) => emit(
            state.copyWith(
              isCheckingPromo: false,
              promoErrorMessage: _messageOf(failure),
            ),
          ),
          (customers) {
            final match = customers
                .where((customer) => customer.id == owner.id)
                .firstOrNull;
            if (match == null) {
              emit(
                state.copyWith(
                  isCheckingPromo: false,
                  promoErrorCode: 'PROMO_CODE_OWNER_NOT_FOUND',
                ),
              );
              return;
            }
            emit(state.copyWith(isCheckingPromo: false, promo: check));
            add(PosAccountCustomerSelected(match));
          },
        );
      },
    );
  }

  /// Re-verifies a held blogger code for the customer it just rode into, so
  /// a code they already redeemed (`PROMO_CODE_ALREADY_USED_BY_CUSTOMER`) is
  /// refused right away rather than at the checkout.
  Future<void> _onPromoCodeRechecked(
    _PosAccountPromoCodeRechecked event,
    Emitter<PosAccountState> emit,
  ) async {
    final promo = state.promo;
    final customer = state.selectedCustomer;
    if (promo == null || !promo.isBlogger || customer == null) return;
    emit(state.copyWith(isCheckingPromo: true, clearPromoError: true));
    final verified = await _repository.verifyPromoCode(
      promo.code,
      customerId: customer.id,
    );
    // The cashier moved on (other customer, ✕, another code) meanwhile —
    // this answer is about a code/customer pair no longer on screen.
    if (state.selectedCustomer?.id != customer.id ||
        state.promo?.code != promo.code) {
      emit(state.copyWith(isCheckingPromo: false));
      return;
    }
    verified.fold((failure) {
      final code = failure is ServerFailure ? failure.code : null;
      // Refused by the server → dropped with the reason. A network hiccup
      // keeps it: the checkout claims it atomically and stays the judge.
      final refused = code?.startsWith('PROMO_CODE_') ?? false;
      emit(
        state.copyWith(
          isCheckingPromo: false,
          clearPromo: refused,
          promoErrorCode: code,
          promoErrorMessage: _messageOf(failure),
        ),
      );
    }, (check) => emit(state.copyWith(isCheckingPromo: false, promo: check)));
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => 'Xatolik yuz berdi',
    };
  }
}
