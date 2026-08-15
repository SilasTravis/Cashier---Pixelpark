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
  });

  final String childId;
  final String childName;
  final String planName;

  /// `per_minute_tiers` or `flat_day` (VIP — due is the parked day price).
  final String planKind;
  final DateTime enteredAt;
  final int minutes;
  final int dueUzs;

  @override
  List<Object?> get props => [
    childId,
    childName,
    planName,
    planKind,
    enteredAt,
    minutes,
    dueUzs,
  ];
}
