part of 'shift_bloc.dart';

sealed class ShiftEvent extends Equatable {
  const ShiftEvent();

  @override
  List<Object?> get props => [];
}

class ShiftStarted extends ShiftEvent {
  const ShiftStarted();
}

class ShiftRefreshed extends ShiftEvent {
  const ShiftRefreshed();
}

class ShiftOpenRequested extends ShiftEvent {
  const ShiftOpenRequested({this.openingCashUzs});

  final int? openingCashUzs;

  @override
  List<Object?> get props => [openingCashUzs];
}

class ShiftCloseRequested extends ShiftEvent {
  const ShiftCloseRequested({this.closingNote});

  final String? closingNote;

  @override
  List<Object?> get props => [closingNote];
}
