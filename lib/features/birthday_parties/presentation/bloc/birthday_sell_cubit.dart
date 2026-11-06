import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../../domain/birthday_plan.dart';

String birthdayDateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class BirthdaySellState extends Equatable {
  const BirthdaySellState({
    this.loading = true,
    this.plans = const [],
    this.selectedPlanId,
    this.childCount = 0,
    this.extraChildren = 0,
    required this.partyDate,
    this.agreedOverrideUzs,
    this.deposit = false,
    this.depositUzs = 0,
    this.payFromBalance = true,
    this.method = PaymentMethod.cash,
    this.cashInput = '',
    this.cardInput = '',
    this.busy = false,
    this.errorCode,
    this.errorMessage,
    this.party,
  });

  final bool loading;
  final List<BirthdayPlan> plans;
  final String? selectedPlanId;

  /// Package size picked (0 = none yet).
  final int childCount;
  final int extraChildren;
  final DateTime partyDate;

  /// The cashier's own total; null = the list price.
  final int? agreedOverrideUzs;
  final bool deposit;
  final int depositUzs;
  final bool payFromBalance;
  final PaymentMethod method;
  final String cashInput;
  final String cardInput;
  final bool busy;
  final String? errorCode;
  final String? errorMessage;

  /// Set once the sale went through.
  final BirthdayParty? party;

  BirthdayPlan? get plan =>
      plans.where((p) => p.id == selectedPlanId).firstOrNull;

  BirthdayPlanSize? get size =>
      plan?.sizes.where((s) => s.childCount == childCount).firstOrNull;

  int get listPriceUzs =>
      size == null ? 0 : size!.priceUzs + extraChildren * size!.extraChildUzs;

  int get agreedUzs => agreedOverrideUzs ?? listPriceUzs;

  int get discountUzs =>
      agreedUzs < listPriceUzs ? listPriceUzs - agreedUzs : 0;

  BirthdayPayment payment(int balanceUzs) => BirthdayPayment.compute(
    dueUzs: agreedUzs,
    balanceUzs: balanceUzs,
    deposit: deposit,
    depositUzs: depositUzs,
    payFromBalance: payFromBalance,
    method: method,
    cashInput: cashInput,
    cardInput: cardInput,
  );

  bool canSubmit(int balanceUzs) =>
      !busy && size != null && agreedUzs > 0 && payment(balanceUzs).isValid;

  BirthdaySellState copyWith({
    bool? loading,
    List<BirthdayPlan>? plans,
    String? selectedPlanId,
    int? childCount,
    int? extraChildren,
    DateTime? partyDate,
    int? agreedOverrideUzs,
    bool clearOverride = false,
    bool? deposit,
    int? depositUzs,
    bool? payFromBalance,
    PaymentMethod? method,
    String? cashInput,
    String? cardInput,
    bool? busy,
    String? errorCode,
    String? errorMessage,
    bool clearError = false,
    BirthdayParty? party,
  }) => BirthdaySellState(
    loading: loading ?? this.loading,
    plans: plans ?? this.plans,
    selectedPlanId: selectedPlanId ?? this.selectedPlanId,
    childCount: childCount ?? this.childCount,
    extraChildren: extraChildren ?? this.extraChildren,
    partyDate: partyDate ?? this.partyDate,
    agreedOverrideUzs: clearOverride
        ? null
        : (agreedOverrideUzs ?? this.agreedOverrideUzs),
    deposit: deposit ?? this.deposit,
    depositUzs: depositUzs ?? this.depositUzs,
    payFromBalance: payFromBalance ?? this.payFromBalance,
    method: method ?? this.method,
    cashInput: cashInput ?? this.cashInput,
    cardInput: cardInput ?? this.cardInput,
    busy: busy ?? this.busy,
    errorCode: clearError ? null : (errorCode ?? this.errorCode),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    party: party ?? this.party,
  );

  @override
  List<Object?> get props => [
    loading,
    plans,
    selectedPlanId,
    childCount,
    extraChildren,
    partyDate,
    agreedOverrideUzs,
    deposit,
    depositUzs,
    payFromBalance,
    method,
    cashInput,
    cardInput,
    busy,
    errorCode,
    errorMessage,
    party,
  ];
}

/// State of the "Tug'ilgan kun sotish" sheet. The [requestId] is fixed for the
/// life of the sheet, so a retry after a timeout (same sheet, same tap) is the
/// same sale on the server and never books twice.
class BirthdaySellCubit extends Cubit<BirthdaySellState> {
  BirthdaySellCubit(this._repository, {DateTime? today})
    : requestId = const Uuid().v4(),
      super(BirthdaySellState(partyDate: today ?? DateTime.now()));

  final BirthdayPartiesRepository _repository;
  final String requestId;

  Future<void> load() async {
    try {
      final plans = await _repository.plans();
      emit(state.copyWith(loading: false, plans: plans, clearError: true));
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          loading: false,
          errorCode: e.code,
          errorMessage: e.message,
        ),
      );
    }
  }

  /// A new package / size / extra count re-prices the sale: the cashier's own
  /// total (and a deposit that no longer fits) start over.
  void selectPlan(String id) {
    final plan = state.plans.where((p) => p.id == id).firstOrNull;
    if (plan == null || id == state.selectedPlanId) return;
    final keep = plan.sizes.any((s) => s.childCount == state.childCount);
    emit(
      state.copyWith(
        selectedPlanId: id,
        childCount: keep ? state.childCount : 0,
        extraChildren: 0,
        clearOverride: true,
        clearError: true,
      ),
    );
  }

  void selectSize(int childCount) => childCount == state.childCount
      ? null
      : emit(
          state.copyWith(
            childCount: childCount,
            extraChildren: 0,
            clearOverride: true,
            clearError: true,
          ),
        );

  void addExtraChild() => emit(
    state.copyWith(
      extraChildren: state.extraChildren + 1,
      clearOverride: true,
      clearError: true,
    ),
  );

  void resetExtraChildren() => state.extraChildren == 0
      ? null
      : emit(
          state.copyWith(
            extraChildren: 0,
            clearOverride: true,
            clearError: true,
          ),
        );

  void setPartyDate(DateTime date) => emit(state.copyWith(partyDate: date));

  /// null (or the list price itself) = no override.
  void setAgreedPrice(int? uzs) => uzs == null || uzs == state.listPriceUzs
      ? emit(state.copyWith(clearOverride: true))
      : emit(state.copyWith(agreedOverrideUzs: uzs));

  /// Zaklad takes no balance by default; the cashier can switch it on.
  void setDeposit(bool deposit) =>
      emit(state.copyWith(deposit: deposit, payFromBalance: !deposit));

  void setDepositUzs(int uzs) => emit(state.copyWith(depositUzs: uzs));

  void setPayFromBalance(bool value) =>
      emit(state.copyWith(payFromBalance: value));

  void setMethod(PaymentMethod method) => emit(state.copyWith(method: method));

  void setSplitInputs({String? cash, String? card}) =>
      emit(state.copyWith(cashInput: cash, cardInput: card));

  Future<void> submit({
    required int customerId,
    required int balanceUzs,
  }) async {
    final plan = state.plan;
    if (plan == null || !state.canSubmit(balanceUzs)) return;
    final payment = state.payment(balanceUzs);
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final party = await _repository.sell(
        customerId: customerId,
        planId: plan.id,
        childCount: state.childCount,
        extraChildren: state.extraChildren,
        partyDate: birthdayDateString(state.partyDate),
        agreedPriceUzs: state.agreedUzs,
        money: payment.money,
        requestId: requestId,
      );
      emit(state.copyWith(busy: false, party: party));
    } on ServerException catch (e) {
      emit(
        state.copyWith(
          busy: false,
          errorCode: e.code ?? 'UNKNOWN',
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      // E.g. a malformed success body after the party was booked: unlock the
      // sheet; a retry reuses [requestId] and returns the existing party.
      emit(state.copyWith(busy: false, errorCode: 'UNKNOWN'));
    }
  }
}
