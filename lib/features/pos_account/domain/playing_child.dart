import 'package:equatable/equatable.dart';

/// One currently-inside child of the selected customer, with the live
/// running cost — what an exit right now would charge. Shown so the cashier
/// can instantly answer a parent whose exit QR refused on a low balance,
/// and top the balance up on the spot.
class PlayingChild extends Equatable {
  const PlayingChild({
    required this.childId,
    required this.childName,
    required this.planName,
    required this.planKind,
    required this.enteredAt,
    required this.minutes,
    required this.dueUzs,
    this.discountId,
    this.discountName,
  });

  final String childId;
  final String childName;
  final String planName;

  /// `per_minute_tiers` or `flat_day` (VIP — due is the parked day price).
  final String planKind;
  final DateTime enteredAt;
  final int minutes;

  /// Already net of the pass's own entry discount, if any.
  final int dueUzs;

  /// The entry discount applied to this pass, if any — so the cashier can
  /// see WHY [dueUzs] is what it is instead of just a bare number.
  final String? discountId;
  final String? discountName;

  @override
  List<Object?> get props => [
    childId,
    childName,
    planName,
    planKind,
    enteredAt,
    minutes,
    dueUzs,
    discountId,
    discountName,
  ];
}
