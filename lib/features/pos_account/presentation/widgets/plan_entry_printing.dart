import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/printing/child_ticket_printer.dart';
import '../../../../core/printing/gate_pass_label_printer.dart';
import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../domain/pos_entry.dart';
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
/// When the label printer can't take the job (no Godex), each child's entry
/// falls back to a text ticket (name, plan, price) on the receipt printer.
void printPlanEntryLabels(
  BuildContext context,
  PosEntryResult result,
  Map<String, String> childNamesById, {
  String? planName,
  int? planPriceUzs,
}) {
  final l10n = AppLocalization.of(context);
  if (result.entries.isNotEmpty || result.companionPasses.isNotEmpty) {
    final messenger = ScaffoldMessenger.of(context);
    GatePassLabelPrinter.printDirect([
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
    ], preferredPrinterName: sl<LocalSource>().getQrPrinterName()).then((
      ok,
    ) async {
      if (ok) return;
      if (result.entries.isNotEmpty) {
        final local = sl<LocalSource>();
        var ticketsPrinted = false;
        try {
          ticketsPrinted = await ChildTicketPrinter.printDirect(
            [
              for (final entry in result.entries)
                (
                  childName: childNamesById[entry.childId] ?? '',
                  planName: planName ?? '',
                  priceUzs: planPriceUzs,
                  ticketId: entry.childId.length > 8
                      ? entry.childId.substring(0, 8)
                      : entry.childId,
                ),
            ],
            branchName: local.getBranchName() ?? '',
            preferredPrinterName: local.getReceiptPrinterName(),
          );
        } catch (_) {}
        // Companion (HAMROH) stickers have no ticket form — only stay quiet
        // when there was nothing but children to print.
        if (ticketsPrinted && result.companionPasses.isEmpty) return;
      }
      // A silently swallowed sticker is the worst failure mode a gate can
      // have — tell the cashier so they can re-print or check the printer.
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: NocturneColors.surface,
          content: Text(
            l10n.stickerPrintFailed,
            style: const TextStyle(color: NocturneColors.danger),
          ),
        ),
      );
    });
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
            const Icon(
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
