import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../generated/l10n.dart';

/// Ages offered as one-tap tiles — the park's audience.
const birthdayAges = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14];

/// Asks the age [childName] turns today, right after the cashier picks a
/// birthday discount. One tap answers; dismissing returns null and the
/// discount is not applied. [suggested] (the age the stored birth date
/// gives, when plausible) is pre-highlighted.
Future<int?> showBirthdayAgeDialog(
  BuildContext context, {
  required String childName,
  int? suggested,
}) => showDialog<int>(
  context: context,
  builder: (_) =>
      _BirthdayAgeDialog(childName: childName, suggested: suggested),
);

class _BirthdayAgeDialog extends StatelessWidget {
  const _BirthdayAgeDialog({required this.childName, this.suggested});

  final String childName;
  final int? suggested;

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
          maxWidth: (screen.width - 48).clamp(280.0, 460.0),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(PhosphorIconsRegular.cake, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.birthdayAgeTitle, style: p.heading),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(PhosphorIconsRegular.x, color: p.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.birthdayAgeHint(childName),
                style: p.body.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final age in birthdayAges)
                    _AgeTile(
                      key: ValueKey('birthday-age-$age'),
                      age: age,
                      highlighted: age == suggested,
                      onTap: () => Navigator.of(context).pop(age),
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

class _AgeTile extends StatelessWidget {
  const _AgeTile({
    super.key,
    required this.age,
    required this.highlighted,
    required this.onTap,
  });

  final int age;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Material(
      color: highlighted ? p.accent : p.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: highlighted ? p.accent : p.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Center(
          child: Text(
            '$age',
            style: p.heading.copyWith(color: highlighted ? p.onAccent : p.text),
          ),
        ),
      ),
    );
  }
}
