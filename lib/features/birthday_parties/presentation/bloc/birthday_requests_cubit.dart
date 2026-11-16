import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';

class BirthdayRequestsState extends Equatable {
  const BirthdayRequestsState({
    this.requests = const [],
    this.loading = false,
    this.error,
  });

  /// Parent requests waiting for this branch's cashier, oldest first.
  final List<BirthdayParty> requests;
  final bool loading;

  /// The last load failed; the cards already shown stay.
  final Object? error;

  @override
  List<Object?> get props => [requests, loading, error];
}

/// The open birthday requests of the branch. Lives at shell level: its count
/// is the Tadbirlar tab badge and its list is the Requests section. Polls
/// while alive; the timer dies with [close].
class BirthdayRequestsCubit extends Cubit<BirthdayRequestsState> {
  BirthdayRequestsCubit(
    this.repository, {
    Duration pollInterval = const Duration(seconds: 60),
  }) : super(const BirthdayRequestsState()) {
    _timer = Timer.periodic(pollInterval, (_) => load());
  }

  final BirthdayPartiesRepository repository;
  Timer? _timer;
  int _request = 0;

  Future<void> load() async {
    final request = ++_request;
    emit(BirthdayRequestsState(requests: state.requests, loading: true));
    try {
      final list = await repository.requests();
      if (request != _request || isClosed) return;
      emit(BirthdayRequestsState(requests: list));
    } catch (error) {
      if (request != _request || isClosed) return;
      emit(BirthdayRequestsState(requests: state.requests, error: error));
    }
  }

  /// Accepts a request for [time] (`HH:MM`); the card leaves the section.
  /// A failure is rethrown for the dialog to explain.
  Future<BirthdayParty> confirm(String id, String time) async {
    final party = await repository.confirm(id, time: time);
    remove(id);
    return party;
  }

  /// Declines a request; [requestId] stays the same across retries.
  Future<BirthdayParty> reject(
    String id,
    String reason, {
    required String requestId,
  }) async {
    final party = await repository.reject(
      id,
      reason: reason,
      requestId: requestId,
    );
    remove(id);
    return party;
  }

  /// Drops a card (decided here, or by another till).
  void remove(String id) {
    if (isClosed) return;
    emit(
      BirthdayRequestsState(
        requests: state.requests.where((p) => p.id != id).toList(),
        loading: state.loading,
        error: state.error,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
