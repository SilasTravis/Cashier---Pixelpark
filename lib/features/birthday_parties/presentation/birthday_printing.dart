import 'package:flutter/material.dart';

import '../../../core/local_source/local_source.dart';
import '../../../core/printing/birthday_receipt.dart';
import '../../../core/printing/sale_receipt_printer.dart';
import '../../../generated/l10n.dart';
import '../../../injector_container.dart';
import '../domain/birthday_party.dart';

/// Prints a birthday receipt (the sale/booking receipt, or one payment's).
///
/// With no [payment] the party's latest payment is printed (right after a
/// sale that is the deposit/full payment just taken); a party without any
/// payment prints with no payment rows. [withItems] lists the included items
/// and is meant for the sale receipt only.
Future<void> printBirthdayReceipt(
  BuildContext context,
  BirthdayParty party, {
  BirthdayPartyPayment? payment,
  bool withItems = false,
}) async {
  try {
    final local = sl<LocalSource>();
    final shown = payment ?? _latest(party.payments);
    final printed = await SaleReceiptPrinter.printBirthdayDirect(
      BirthdayReceipt.fromParty(party, payment: shown, withItems: withItems),
      branchName: local.getBranchName() ?? party.branchName,
      cashierName: shown?.cashierUsername ?? local.getCashierFullName() ?? '',
      preferredPrinterName: local.getReceiptPrinterName(),
    );
    if (!printed && context.mounted) _fail(context);
  } catch (_) {
    if (context.mounted) _fail(context);
  }
}

BirthdayPartyPayment? _latest(List<BirthdayPartyPayment> payments) {
  if (payments.isEmpty) return null;
  return payments.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
}

void _fail(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(AppLocalization.of(context).receiptPrintFailed)),
  );
}
