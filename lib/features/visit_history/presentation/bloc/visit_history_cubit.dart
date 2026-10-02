import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/visit_history_repository.dart';
import '../../domain/shift_visit.dart';

class VisitHistoryState extends Equatable {
  const VisitHistoryState({
    this.items = const [],
    this.total = 0,
    this.entries = 0,
    this.exits = 0,
    this.inside = 0,
    this.page = 1,
    this.status = 'all',
    this.search = '',
    this.loading = false,
    this.error,
  });

  static const pageSize = 20;
  final List<ShiftVisit> items;
  final int total;
  final int entries;
  final int exits;
  final int inside;
  final int page;
  final String status;
  final String search;
  final bool loading;
  final String? error;
  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();

  VisitHistoryState copyWith({
    List<ShiftVisit>? items,
    int? total,
    int? entries,
    int? exits,
    int? inside,
    int? page,
    String? status,
    String? search,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => VisitHistoryState(
    items: items ?? this.items,
    total: total ?? this.total,
    entries: entries ?? this.entries,
    exits: exits ?? this.exits,
    inside: inside ?? this.inside,
    page: page ?? this.page,
    status: status ?? this.status,
    search: search ?? this.search,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    items,
    total,
    entries,
    exits,
    inside,
    page,
    status,
    search,
    loading,
    error,
  ];
}

class VisitHistoryCubit extends Cubit<VisitHistoryState> {
  VisitHistoryCubit(this.repository) : super(const VisitHistoryState());
  final VisitHistoryRepository repository;

  Future<void> load({int? page, String? status, String? search}) async {
    final targetPage = page ?? state.page;
    final targetStatus = status ?? state.status;
    final targetSearch = search ?? state.search;
    emit(
      state.copyWith(
        loading: true,
        page: targetPage,
        status: targetStatus,
        search: targetSearch,
        clearError: true,
      ),
    );
    try {
      final result = await repository.list(
        page: targetPage,
        limit: VisitHistoryState.pageSize,
        status: targetStatus,
        search: targetSearch,
      );
      emit(
        state.copyWith(
          items: result.items,
          total: result.total,
          entries: result.entries,
          exits: result.exits,
          inside: result.inside,
          loading: false,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          loading: false,
          error: error is ServerException ? error.message : error.toString(),
        ),
      );
    }
  }
}
