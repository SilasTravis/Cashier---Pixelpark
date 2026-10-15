import 'package:equatable/equatable.dart';

/// The Inside tab header for the cashier's branch (`GET /pos/inside/summary`).
class InsideSummary extends Equatable {
  const InsideSummary({
    required this.hasTurnstile,
    required this.vipSoldToday,
    required this.hourSoldToday,
    required this.standardSoldToday,
  });

  /// False = no turnstile at this branch: only 1 soat children are tracked
  /// inside (checked in when the ticket prints, out when the hour ends).
  final bool hasTurnstile;
  final int vipSoldToday;
  final int hourSoldToday;
  final int standardSoldToday;

  factory InsideSummary.fromJson(Map<String, dynamic> json) {
    final sold = Map<String, dynamic>.from(json['soldToday'] as Map? ?? {});
    return InsideSummary(
      hasTurnstile: json['hasTurnstile'] as bool? ?? true,
      vipSoldToday: sold['vip'] as int? ?? 0,
      hourSoldToday: sold['hour'] as int? ?? 0,
      standardSoldToday: sold['standard'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    hasTurnstile,
    vipSoldToday,
    hourSoldToday,
    standardSoldToday,
  ];
}
