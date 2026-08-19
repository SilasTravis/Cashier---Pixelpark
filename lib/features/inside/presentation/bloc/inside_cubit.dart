import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/inside_repository.dart';
import '../../domain/inside_child.dart';

class InsideState extends Equatable {
  const InsideState({
    this.children = const [],
    this.loading = false,
    this.exitingVisitId,
    this.error,
    this.exitSucceeded = false,
  });

  final List<InsideChild> children;
  final bool loading;
  final String? exitingVisitId;
  final String? error;
  final bool exitSucceeded;

  InsideState copyWith({
    List<InsideChild>? children,
    bool? loading,
    String? exitingVisitId,
    bool clearExiting = false,
    String? error,
    bool clearError = false,
    bool? exitSucceeded,
  }) => InsideState(
    children: children ?? this.children,
    loading: loading ?? this.loading,
    exitingVisitId: clearExiting
        ? null
        : (exitingVisitId ?? this.exitingVisitId),
    error: clearError ? null : (error ?? this.error),
    exitSucceeded: exitSucceeded ?? this.exitSucceeded,
  );

  @override
  List<Object?> get props => [
    children,
    loading,
    exitingVisitId,
    error,
    exitSucceeded,
  ];
}

class InsideCubit extends Cubit<InsideState> {
  InsideCubit(this.repository) : super(const InsideState());
  final InsideRepository repository;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, exitSucceeded: false));
    try {
      emit(state.copyWith(children: await repository.list(), loading: false));
    } catch (error) {
      emit(state.copyWith(loading: false, error: _message(error)));
    }
  }

  Future<void> forceExit(String visitId) async {
    emit(
      state.copyWith(
        exitingVisitId: visitId,
        clearError: true,
        exitSucceeded: false,
      ),
    );
    try {
      await repository.forceExit(visitId);
      final children = state.children
          .where((item) => item.visitId != visitId)
          .toList();
      emit(
        state.copyWith(
          children: children,
          clearExiting: true,
          exitSucceeded: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(clearExiting: true, error: _message(error)));
    }
  }

  String _message(Object error) => switch (error) {
    ServerException(:final message) => message,
    _ => 'Unable to load children inside the park',
  };
}
