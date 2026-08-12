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

class PosAccountProductsRequested extends PosAccountEvent {
  const PosAccountProductsRequested();
}

class PosAccountPassesRequested extends PosAccountEvent {
  const PosAccountPassesRequested({
    required this.productId,
    required this.childIds,
    required this.cashUzs,
    required this.cardUzs,
  });

  final String productId;
  final List<String> childIds;
  final int cashUzs;
  final int cardUzs;

  @override
  List<Object?> get props => [productId, childIds, cashUzs, cardUzs];
}

class PosAccountIssuedPassesAcknowledged extends PosAccountEvent {
  const PosAccountIssuedPassesAcknowledged();
}
