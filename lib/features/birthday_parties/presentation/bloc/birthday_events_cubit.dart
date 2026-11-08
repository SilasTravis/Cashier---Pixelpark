import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';

class BirthdayEventsState extends Equatable {
  const BirthdayEventsState({
    this.status = BirthdayPartyStatus.booked,
    this.parties = const [],
    this.loading = false,
    this.error,
    this.failed = false,
  });

  final BirthdayPartyStatus status;
  final List<BirthdayParty> parties;
  final bool loading;

  /// The server's own message when it sent one.
  final String? error;

  /// The last load failed ([error] null = show the generic localized text).
  final bool failed;

  @override
  List<Object?> get props => [status, parties, loading, error, failed];
}

class BirthdayEventsCubit extends Cubit<BirthdayEventsState> {
  BirthdayEventsCubit(this.repository) : super(const BirthdayEventsState());
  final BirthdayPartiesRepository repository;

  int _request = 0;

  Future<void> load(BirthdayPartyStatus status) async {
    final request = ++_request;
    emit(
      BirthdayEventsState(
        status: status,
        parties: status == state.status ? state.parties : const [],
        loading: true,
      ),
    );
    try {
      final parties = await repository.list(status);
      if (request != _request || isClosed) return;
      emit(BirthdayEventsState(status: status, parties: parties));
    } catch (error) {
      if (request != _request || isClosed) return;
      emit(
        BirthdayEventsState(
          status: status,
          parties: state.parties,
          error: error is ServerException ? error.message : null,
          failed: true,
        ),
      );
    }
  }

  Future<void> refresh() => load(state.status);

  /// After a detail action: swap the party in place, or drop it when it no
  /// longer belongs to this segment (completed / cancelled).
  void replace(BirthdayParty party) {
    if (isClosed) return;
    final list = state.parties
        .map((p) => p.id == party.id ? party : p)
        .where((p) => p.status == state.status)
        .toList();
    emit(
      BirthdayEventsState(
        status: state.status,
        parties: list,
        loading: state.loading,
        error: state.error,
        failed: state.failed,
      ),
    );
  }
}
