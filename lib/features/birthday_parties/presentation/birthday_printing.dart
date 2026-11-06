import 'package:flutter/widgets.dart';

import '../domain/birthday_party.dart';

/// Prints a birthday receipt (the sale/booking receipt, or one payment's).
///
/// C4 HOOK: a no-op until the printing task implements it. Callers (the
/// account panel after a sale) already call it with `withItems: true`.
Future<void> printBirthdayReceipt(
  BuildContext context,
  BirthdayParty party, {
  BirthdayPartyPayment? payment,
  bool withItems = false,
}) async {}
