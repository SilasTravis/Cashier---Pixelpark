import 'package:equatable/equatable.dart';

/// A Standard/VIP tariff — the same plan a parent picks in the mobile app
/// before checking in, not a POS product. `kind` decides how the cashier's
/// "Farzandlar" card behaves: `flatDay` is a normal prepaid sale (pick,
/// pay, print), `perMinuteTiers` has no fixed price — it starts a metered
/// visit billed from the customer's balance at exit, no payment collected
/// at the register.
enum KidsPlanKind { perMinuteTiers, flatDay }

class KidsPlan extends Equatable {
  const KidsPlan({
    required this.key,
    required this.name,
    required this.kind,
    required this.firstMinuteUzs,
    required this.secondMinuteUzs,
    required this.extraMinuteUzs,
    required this.flatUzs,
  });

  final String key;
  final String name;
  final KidsPlanKind kind;
  final int? firstMinuteUzs;
  final int? secondMinuteUzs;
  final int? extraMinuteUzs;
  final int? flatUzs;

  @override
  List<Object?> get props => [
    key,
    name,
    kind,
    firstMinuteUzs,
    secondMinuteUzs,
    extraMinuteUzs,
    flatUzs,
  ];
}
