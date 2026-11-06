import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';

/// The largest class the till checks in at once (the backend's limit).
const maxGroupCount = 300;

/// Asks how many children of a school class came in. Returns the count, 0
/// to drop the group from the checkout, or null when dismissed. [current]
/// (the seats already picked) prefills the field and offers "remove".
Future<int?> showGroupCountDialog(BuildContext context, {int current = 0}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _GroupCountDialog(current: current),
    );

class _GroupCountDialog extends StatefulWidget {
  const _GroupCountDialog({required this.current});

  final int current;

  @override
  State<_GroupCountDialog> createState() => _GroupCountDialogState();
}

class _GroupCountDialogState extends State<_GroupCountDialog> {
  late final _controller = TextEditingController(
    text: widget.current > 0 ? '${widget.current}' : '',
  );

  int? get _count {
    final value = int.tryParse(_controller.text.trim());
    return value != null && value >= 1 && value <= maxGroupCount ? value : null;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final count = _count;
    if (count != null) Navigator.of(context).pop(count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (screen.width - 48).clamp(280.0, 440.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.usersThree, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.groupDialogTitle, style: p.heading),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(PhosphorIconsRegular.x, color: p.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.groupDialogHint,
                style: p.body.copyWith(fontSize: 13, color: p.textMuted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: p.body.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: l10n.groupCountLabel,
                  prefixIcon: const Icon(PhosphorIconsRegular.hash, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.current > 0)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(0),
                      child: Text(
                        l10n.groupRemove,
                        style: TextStyle(color: p.danger),
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _count == null ? null : _submit,
                      icon: const Icon(PhosphorIconsRegular.check, size: 16),
                      label: Text(l10n.groupApply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
