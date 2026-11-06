import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';

/// Step "Qo'shimcha bola": `+` only — a miscounted cashier resets with
/// "0 ga qaytarish" (tap the number) instead of a minus that could go below
/// what the family already booked.
class ExtraChildrenStepper extends StatelessWidget {
  const ExtraChildrenStepper({
    super.key,
    required this.count,
    required this.hint,
    required this.onAdd,
    required this.onReset,
  });

  final int count;
  final String hint;
  final VoidCallback onAdd;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return Row(
      children: [
        Expanded(child: Text(hint, style: p.bodyMuted.copyWith(fontSize: 13))),
        PopupMenuButton<void>(
          key: const ValueKey('birthday-extra-count'),
          enabled: count > 0,
          tooltip: '',
          onSelected: (_) => onReset(),
          itemBuilder: (_) => [
            PopupMenuItem<void>(
              key: const ValueKey('birthday-extra-reset'),
              child: Text(l10n.birthdayResetExtra),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count == 0 ? '0' : '+$count',
              textAlign: TextAlign.center,
              style: p.title.copyWith(fontSize: 22),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton.filled(
            key: const ValueKey('birthday-extra-plus'),
            onPressed: onAdd,
            icon: const Icon(PhosphorIconsRegular.plus, size: 20),
          ),
        ),
      ],
    );
  }
}
