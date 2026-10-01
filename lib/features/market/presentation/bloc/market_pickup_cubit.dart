import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/market_repository.dart';
import '../../domain/market_order.dart';

/// Local refusal: the scan/typing wasn't 6 digits — no request was made.
const marketCodeInvalid = 'MARKET_CODE_INVALID';

class MarketPickupState extends Equatable {
  const MarketPickupState({
    this.code,
    this.orders = const [],
    this.loading = false,
    this.receivingId,
    this.handingOver = false,
    this.handed = const [],
    this.errorCode,
    this.errorMessage,
  });

  /// The code whose orders are on screen.
  final String? code;

  /// Open orders of [code] still to hand over (handed_over / at_branch).
  final List<MarketOrder> orders;
  final bool loading;
  final String? receivingId;
  final bool handingOver;

  /// The orders the last "Topshirildi" handed to the parent; non-empty =
  /// show the success panel.
  final List<MarketOrder> handed;

  /// A backend `code`, or [marketCodeInvalid]; the UI localizes the local one
  /// and shows [errorMessage] (already localized by the server) otherwise.
  final String? errorCode;
  final String? errorMessage;

  bool get hasError => errorCode != null || errorMessage != null;

  bool get busy => loading || handingOver || receivingId != null;

  bool get canHandOver =>
      orders.any((order) => order.status == MarketOrderStatus.atBranch);

  bool get hasUnreceived =>
      orders.any((order) => order.status == MarketOrderStatus.handedOver);

  MarketPickupState copyWith({
    String? code,
    List<MarketOrder>? orders,
    bool? loading,
    String? receivingId,
    bool clearReceiving = false,
    bool? handingOver,
    List<MarketOrder>? handed,
  }) => MarketPickupState(
    code: code ?? this.code,
    orders: orders ?? this.orders,
    loading: loading ?? this.loading,
    receivingId: clearReceiving ? null : (receivingId ?? this.receivingId),
    handingOver: handingOver ?? this.handingOver,
    handed: handed ?? this.handed,
    // Every transition clears the previous error; failures set it anew.
  );

  MarketPickupState withError(Object error) => MarketPickupState(
    code: code,
    orders: orders,
    handed: handed,
    errorCode: error is ServerException ? error.code : null,
    errorMessage: error is ServerException ? error.message : null,
  );

  @override
  List<Object?> get props => [
    code,
    orders,
    loading,
    receivingId,
    handingOver,
    handed,
    errorCode,
    errorMessage,
  ];
}

/// "Berish": look a parent's pickup code up, receive any parcel that's still
/// marked as on its way, then hand everything at the park over at once.
class MarketPickupCubit extends Cubit<MarketPickupState> {
  MarketPickupCubit(this.repository) : super(const MarketPickupState());
  final MarketRepository repository;

  Future<void> lookup(String raw) async {
    if (state.busy) return;
    final code = normalizePickupCode(raw);
    if (code == null) {
      emit(const MarketPickupState(errorCode: marketCodeInvalid));
      return;
    }
    // A new scan replaces whatever was on screen, success panel included.
    emit(MarketPickupState(code: code, loading: true));
    try {
      final orders = await repository.pickup(code);
      emit(MarketPickupState(code: code, orders: orders));
    } catch (error) {
      emit(const MarketPickupState().withError(error));
    }
  }

  Future<void> receive(String orderId) async {
    if (state.busy) return;
    emit(state.copyWith(receivingId: orderId, handed: const []));
    try {
      final received = await repository.receive(orderId);
      emit(
        state.copyWith(
          clearReceiving: true,
          orders: [
            for (final order in state.orders)
              order.id == orderId
                  ? order.copyWith(status: received.status)
                  : order,
          ],
        ),
      );
    } catch (error) {
      emit(state.copyWith(clearReceiving: true).withError(error));
    }
  }

  Future<void> handOver() async {
    final code = state.code;
    if (code == null || state.busy || !state.canHandOver) return;
    emit(state.copyWith(handingOver: true, handed: const []));
    try {
      final handed = await repository.handOver(code);
      final handedIds = {for (final order in handed) order.id};
      emit(
        MarketPickupState(
          code: code,
          handed: handed,
          // Only at_branch orders are handed over; anything not received
          // yet stays on screen.
          orders: [
            for (final order in state.orders)
              if (!handedIds.contains(order.id)) order,
          ],
        ),
      );
    } catch (error) {
      emit(state.copyWith(handingOver: false).withError(error));
    }
  }

  void reset() => emit(const MarketPickupState());
}
