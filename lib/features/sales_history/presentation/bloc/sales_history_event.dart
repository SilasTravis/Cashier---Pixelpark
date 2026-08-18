part of 'sales_history_bloc.dart';

sealed class SalesHistoryEvent extends Equatable {
  const SalesHistoryEvent();
  @override
  List<Object?> get props => [];
}

class SalesHistoryStarted extends SalesHistoryEvent {
  const SalesHistoryStarted();
}

class SalesHistoryPeriodChanged extends SalesHistoryEvent {
  const SalesHistoryPeriodChanged(this.period);
  final SaleHistoryPeriod period;
  @override
  List<Object?> get props => [period];
}

class SalesHistoryPageChanged extends SalesHistoryEvent {
  const SalesHistoryPageChanged(this.page);
  final int page;
  @override
  List<Object?> get props => [page];
}
