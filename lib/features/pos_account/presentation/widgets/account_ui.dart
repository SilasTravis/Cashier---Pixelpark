import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/theme/pos_palette.dart';

/// Building blocks shared by the account workspace's search and detail
/// screens — one card, step header and status chip look for every section.

BoxDecoration accountCardDecoration(PosPalette p) => BoxDecoration(
  color: p.surface,
  borderRadius: BorderRadius.circular(AppRadius.lg),
  border: Border.all(color: p.border),
);

/// Initials for an avatar — "Aziza Karimova" → "AK".
String initialsOf(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed
      .split(RegExp(r'\s+'))
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();
}

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: accountCardDecoration(PosPalette.of(context)),
      child: child,
    );
  }
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.name, this.size = 40});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.accentSoft, shape: BoxShape.circle),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: p.accent,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// "① Kim kiradi?" — numbered so a new cashier reads the card top-down.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.title,
    this.step,
    this.icon,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final int? step;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Row(
      children: [
        if (step != null) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            child: Text(
              '$step',
              style: TextStyle(
                color: p.onAccent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: p.accent),
          const SizedBox(width: 8),
        ],
        Text(title, style: p.heading.copyWith(fontSize: 15)),
        const SizedBox(width: 8),
        // Takes the free width, so [trailing] always sits at the far right.
        Expanded(
          child: Text(
            subtitle ?? '',
            overflow: TextOverflow.ellipsis,
            style: p.bodyMuted.copyWith(fontSize: 12),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

enum ChipTone { accent, positive, warning, neutral }

/// Small rounded status label — "Ichkarida · 42 daq", "−20%", "VIP".
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = ChipTone.accent,
  });

  final String label;
  final IconData? icon;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final (bg, fg) = switch (tone) {
      ChipTone.accent => (p.accentSoft, p.accent),
      ChipTone.positive => (p.positiveSoft, p.positive),
      ChipTone.warning => (p.warningSoft, p.warning),
      ChipTone.neutral => (p.surfaceMuted, p.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
