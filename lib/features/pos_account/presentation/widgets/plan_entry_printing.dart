import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/printing/gate_pass_label_printer.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../domain/pos_entry.dart';

/// Fires gate-pass label printing the instant entry is confirmed — no
/// preview step, no dialog. Any child who couldn't enter (e.g. already
/// inside) still isn't dropped silently: it surfaces as a SnackBar instead
/// of a blocking modal. Paid HAMROH companion stickers bought with the
/// checkout print in the same batch, styled like the parent sticker
/// (inverted name strip).
void printPlanEntryLabels(
  BuildContext context,
  PosEntryResult result,
  Map<String, String> childNamesById,
) {
  if (result.entries.isNotEmpty || result.companionPasses.isNotEmpty) {
    final messenger = ScaffoldMessenger.of(context);
    GatePassLabelPrinter.printDirect([
      for (final entry in result.entries)
        (
          qrData: entry.token,
          name: childNamesById[entry.childId] ?? '',
          invertName: false,
        ),
      for (final companion in result.companionPasses)
        (qrData: companion.code, name: 'HAMROH', invertName: true),
    ]).then((ok) {
      if (ok) return;
      // A silently swallowed sticker is the worst failure mode a gate can
      // have — tell the cashier so they can re-print or check the printer.
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: NocturneColors.surface,
          content: Text(
            'Stiker chop etilmadi — printerni tekshiring',
            style: TextStyle(color: NocturneColors.danger),
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
            Expanded(child: Text('Kirmadi: $message')),
          ],
        ),
      ),
    );
  }
}
