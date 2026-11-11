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
/// and is meant for the sale receipt only. [refunds] (a cancel's new rows)
/// make it a refund receipt with one row per destination.
Future<void> printBirthdayReceipt(
  BuildContext context,
  BirthdayParty party, {
  BirthdayPartyPayment? payment,
  List<BirthdayPartyPayment> refunds = const [],
  bool withItems = false,
}) async {
  final printed = await printBirthdayReceiptDirect(
    party,
    payment: payment,
    refunds: refunds,
    withItems: withItems,
  );
  if (!printed && context.mounted) {
    _fail(
      ScaffoldMessenger.maybeOf(context),
      AppLocalization.of(context).receiptPrintFailed,
    );
  }
}

/// [printBirthdayReceipt] without any widget: true when it printed. It needs
/// no [BuildContext], so it still works after the caller's widget is gone.
Future<bool> printBirthdayReceiptDirect(
  BirthdayParty party, {
  BirthdayPartyPayment? payment,
  List<BirthdayPartyPayment> refunds = const [],
  bool withItems = false,
}) async {
  try {
    final local = sl<LocalSource>();
    final shown =
        payment ??
        (refunds.isNotEmpty ? refunds.last : _latest(party.payments));
    return await SaleReceiptPrinter.printBirthdayDirect(
      BirthdayReceipt.fromParty(
        party,
        payment: shown,
        refunds: refunds,
        withItems: withItems,
      ),
      branchName: local.getBranchName() ?? party.branchName,
      cashierName: shown?.cashierUsername ?? local.getCashierFullName() ?? '',
      preferredPrinterName: local.getReceiptPrinterName(),
    );
  } catch (_) {
    return false;
  }
}

/// A sale from the account panel: [openSheet] runs the sell sheet; once it
/// resolves with a party the booking receipt (with the included items) is
/// printed and [onSold] runs (the customer refresh).
///
/// The sheet lives on the root navigator, so the panel that opened it can be
/// disposed meanwhile (offline switch, shift refresh). Everything needed
/// afterwards — the messenger and the failure text — is captured up front, so
/// the money taken always gets its receipt. [print] is for tests.
Future<void> sellBirthdayAndPrint(
  BuildContext context, {
  required Future<BirthdayParty?> Function() openSheet,
  required VoidCallback onSold,
  Future<bool> Function(BirthdayParty party)? print,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final failText = AppLocalization.of(context).receiptPrintFailed;
  final party = await openSheet();
  if (party == null) return;
  final printed =
      await (print ?? (p) => printBirthdayReceiptDirect(p, withItems: true))(
        party,
      );
  if (!printed) _fail(messenger, failText);
  onSold();
}

BirthdayPartyPayment? _latest(List<BirthdayPartyPayment> payments) {
  if (payments.isEmpty) return null;
  return payments.reduce((a, b) => b.createdAt.isAfter(a.createdAt) ? b : a);
}

void _fail(ScaffoldMessengerState? messenger, String text) {
  if (messenger == null || !messenger.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(text)));
}
