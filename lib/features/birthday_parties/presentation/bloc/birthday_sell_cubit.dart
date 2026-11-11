import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../data/birthday_parties_repository.dart';
import '../birthday_recovery.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../../domain/birthday_plan.dart';
import '../../domain/birthday_wallet.dart';

/// The backend DTO caps extra children per party at 50.
const maxExtraChildren = 50;

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
    this.wallet,
    this.walletLoading = true,
    this.unclear = false,
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

  /// What of the balance may pay (real money) and the bonus that can't —
  /// read when the sheet opens and again after a balance refusal. Null while
  /// loading or when the lookup failed.
  final BirthdayWallet? wallet;
  final bool walletLoading;

  /// The wallet could not be read: "Balansdan yechish" is off, cash / card
  /// still work.
  bool get walletFailed => !walletLoading && wallet == null;

  /// The only part of the balance a birthday payment may spend.
  int get usableUzs => wallet?.usableUzs ?? 0;

  /// The last submit ended without a clear answer (timeout, dropped
  /// connection): the sale may or may not exist. The amounts are locked and
  /// only a retry with the same [BirthdaySellCubit.requestId] (or closing) is
  /// offered.
  final bool unclear;
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
      agreedUzs > 0 && agreedUzs < listPriceUzs ? listPriceUzs - agreedUzs : 0;

  BirthdayPayment get payment => BirthdayPayment.compute(
    dueUzs: agreedUzs,
    balanceUzs: usableUzs,
    deposit: deposit,
    depositUzs: depositUzs,
    payFromBalance: payFromBalance,
    method: method,
    cashInput: cashInput,
    cardInput: cardInput,
  );

  bool get canSubmit =>
      !busy &&
      !walletLoading &&
      size != null &&
      agreedUzs > 0 &&
      payment.isValid;

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
    BirthdayWallet? wallet,
    bool? walletLoading,
    bool? unclear,
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
    wallet: wallet ?? this.wallet,
    walletLoading: walletLoading ?? this.walletLoading,
    unclear: unclear ?? this.unclear,
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
    wallet,
    walletLoading,
    unclear,
    errorCode,
    errorMessage,
    party,
  ];
}

/// State of the "Tug'ilgan kun sotish" sheet. The [requestId] is fixed for the
/// life of the sheet, so a retry after a timeout (same sheet, same tap) is the
/// same sale on the server and never books twice.
class BirthdaySellCubit extends Cubit<BirthdaySellState> {
  BirthdaySellCubit(
    this._repository, {
    required this.customerId,
    DateTime? today,
    this.recheckDelay = birthdayRecheckDelay,
  }) : requestId = const Uuid().v4(),
       super(BirthdaySellState(partyDate: today ?? DateTime.now()));

  final BirthdayPartiesRepository _repository;

  /// Whose balance pays (its birthday wallet is read on [load]).
  final int customerId;
  final String requestId;

  /// Pause between the close re-checks of a sale that came back "not found".
  final Duration recheckDelay;

  /// Amounts are frozen once a submit ended unclearly.
  bool get _locked => state.unclear;

  Future<void> load() async {
    await Future.wait([_loadPlans(), _loadWallet()]);
  }

  /// The wallet, or null when it can't be read (never a silent 0).
  Future<BirthdayWallet?> _readWallet() async {
    try {
      return await _repository.wallet(customerId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadWallet() async {
    final wallet = await _readWallet();
    if (isClosed) return;
    emit(
      state.copyWith(
        wallet: wallet,
        walletLoading: false,
        // Nothing to take from (or unknown): the switch shows off.
        payFromBalance: wallet != null && wallet.usableUzs > 0
            ? state.payFromBalance
            : false,
      ),
    );
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _repository.plans();
      if (isClosed) return;
      emit(state.copyWith(loading: false, plans: plans, clearError: true));
    } on ServerException catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          loading: false,
          errorCode: e.code ?? 'UNKNOWN',
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      // Never leave the spinner hanging on an unexpected failure.
      if (isClosed) return;
      emit(state.copyWith(loading: false, errorCode: 'UNKNOWN'));
    }
  }

  /// A new package / size / extra count re-prices the sale: the cashier's own
  /// total (and a deposit that no longer fits) start over.
  void selectPlan(String id) {
    final plan = state.plans.where((p) => p.id == id).firstOrNull;
    if (_locked || plan == null || id == state.selectedPlanId) return;
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

  void selectSize(int childCount) => _locked || childCount == state.childCount
      ? null
      : emit(
          state.copyWith(
            childCount: childCount,
            extraChildren: 0,
            clearOverride: true,
            clearError: true,
          ),
        );

  void addExtraChild() => _locked || state.extraChildren >= maxExtraChildren
      ? null
      : emit(
          state.copyWith(
            extraChildren: state.extraChildren + 1,
            clearOverride: true,
            clearError: true,
          ),
        );

  /// The sale-time minus: never below 0 (the package size already counts the
  /// booked children).
  void removeExtraChild() => _locked || state.extraChildren <= 0
      ? null
      : emit(
          state.copyWith(
            extraChildren: state.extraChildren - 1,
            clearOverride: true,
            clearError: true,
          ),
        );

  void resetExtraChildren() => _locked || state.extraChildren == 0
      ? null
      : emit(
          state.copyWith(
            extraChildren: 0,
            clearOverride: true,
            clearError: true,
          ),
        );

  void setPartyDate(DateTime date) =>
      _locked ? null : emit(state.copyWith(partyDate: date));

  /// The list price itself = no override. An emptied field is an override of
  /// 0 (nothing to submit) — it must not snap back to the list price while
  /// the cashier is still typing; only re-pricing rewrites the field.
  void setAgreedPrice(int? uzs) {
    if (_locked) return;
    uzs == state.listPriceUzs
        ? emit(state.copyWith(clearOverride: true))
        : emit(state.copyWith(agreedOverrideUzs: uzs ?? 0));
  }

  /// Zaklad takes no balance by default; the cashier can switch it on. Full
  /// payment starts from the balance when there is real money to take.
  void setDeposit(bool deposit) => _locked || deposit == state.deposit
      ? null
      : emit(
          state.copyWith(
            deposit: deposit,
            payFromBalance: !deposit && state.usableUzs > 0,
          ),
        );

  void setDepositUzs(int uzs) =>
      _locked ? null : emit(state.copyWith(depositUzs: uzs));

  /// Only real money can be switched on: no usable balance keeps it off.
  void setPayFromBalance(bool value) => _locked
      ? null
      : emit(state.copyWith(payFromBalance: value && state.usableUzs > 0));

  void setMethod(PaymentMethod method) =>
      _locked ? null : emit(state.copyWith(method: method));

  void setSplitInputs({String? cash, String? card}) =>
      _locked ? null : emit(state.copyWith(cashInput: cash, cardInput: card));

  /// The party this sheet's requestId booked, null when the server has none
  /// (or cannot be reached): the party id IS the sell requestId.
  Future<BirthdayParty?> bookedParty() => refetchParty(_repository, requestId);

  /// Closing after an unclear failure: the sale may have gone through, so the
  /// caller must learn about it (receipt, customer refresh).
  ///
  /// Null when nothing was unclear (just close). [PartyUnreachable] means the
  /// server could not be asked: the sheet must stay locked, not close. A
  /// "not found" is re-checked first ([lookupPartySettled]): the lost request
  /// may still be committing.
  Future<PartyLookup?> resolveOnClose() async {
    if (!state.unclear) return null;
    emit(state.copyWith(busy: true));
    final lookup = await lookupPartySettled(
      _repository,
      requestId,
      delay: recheckDelay,
    );
    if (!isClosed) emit(state.copyWith(busy: false));
    return lookup;
  }

  Future<void> submit({required int customerId}) async {
    final plan = state.plan;
    if (plan == null || !state.canSubmit) return;
    final payment = state.payment;
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
    } catch (error) {
      final code = error is ServerException ? error.code : null;
      final message = error is ServerException ? error.message : null;
      if (isUnclearFailure(error)) {
        // The response may have been lost after the server booked it.
        final booked = await bookedParty();
        if (isClosed) return;
        if (booked != null) {
          emit(state.copyWith(busy: false, party: booked));
          return;
        }
        emit(
          state.copyWith(
            busy: false,
            unclear: true,
            errorCode: code ?? 'UNKNOWN',
            errorMessage: message,
          ),
        );
        return;
      }
      // A clean refusal — also of a retry: a sale already booked under this
      // requestId would have replayed as a success — so nothing was booked
      // and the sheet is editable again.
      emit(
        state.copyWith(
          busy: false,
          unclear: false,
          errorCode: code ?? 'UNKNOWN',
          errorMessage: message,
        ),
      );
      if (code == 'BIRTHDAY_BALANCE_INSUFFICIENT') await _refreshWallet();
    }
  }

  /// After a balance refusal the usable amount shown was stale: re-read it.
  /// A failed re-read keeps the last known wallet.
  Future<void> _refreshWallet() async {
    final wallet = await _readWallet();
    // A locked (unclear) split must not be recomputed behind the cashier.
    if (wallet == null || isClosed || _locked) return;
    emit(
      state.copyWith(
        wallet: wallet,
        payFromBalance: state.payFromBalance && wallet.usableUzs > 0,
      ),
    );
  }
}
