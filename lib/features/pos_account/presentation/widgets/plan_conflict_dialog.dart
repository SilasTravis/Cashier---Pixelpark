import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/pos_entry.dart';
import '../bloc/pos_account_bloc.dart';
import '../../../../generated/l10n.dart';

/// The plan-switch confirmation: the child already holds today's pass on
/// ANOTHER plan, so nothing was printed. Shows what the child is on now (and
/// what settling the running time costs), and on "Almashtirish" retries the
/// same plan-entry with `replacePlan` — the backend settles + kills the old
/// pass and the fresh QR prints through the normal result flow.
///
/// Downgrades arrive with `switchable == false`; there the modal instead
/// offers re-printing the CURRENT pass — the everyday reason a cashier
/// lands here is a lost sticker, and a blocked switch must not leave them
/// with no way to print at all. The re-print goes through the same
/// plan-entry request with the child's current plan, which the backend
/// answers with the existing pass (same code, old sticker keeps working).
Future<void> showPlanConflictDialog(
  BuildContext context, {
  required List<PosEntryConflict> conflicts,
  required Map<String, String> childNamesById,
  required String requestedPlanName,

  /// The requested plan's flat day price when it is VIP — the backend
  /// refuses the switch unless the balance already covers it, so the
  /// modal says so before the cashier confirms.
  int? requestedPlanFlatUzs,
}) {
  final bloc = context.read<PosAccountBloc>();
  final switchable = conflicts.where((c) => c.switchable).toList();
  // currentPlanKey is null only when the plan row was deleted — nothing to
  // re-print against then.
  final reprintable = conflicts.where((c) => c.currentPlanKey != null).toList();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final l10n = AppLocalization.of(dialogContext);
      return AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: Text(l10n.planSwitch, style: AppTextStyles.h4),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final conflict in conflicts) ...[
                _ConflictRow(
                  conflict: conflict,
                  childName:
                      childNamesById[conflict.childId] ?? conflict.childId,
                ),
                const SizedBox(height: 8),
              ],
              if (switchable.isNotEmpty)
                Text(
                  requestedPlanFlatUzs == null
                      ? l10n.planSwitchQuestion(requestedPlanName)
                      : l10n.planSwitchVipQuestion(
                          requestedPlanName,
                          formatUzs(requestedPlanFlatUzs),
                        ),
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          if (reprintable.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                // Children may sit on different current plans — one
                // same-plan re-print request per plan key.
                final childIdsByPlan = <String, List<String>>{};
                for (final c in reprintable) {
                  childIdsByPlan
                      .putIfAbsent(c.currentPlanKey!, () => [])
                      .add(c.childId);
                }
                for (final entry in childIdsByPlan.entries) {
                  bloc.add(
                    PosAccountPlanEntryRequested(
                      planKey: entry.key,
                      childIds: entry.value,
                    ),
                  );
                }
              },
              icon: const Icon(PhosphorIconsRegular.printer, size: 16),
              label: Text(l10n.reprint),
            ),
          if (switchable.isNotEmpty)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                bloc.add(
                  PosAccountPlanEntryRequested(
                    planKey: switchable.first.requestedPlanKey,
                    childIds: [for (final c in switchable) c.childId],
                    replacePlan: true,
                  ),
                );
              },
              icon: const Icon(PhosphorIconsRegular.printer, size: 16),
              label: Text(l10n.switchAndPrint),
            ),
        ],
      );
    },
  );
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({required this.conflict, required this.childName});

  final PosEntryConflict conflict;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final details = <String>[
      l10n.currentPlanToday(
        childName,
        conflict.currentPlanLabel,
        conflict.isInside ? l10n.insideSuffix : '',
      ),
      if (!conflict.switchable) l10n.downgradeForbidden,
      if (conflict.switchable && conflict.accruedDueUzs > 0)
        l10n.accruedDue(formatUzs(conflict.accruedDueUzs)),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: NocturneColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NocturneColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            conflict.switchable
                ? PhosphorIconsRegular.arrowsClockwise
                : PhosphorIconsRegular.warning,
            size: 16,
            color: NocturneColors.accent300,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              details.join(' '),
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
