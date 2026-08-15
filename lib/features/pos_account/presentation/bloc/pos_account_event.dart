part of 'pos_account_bloc.dart';

sealed class PosAccountEvent extends Equatable {
  const PosAccountEvent();

  @override
  List<Object?> get props => [];
}

class PosAccountDigitPressed extends PosAccountEvent {
  const PosAccountDigitPressed(this.digit);

  final String digit;

  @override
  List<Object?> get props => [digit];
}

class PosAccountBackspacePressed extends PosAccountEvent {
  const PosAccountBackspacePressed();
}

class PosAccountSearchRequested extends PosAccountEvent {
  const PosAccountSearchRequested();
}

/// Fired once on page load — populates the browsable "latest customers"
/// list shown before the cashier has typed a phone number.
class PosAccountRecentCustomersRequested extends PosAccountEvent {
  const PosAccountRecentCustomersRequested();
}

class PosAccountCustomerSelected extends PosAccountEvent {
  const PosAccountCustomerSelected(this.customer);

  final Customer customer;

  @override
  List<Object?> get props => [customer];
}

class PosAccountSelectionCleared extends PosAccountEvent {
  const PosAccountSelectionCleared();
}

class PosAccountNewCustomerRequested extends PosAccountEvent {
  const PosAccountNewCustomerRequested(this.fullName);

  final String fullName;

  @override
  List<Object?> get props => [fullName];
}

class PosAccountChildAddRequested extends PosAccountEvent {
  const PosAccountChildAddRequested({
    required this.firstName,
    this.lastName,
    required this.birthDate,
  });

  final String firstName;
  final String? lastName;

  /// ISO `YYYY-MM-DD`.
  final String birthDate;

  @override
  List<Object?> get props => [firstName, lastName, birthDate];
}

class PosAccountTopupRequested extends PosAccountEvent {
  const PosAccountTopupRequested({
    required this.amountUzs,
    required this.cashUzs,
    required this.cardUzs,
  });

  final int amountUzs;
  final int cashUzs;
  final int cardUzs;

  @override
  List<Object?> get props => [amountUzs, cashUzs, cardUzs];
}

/// Fired once on page load, alongside [PosAccountRecentCustomersRequested]
/// — Standard/VIP tariffs.
class PosAccountPlansRequested extends PosAccountEvent {
  const PosAccountPlansRequested();
}

/// Starts a visit (Standard or VIP — whichever [planKey] is) for each
/// selected child — no payment involved, both are billed from the
/// customer's balance at exit. See `PosController.issuePlanEntry` on the
/// backend.
class PosAccountPlanEntryRequested extends PosAccountEvent {
  const PosAccountPlanEntryRequested({
    required this.planKey,
    required this.childIds,
  });

  final String planKey;
  final List<String> childIds;

  @override
  List<Object?> get props => [planKey, childIds];
}

class PosAccountEntryAcknowledged extends PosAccountEvent {
  const PosAccountEntryAcknowledged();
}

/// Fired once on page load — the ticket-type products (socks etc.) that can
/// be added to a plan-entry checkout.
class PosAccountProductsRequested extends PosAccountEvent {
  const PosAccountProductsRequested();
}

/// Refreshes the selected customer's currently-inside children (fired on
/// selection and after a checkout enters new children).
class PosAccountPlayingRequested extends PosAccountEvent {
  const PosAccountPlayingRequested();
}

/// The one-stop "to'lov + chop etish": optional collected cash/card (topped
/// onto the balance first), optional products (debited FROM the balance),
/// and the Standard/VIP day passes. The plan itself is billed at exit.
class PosAccountCheckoutRequested extends PosAccountEvent {
  const PosAccountCheckoutRequested({
    required this.planKey,
    required this.childIds,
    required this.products,
    required this.cashUzs,
    required this.cardUzs,
  });

  final String planKey;
  final List<String> childIds;
  final List<CheckoutLine> products;
  final int cashUzs;
  final int cardUzs;

  @override
  List<Object?> get props => [planKey, childIds, products, cashUzs, cardUzs];
}
