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
  });

  final String childId;
  final String? planKey;
  final String planLabel;
  final DateTime expiresAt;

  @override
  List<Object?> get props => [childId, planKey, planLabel, expiresAt];
}
