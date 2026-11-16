import '../../domain/birthday_party.dart';

/// What goes back to the parent when a request is rejected: the balance and
/// the online money still held (an online part already reversed to the card
/// is gone). Cash still owed was never paid, so it is not here.
int requestRefundUzs(BirthdayParty party) => party.payments
    .where((p) => p.kind == BirthdayPaymentKind.payment)
    .fold(
      0,
      (sum, p) =>
          sum +
          p.fromBalanceUzs +
          (p.onlineReversedAt == null ? p.onlineUzs : 0),
    );
