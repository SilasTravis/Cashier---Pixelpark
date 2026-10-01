import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/market_repository.dart';
import '../../domain/market_order.dart';

class MarketIncomingState extends Equatable {
  const MarketIncomingState({
    this.orders = const [],
    this.loading = false,
    this.receivingId,
    this.error,
    this.errorSeq = 0,
    this.receivedSeq = 0,
  });

  final List<MarketOrder> orders;
  final bool loading;
  final String? receivingId;

  /// The server's localized message; '' = no message (the UI falls back to a
  /// generic one).
  final String? error;

  /// Bumped per failure / per received parcel so the page's snackbar fires
  /// even when the same message repeats.
  final int errorSeq;
  final int receivedSeq;

  MarketIncomingState copyWith({
    List<MarketOrder>? orders,
    bool? loading,
    String? receivingId,
    bool clearReceiving = false,
    String? error,
    int? errorSeq,
    int? receivedSeq,
  }) => MarketIncomingState(
    orders: orders ?? this.orders,
    loading: loading ?? this.loading,
    receivingId: clearReceiving ? null : (receivingId ?? this.receivingId),
    error: error ?? this.error,
    errorSeq: errorSeq ?? this.errorSeq,
    receivedSeq: receivedSeq ?? this.receivedSeq,
  );

  @override
  List<Object?> get props => [
    orders,
    loading,
    receivingId,
    error,
    errorSeq,
    receivedSeq,
  ];
}

/// "Kelayotgan": parcels on their way to this park.
class MarketIncomingCubit extends Cubit<MarketIncomingState> {
  MarketIncomingCubit(this.repository) : super(const MarketIncomingState());
  final MarketRepository repository;

  Future<void> load() async {
    if (state.loading) return;
    emit(state.copyWith(loading: true));
    try {
      emit(state.copyWith(orders: await repository.incoming(), loading: false));
    } catch (error) {
      _fail(state.copyWith(loading: false), error);
    }
  }

  Future<void> receive(String orderId) async {
    if (state.receivingId != null) return;
    emit(state.copyWith(receivingId: orderId));
    try {
      final received = await repository.receive(orderId);
      emit(
        state.copyWith(
          clearReceiving: true,
          receivedSeq: state.receivedSeq + 1,
          // at_branch is no longer "incoming" — it waits for the parent now.
          orders: [
            for (final order in state.orders)
              if (order.id != orderId)
                order
              else if (received.status == MarketOrderStatus.handedOver ||
                  received.status == MarketOrderStatus.confirmed)
                received,
          ],
        ),
      );
    } catch (error) {
      _fail(state.copyWith(clearReceiving: true), error);
    }
  }

  void _fail(MarketIncomingState base, Object error) => emit(
    base.copyWith(
      error: error is ServerException ? error.message : '',
      errorSeq: base.errorSeq + 1,
    ),
  );
}
