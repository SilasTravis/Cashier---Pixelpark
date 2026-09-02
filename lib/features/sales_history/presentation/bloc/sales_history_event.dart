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

class SalesHistoryProductChanged extends SalesHistoryEvent {
  const SalesHistoryProductChanged(this.productId);
  final String? productId;
  @override
  List<Object?> get props => [productId];
}

class SalesHistoryDateRangeChanged extends SalesHistoryEvent {
  const SalesHistoryDateRangeChanged(this.from, this.to);
  final DateTime from;
  final DateTime to;
  @override
  List<Object?> get props => [from, to];
}

class SalesHistoryRefundRequested extends SalesHistoryEvent {
  const SalesHistoryRefundRequested({
    required this.saleId,
    required this.amountUzs,
    required this.method,
    required this.reason,
    required this.requestId,
  });

  final String saleId;
  final int amountUzs;
  final SaleRefundMethod method;
  final String reason;
  final String requestId;

  @override
  List<Object?> get props => [saleId, amountUzs, method, reason, requestId];
}
