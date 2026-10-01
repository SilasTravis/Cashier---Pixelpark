import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/market_repository.dart';

class MarketStatusState extends Equatable {
  const MarketStatusState({this.showTab = false, this.openOrders = 0});

  /// Hidden until the server says otherwise, so a terminal on a backend
  /// without the market (or with it switched off) looks exactly as before.
  final bool showTab;
  final int openOrders;

  @override
  List<Object?> get props => [showTab, openOrders];
}

/// Shell-scoped: decides whether the sidebar shows the Pixel Market tab and
/// its open-parcel badge. Re-checked on start, every [interval] and when the
/// terminal comes back online.
class MarketStatusCubit extends Cubit<MarketStatusState> {
  MarketStatusCubit(
    this.repository, {
    this.interval = const Duration(minutes: 3),
  }) : super(const MarketStatusState());

  final MarketRepository repository;
  final Duration interval;
  Timer? _timer;

  void start() {
    unawaited(refresh());
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(refresh()));
  }

  Future<void> refresh() async {
    final status = await repository.status();
    if (isClosed) return;
    emit(
      MarketStatusState(showTab: status.showTab, openOrders: status.openOrders),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
