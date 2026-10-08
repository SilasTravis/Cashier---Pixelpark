import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/printing/child_ticket_printer.dart';
import '../../../../core/printing/gate_pass_label_printer.dart';
import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../domain/pos_entry.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../../../injector_container.dart';
import '../../../../generated/l10n.dart';

/// The name line of a child's gate-pass sticker. A time-limited (1 soat)
/// sticker leads with its duration so door staff can tell it from an
/// all-day Standard/VIP sticker at a glance; every other sticker is exactly
/// the child's name, as before. The label printer itself is untouched.
String stickerNameFor(String childName, int? durationMinutes) {
  if (durationMinutes == null) return childName;
  final tag = durationMinutes % 60 == 0
      ? '${durationMinutes ~/ 60} SOAT'
      : '$durationMinutes DAQ';
  return childName.isEmpty ? tag : '$tag · $childName';
}

/// Fires gate-pass label printing the instant entry is confirmed — no
/// preview step, no dialog. Any child who couldn't enter (e.g. already
/// inside) still isn't dropped silently: it surfaces as a SnackBar instead
/// of a blocking modal. Paid HAMROH companion stickers bought with the
/// checkout print in the same batch, styled like the parent sticker
/// (inverted name strip).
///
/// When the label printer can't take the job (no Godex), every pass falls
/// back to a ticket (name, plan, net price and the same entry QR) on the
/// receipt printer — see [printPassesWithTicketFallback].
/// [entryDiscountsByChild] is the entry discount (birthday, partner promo…)
/// each child checked out with, so the ticket shows the discounted price
/// and why — not the plan's list price.
void printPlanEntryLabels(
  BuildContext context,
  PosEntryResult result,
  Map<String, String> childNamesById, {
  String? planName,
  int? planPriceUzs,
  Map<String, Discount> entryDiscountsByChild = const {},
  int companionPriceUzs = 0,
}) {
  final l10n = AppLocalization.of(context);
  if (result.entries.isNotEmpty || result.companionPasses.isNotEmpty) {
    printPassesWithTicketFallback(
      ScaffoldMessenger.of(context),
      l10n,
      stickers: [
        for (final entry in result.entries)
          (
            qrData: entry.token,
            name: stickerNameFor(
              childNamesById[entry.childId] ?? '',
              entry.durationMinutes,
            ),
            invertName: false,
          ),
        for (final companion in result.companionPasses)
          (qrData: companion.code, name: 'HAMROH', invertName: true),
      ],
      tickets: [
        for (final entry in result.entries)
          (
            qrData: entry.token,
            childName: childNamesById[entry.childId] ?? '',
            planName: planName ?? '',
            priceUzs: planPriceUzs,
            discountUzs: planPriceUzs == null
                ? 0
                : entryDiscountsByChild[entry.childId]?.appliedDiscountUzs(
                        planPriceUzs,
                      ) ??
                      0,
            discountName: entryDiscountsByChild[entry.childId]?.name,
            ticketId: _ticketId(entry.childId),
          ),
        for (final companion in result.companionPasses)
          (
            qrData: companion.code,
            childName: 'HAMROH',
            planName: 'HAMROH',
            priceUzs: companionPriceUzs,
            discountUzs: 0,
            discountName: null,
            ticketId: _ticketId(companion.code),
          ),
      ],
    );
  }

  if (result.failures.isNotEmpty) {
    final message = [
      for (final failure in result.failures)
        '${childNamesById[failure.childId] ?? failure.childId}: '
            '${failure.message}',
    ].join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: NocturneColors.surface,
        content: Row(
          children: [
            Icon(
              PhosphorIconsRegular.warning,
              size: 16,
              color: NocturneColors.accent300,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.entryFailed(message))),
          ],
        ),
      ),
    );
  }
}

String _ticketId(String id) => id.length > 8 ? id.substring(0, 8) : id;

/// Two fallbacks firing for one checkout (child tickets + the parent QR)
/// should not stack the same notice twice.
DateTime? _lastFallbackNoticeAt;

/// Prints gate-pass [stickers] on the QR label printer. When that printer
/// isn't there (or refuses the job), the same passes go out as [tickets] on
/// the receipt printer instead and the cashier gets a calm notice — the QR
/// still reached the customer, so it is not an error. Only when the receipt
/// printer fails too is a real "not printed" error shown: a silently
/// swallowed QR is the worst failure mode a gate can have.
void printPassesWithTicketFallback(
  ScaffoldMessengerState messenger,
  AppLocalization l10n, {
  required List<GatePassLabelEntry> stickers,
  required List<ChildTicketEntry> tickets,
}) {
  GatePassLabelPrinter.printDirect(
    stickers,
    preferredPrinterName: sl<LocalSource>().getQrPrinterName(),
  ).then((ok) async {
    if (ok) return;
    var ticketsPrinted = false;
    if (tickets.isNotEmpty) {
      final local = sl<LocalSource>();
      try {
        ticketsPrinted = await ChildTicketPrinter.printDirect(
          tickets,
          branchName: local.getBranchName() ?? '',
          preferredPrinterName: local.getReceiptPrinterName(),
        );
      } catch (_) {}
    }
    if (ticketsPrinted) {
      final now = DateTime.now();
      final last = _lastFallbackNoticeAt;
      if (last != null && now.difference(last) < const Duration(seconds: 5)) {
        return;
      }
      _lastFallbackNoticeAt = now;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: NocturneColors.surface,
          content: Row(
            children: [
              Icon(
                PhosphorIconsRegular.printer,
                size: 16,
                color: NocturneColors.accent300,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.qrPrinterFallbackNotice)),
            ],
          ),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: NocturneColors.surface,
        content: Text(
          l10n.stickerPrintFailed,
          style: TextStyle(color: NocturneColors.danger),
        ),
      ),
    );
  });
}
