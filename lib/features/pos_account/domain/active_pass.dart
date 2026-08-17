import 'package:equatable/equatable.dart';

/// One child's still-valid day pass — powers the "already on this plan
/// today" badge in the children list, so the cashier sees the existing
/// tariff BEFORE picking one and printing.
class ActivePass extends Equatable {
  const ActivePass({
    required this.childId,
    required this.planKey,
    required this.planLabel,
    required this.expiresAt,
    required this.dueTodayUzs,
  });

  final String childId;
  final String? planKey;
  final String planLabel;
  final DateTime expiresAt;

  /// The day's running cost on this pass — Standard: cumulative tier total
  /// over today's cycles, VIP: the flat day price. The number the cashier
  /// reads out when a parent asks "qancha bo'ldi?".
  final int dueTodayUzs;

  @override
  List<Object?> get props => [
    childId,
    planKey,
    planLabel,
    expiresAt,
    dueTodayUzs,
  ];
}
