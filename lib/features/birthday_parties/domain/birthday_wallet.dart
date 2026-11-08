import 'package:equatable/equatable.dart';

/// What of a customer's balance may pay for a birthday pack
/// (`GET /v1/pos/customers/:id/birthday-wallet`). Only real money is
/// [usableUzs]; bonus / cashback money ([bonusUzs]) can't pay for a party.
class BirthdayWallet extends Equatable {
  const BirthdayWallet({
    required this.balanceUzs,
    required this.usableUzs,
    required this.bonusUzs,
  });

  /// The whole balance (real + bonus).
  final int balanceUzs;

  /// The real-money part — the only part a birthday payment may spend.
  final int usableUzs;

  /// Bonus / cashback money — shown, never spent on a party.
  final int bonusUzs;

  factory BirthdayWallet.fromJson(Map<String, dynamic> json) => BirthdayWallet(
    balanceUzs: (json['balanceUzs'] as num?)?.toInt() ?? 0,
    usableUzs: (json['usableUzs'] as num?)?.toInt() ?? 0,
    bonusUzs: (json['bonusUzs'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [balanceUzs, usableUzs, bonusUzs];
}
