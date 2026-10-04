import 'package:equatable/equatable.dart';

/// A Standard/VIP/1 soat tariff — not a POS product. `kind` decides how the
/// cashier's "Farzandlar" card behaves:
/// - `flatDay` (VIP) and `flatHour` (1 soat) are prepaid sales (pick, pay,
///   print). A 1 soat sticker admits for [KidsPlan.durationMinutes] from its
///   first door entry; exit is always free.
/// - `perMinuteTiers` (Standard) has no fixed price — it starts a metered
///   visit billed from the customer's balance at exit, no payment collected
///   at the register.
enum KidsPlanKind { perMinuteTiers, flatDay, flatHour }

class KidsPlan extends Equatable {
  const KidsPlan({
    required this.key,
    required this.name,
    required this.kind,
    required this.firstMinuteUzs,
    required this.secondMinuteUzs,
    required this.extraMinuteUzs,
    required this.flatUzs,
    this.durationMinutes,
  });

  final String key;
  final String name;
  final KidsPlanKind kind;
  final int? firstMinuteUzs;
  final int? secondMinuteUzs;
  final int? extraMinuteUzs;
  final int? flatUzs;

  /// 1 soat only: minutes the sticker admits from its first entry.
  final int? durationMinutes;

  /// Paid at the register (VIP, 1 soat) — the price must be on the balance
  /// before the sticker prints.
  bool get isPrepaid =>
      kind == KidsPlanKind.flatDay || kind == KidsPlanKind.flatHour;

  @override
  List<Object?> get props => [
    key,
    name,
    kind,
    firstMinuteUzs,
    secondMinuteUzs,
    extraMinuteUzs,
    flatUzs,
    durationMinutes,
  ];
}
