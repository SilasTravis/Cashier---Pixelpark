import 'package:equatable/equatable.dart';

import '../../shift/domain/shift.dart';

/// A shift the cashier opened while the terminal was offline. The server
/// creates it first on sync; [serverShiftId] is its real id afterwards.
class OfflineShift extends Equatable {
  const OfflineShift({
    required this.offlineRequestId,
    required this.cashierId,
    required this.openedAt,
    this.openingCashUzs,
    this.serverShiftId,
  });

  final String offlineRequestId;
  final String cashierId;
  final DateTime openedAt;
  final int? openingCashUzs;
  final String? serverShiftId;

  bool get isSynced => serverShiftId != null;

  /// How the shell shows it offline. The `offline:` prefix keeps it from
  /// ever being mistaken for a server id.
  Shift toShift() => Shift(
    id: 'offline:$offlineRequestId',
    openedAt: openedAt,
    closedAt: null,
    status: 'open',
    totals: ShiftTotals.zero,
  );

  OfflineShift withServerShiftId(String id) => OfflineShift(
    offlineRequestId: offlineRequestId,
    cashierId: cashierId,
    openedAt: openedAt,
    openingCashUzs: openingCashUzs,
    serverShiftId: id,
  );

  Map<String, dynamic> toSyncJson() => {
    'offlineRequestId': offlineRequestId,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'openingCashUzs': ?openingCashUzs,
  };

  Map<String, dynamic> toJson() => {
    'offlineRequestId': offlineRequestId,
    'cashierId': cashierId,
    'openedAt': openedAt.toUtc().toIso8601String(),
    'openingCashUzs': openingCashUzs,
    'serverShiftId': serverShiftId,
  };

  factory OfflineShift.fromJson(Map<String, dynamic> json) => OfflineShift(
    offlineRequestId: json['offlineRequestId'] as String,
    cashierId: json['cashierId'] as String,
    openedAt: DateTime.parse(json['openedAt'] as String),
    openingCashUzs: json['openingCashUzs'] as int?,
    serverShiftId: json['serverShiftId'] as String?,
  );

  @override
  List<Object?> get props => [
    offlineRequestId,
    cashierId,
    openedAt,
    openingCashUzs,
    serverShiftId,
  ];
}
