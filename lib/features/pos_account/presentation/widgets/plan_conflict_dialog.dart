import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/pos_entry.dart';
import '../bloc/pos_account_bloc.dart';

/// The plan-switch confirmation: the child already holds today's pass on
/// ANOTHER plan, so nothing was printed. Shows what the child is on now (and
/// what settling the running time costs), and on "Almashtirish" retries the
/// same plan-entry with `replacePlan` — the backend settles + kills the old
/// pass and the fresh QR prints through the normal result flow.
///
/// Downgrades arrive with `switchable == false` and are explained
/// information-only; the confirm button covers just the switchable children.
Future<void> showPlanConflictDialog(
  BuildContext context, {
  required List<PosEntryConflict> conflicts,
  required Map<String, String> childNamesById,
  required String requestedPlanName,
}) {
  final bloc = context.read<PosAccountBloc>();
  final switchable = conflicts.where((c) => c.switchable).toList();
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: NocturneColors.surface,
        title: const Text('Reja almashtirish', style: AppTextStyles.h4),
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
                  '«$requestedPlanName» rejasiga almashtirilsinmi? '
                  'Eski stiker bekor qilinadi va yangi QR chop etiladi.',
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Bekor qilish'),
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
              label: const Text('Almashtirish va chop etish'),
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
    final details = <String>[
      '«$childName» bugun «${conflict.currentPlanLabel}» rejasida'
          '${conflict.isInside ? ' (hozir ichkarida)' : ''}.',
      if (!conflict.switchable)
        'Bu rejadan pasaytirish mumkin emas — mavjud stiker amal qiladi.',
      if (conflict.switchable && conflict.accruedDueUzs > 0)
        "O'ynagan vaqti uchun ${formatUzs(conflict.accruedDueUzs)} "
            'balansdan yechiladi.',
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
