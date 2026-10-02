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
    this.freeReason,
    this.discountId,
    this.discountName,
  });

  final String childId;
  final String? planKey;
  final String planLabel;
  final DateTime expiresAt;

  /// The day's running cost on this pass — Standard: cumulative tier total
  /// over today's cycles, VIP: the flat day price. The number the cashier
  /// reads out when a parent asks "qancha bo'ldi?".
  final int dueTodayUzs;

  /// LEGACY (read-only) — set only for a pre-discount-catalog free pass.
  final String? freeReason;

  /// The entry discount applied to this pass, if any — replaces [freeReason]
  /// for new passes. `discountName` is the badge label; `discountId` isn't
  /// shown but lets the picker pre-select the same discount on re-entry.
  final String? discountId;
  final String? discountName;

  @override
  List<Object?> get props => [
    childId,
    planKey,
    planLabel,
    expiresAt,
    dueTodayUzs,
    freeReason,
    discountId,
    discountName,
  ];
}
