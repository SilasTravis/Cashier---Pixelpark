import 'package:equatable/equatable.dart';

class ShiftVisit extends Equatable {
  const ShiftVisit({
    required this.id,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.enteredAt,
    required this.exitedAt,
    required this.minutes,
    required this.amountUzs,
    required this.forceClosed,
  });

  final String id;
  final String childName;
  final String parentName;
  final String parentPhone;
  final DateTime enteredAt;
  final DateTime? exitedAt;
  final int? minutes;
  final int amountUzs;
  final bool forceClosed;

  @override
  List<Object?> get props => [id, exitedAt, amountUzs, forceClosed];
}

class ShiftVisitPage {
  const ShiftVisitPage({
    required this.items,
    required this.total,
    required this.entries,
    required this.exits,
    required this.inside,
  });

  final List<ShiftVisit> items;
  final int total;
  final int entries;
  final int exits;
  final int inside;
}
