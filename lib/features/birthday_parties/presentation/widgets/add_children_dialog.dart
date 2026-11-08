import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';

/// "+ bola": how many extra children join (1–50) at the party's snapshot
/// price. Resolves with the count, null when closed.
Future<int?> showAddChildrenDialog(BuildContext context, BirthdayParty party) {
  final theme = Theme.of(context);
  return showDialog<int>(
    context: context,
    builder: (_) => Theme(
      data: theme,
      child: _AddChildrenDialog(party: party),
    ),
  );
}

class _AddChildrenDialog extends StatefulWidget {
  const _AddChildrenDialog({required this.party});
  final BirthdayParty party;

  @override
  State<_AddChildrenDialog> createState() => _AddChildrenDialogState();
}

class _AddChildrenDialogState extends State<_AddChildrenDialog> {
  int _count = 1;

  void _step(int by) => setState(() => _count = (_count + by).clamp(1, 50));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return AlertDialog(
      title: Text(l10n.bdAddChildTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.outlined(
                key: const ValueKey('bd-child-minus'),
                onPressed: _count > 1 ? () => _step(-1) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '$_count',
                  textAlign: TextAlign.center,
                  style: p.title.copyWith(fontSize: 28),
                ),
              ),
              IconButton.outlined(
                key: const ValueKey('bd-child-plus'),
                onPressed: _count < 50 ? () => _step(1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            l10n.bdAddChildPrice(
              groupDigits(_count * widget.party.extraChildUzs),
            ),
            style: p.heading,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const ValueKey('bd-child-submit'),
          onPressed: () => Navigator.of(context).pop(_count),
          child: Text(l10n.bdAddChildSubmit),
        ),
      ],
    );
  }
}
