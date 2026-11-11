import 'package:flutter/material.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/printing/sale_receipt_printer.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../domain/pos_entry.dart';
import '../../domain/subscription.dart';
import 'plan_entry_printing.dart';
import 'subscription_sell_dialog.dart';

/// After a subscription sale: the 80 mm receipt always prints (with the
/// KESHBEK + QR block when the server minted cashback), then today's sticker
/// when the sale also issued a pass — through the same label printer and
/// ticket fallback as every other gate pass. A failed entry never undoes
/// the sale; it only shows why.
Future<void> printSubscriptionSale(
  BuildContext context,
  SubscriptionSellOutcome outcome,
) async {
  final l10n = AppLocalization.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final sale = outcome.sale;
  final receipt = SubscriptionReceipt.fromSale(
    sale,
    childName: outcome.childName,
    plan: outcome.plan,
  );
  var printed = false;
  try {
    final local = sl<LocalSource>();
    printed = await SaleReceiptPrinter.printSubscriptionDirect(
      receipt,
      branchName: local.getBranchName() ?? '',
      cashierName: local.getCashierFullName() ?? '',
      preferredPrinterName: local.getReceiptPrinterName(),
    );
  } catch (_) {
    printed = false;
  }
  if (!printed) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.receiptPrintFailed)));
  }
  if (!context.mounted) return;

  final pass = sale.pass;
  if (pass != null) {
    try {
      printPlanEntryLabels(
        context,
        PosEntryResult(entries: [pass], failures: const []),
        {pass.childId: outcome.childName},
        planName: outcome.plan?.kidsPlan?.name ?? sale.subscription.name,
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.stickerPrintFailed)));
    }
  } else if (sale.passFailureCode != null || sale.passFailureMessage != null) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l10n.subscriptionPassFailed(
            sale.passFailureMessage ?? sale.passFailureCode ?? '',
          ),
        ),
      ),
    );
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l10n.subscriptionSold)));
  }
}
