import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../data/shift_repository_impl.dart';
import '../../domain/shift.dart';

part 'shift_event.dart';
part 'shift_state.dart';

/// Owns the cashier's current shift — every POS action (sale, top-up, gate
/// pass) is gated on `state.shift != null`.
class ShiftBloc extends Bloc<ShiftEvent, ShiftState> {
  ShiftBloc(this._repository) : super(const ShiftState()) {
    on<ShiftStarted>(_onStarted);
    on<ShiftOpenRequested>(_onOpenRequested);
    on<ShiftCloseRequested>(_onCloseRequested);
    on<ShiftRefreshed>(_onRefreshed);
  }

  final ShiftRepository _repository;

  Future<void> _onStarted(ShiftStarted event, Emitter<ShiftState> emit) async {
    await _load(emit);
  }

  Future<void> _onRefreshed(ShiftRefreshed event, Emitter<ShiftState> emit) async {
    await _load(emit, silent: true);
  }

  Future<void> _load(Emitter<ShiftState> emit, {bool silent = false}) async {
    if (!silent) emit(state.copyWith(isLoading: true));
    final result = await _repository.getCurrentShift();
    result.fold(
      (failure) {
        if (failure is ServerFailure && failure.code == 'SHIFT_NOT_OPEN') {
          emit(state.copyWith(isLoading: false, shift: null, clearShift: true));
        } else {
          emit(state.copyWith(isLoading: false, errorMessage: _messageOf(failure)));
        }
      },
      (shift) => emit(state.copyWith(isLoading: false, shift: shift, errorMessage: null)),
    );
  }

  Future<void> _onOpenRequested(ShiftOpenRequested event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    final result = await _repository.openShift(openingCashUzs: event.openingCashUzs);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: _messageOf(failure))),
      (shift) => emit(state.copyWith(isLoading: false, shift: shift)),
    );
  }

  Future<void> _onCloseRequested(ShiftCloseRequested event, Emitter<ShiftState> emit) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    final result = await _repository.closeShift(closingNote: event.closingNote);
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: _messageOf(failure))),
      (shift) => emit(
        state.copyWith(isLoading: false, shift: null, clearShift: true, lastClosed: shift),
      ),
    );
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => 'Xatolik yuz berdi',
    };
  }
}
