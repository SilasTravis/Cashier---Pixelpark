import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sales_history_repository.dart';
import '../../domain/sale_history.dart';

part 'sales_history_event.dart';
part 'sales_history_state.dart';

class SalesHistoryBloc extends Bloc<SalesHistoryEvent, SalesHistoryState> {
  SalesHistoryBloc(this.repository) : super(const SalesHistoryState()) {
    on<SalesHistoryStarted>(_load);
    on<SalesHistoryPeriodChanged>(_changePeriod);
    on<SalesHistoryPageChanged>(_changePage);
  }
  final SalesHistoryRepository repository;

  Future<void> _load(
    SalesHistoryStarted event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(state.period, state.page, emit);

  Future<void> _changePeriod(
    SalesHistoryPeriodChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(event.period, 1, emit);

  Future<void> _changePage(
    SalesHistoryPageChanged event,
    Emitter<SalesHistoryState> emit,
  ) => _fetch(state.period, event.page, emit);

  Future<void> _fetch(
    SaleHistoryPeriod period,
    int page,
    Emitter<SalesHistoryState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        period: period,
        page: page,
        clearError: true,
      ),
    );
    try {
      final result = await repository.load(period: period, page: page);
      emit(
        state.copyWith(
          isLoading: false,
          items: result.$1.items,
          total: result.$1.total,
          summary: result.$2,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(isLoading: false, error: repository.errorMessage(error)),
      );
    }
  }
}
