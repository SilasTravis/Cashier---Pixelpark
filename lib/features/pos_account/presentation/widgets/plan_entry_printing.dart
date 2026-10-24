import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/printing/child_ticket_printer.dart';
import '../../../../core/printing/gate_pass_label_printer.dart';
import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../domain/pos_entry.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../../pos_sale/domain/sale_receipt.dart';
import '../../../../injector_container.dart';
import '../../../../generated/l10n.dart';

/// The name line of a child's gate-pass sticker. A time-limited (1 soat)
/// sticker leads with its duration so door staff can tell it from an
/// all-day Standard/VIP sticker at a glance; every other sticker is exactly
/// the child's name, as before. The label printer itself is untouched.
String stickerNameFor(
  String childName,
  int? durationMinutes, {
  bool upgrade = false,
}) {
  // An upgraded sticker says so, so the parent and door staff can tell the
  // new all-day QR from the stopped one.
  if (upgrade) return childName.isEmpty ? 'UPGRADE' : 'UPGRADE · $childName';
  if (durationMinutes == null) return childName;
  final tag = durationMinutes % 60 == 0
      ? '${durationMinutes ~/ 60} SOAT'
      : '$durationMinutes DAQ';
  return childName.isEmpty ? tag : '$tag · $childName';
}

/// The plan line of an upgraded pass's paper ticket: "UPGRADE - VIP". The
/// ticket printer's built-in font is ASCII-only (anything else prints as
/// "?"), so the separator is a plain hyphen — the sticker's "·" is fine
/// there (WinAnsi), not here. No plan name leaves just "UPGRADE".
String upgradeTicketPlanName(String? planName) {
  final name = planName?.trim() ?? '';
  return name.isEmpty ? 'UPGRADE' : 'UPGRADE - $name';
}

/// The price a RE-PRINTED ticket shows: the pass's own register price
/// ([PosEntry.priceUzs], already net of its discount — 0 prints "BEPUL"),
/// never the panel's current pick. Null — "DAQIQABAY" — only for a
/// per-minute (Standard) pass, which has no up-front price; a pass that cost
/// something or carries an hour window is prepaid even when its plan is no
/// longer in the till's list.
int? reprintTicketPriceUzs(PosEntry entry, {required bool prepaidPlan}) {
  final prepaid =
      prepaidPlan || (entry.priceUzs ?? 0) > 0 || entry.durationMinutes != null;
  return prepaid ? entry.priceUzs : null;
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
  bool? reprintPrepaidPlan,
}) {
  final l10n = AppLocalization.of(context);
  // A re-print ([reprintPrepaidPlan] set): each ticket shows what ITS pass
  // cost — nothing is charged again, so no discount line either.
  int? ticketPriceUzs(PosEntry entry) => reprintPrepaidPlan == null
      ? planPriceUzs
      : reprintTicketPriceUzs(entry, prepaidPlan: reprintPrepaidPlan);
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
              upgrade: entry.upgrade,
            ),
            invertName: false,
          ),
        for (final companion in result.companionPasses)
          (qrData: companion.code, name: 'HAMROH', invertName: true),
      ],
      tickets: [
        for (final entry in result.entries)
          if (entry.upgrade)
            // An upgrade prints what was actually charged — the surcharge —
            // not the plan's list price.
            (
              qrData: entry.token,
              childName: childNamesById[entry.childId] ?? '',
              planName: upgradeTicketPlanName(planName),
              priceUzs: entry.priceUzs ?? 0,
              discountUzs: 0,
              discountName: null,
              ticketId: _ticketId(entry.childId),
            )
          else
            (
              qrData: entry.token,
              childName: childNamesById[entry.childId] ?? '',
              planName: planName ?? '',
              priceUzs: ticketPriceUzs(entry),
              discountUzs: planPriceUzs == null || reprintPrepaidPlan != null
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

/// The SLK entry receipt that carries a plan-entry checkout's cashback QR —
/// cashback is earned on entries only, so it is printed only when the
/// server issued one. One line per child pass (+ HAMROH) when every charged
/// price is known and they add up to the money collected; otherwise a single
/// "Kirish" line for the collected total, so the paper never shows a JAMI
/// that differs from what the parent paid. Null = nothing to print.
SaleReceipt? entryCashbackReceipt(
  PosEntryResult result,
  Map<String, String> childNamesById, {
  String? planName,
  int companionPriceUzs = 0,
  DateTime? now,
}) {
  final cashback = result.cashback;
  final sale = result.entrySale;
  if (cashback == null || sale == null || sale.totalUzs <= 0) return null;

  String passLine(PosEntry entry) {
    final child = childNamesById[entry.childId]?.trim() ?? '';
    final plan = entry.upgrade
        ? upgradeTicketPlanName(planName)
        : (planName?.trim().isNotEmpty ?? false)
        ? planName!.trim()
        : 'Kirish';
    return child.isEmpty ? plan : '$plan - $child';
  }

  final lines = <SaleReceiptItem>[
    for (final entry in result.entries)
      SaleReceiptItem(
        productId: entry.childId,
        nameSnapshot: passLine(entry),
        priceSnapshotUzs: entry.priceUzs ?? 0,
        qty: 1,
        lineTotalUzs: entry.priceUzs ?? 0,
      ),
    if (result.companionPasses.isNotEmpty)
      SaleReceiptItem(
        productId: 'hamroh',
        nameSnapshot: 'HAMROH',
        priceSnapshotUzs: companionPriceUzs,
        qty: result.companionPasses.length,
        lineTotalUzs: companionPriceUzs * result.companionPasses.length,
      ),
  ];
  final itemized =
      lines.isNotEmpty &&
      lines.every((line) => line.lineTotalUzs > 0) &&
      lines.fold<int>(0, (sum, line) => sum + line.lineTotalUzs) ==
          sale.totalUzs;
  final items = itemized
      ? lines
      : [
          SaleReceiptItem(
            productId: 'entry',
            nameSnapshot: (planName?.trim().isNotEmpty ?? false)
                ? 'Kirish - ${planName!.trim()}'
                : 'Kirish',
            priceSnapshotUzs: sale.totalUzs,
            qty: 1,
            lineTotalUzs: sale.totalUzs,
          ),
        ];
  return SaleReceipt(
    id: sale.id,
    subtotalUzs: sale.totalUzs,
    cashUzs: sale.cashUzs,
    cardUzs: sale.cardUzs,
    createdAt: now ?? DateTime.now(),
    items: items,
    cashback: cashback,
  );
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
