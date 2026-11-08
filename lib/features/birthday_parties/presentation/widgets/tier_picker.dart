import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_plan.dart';

/// Step "Tarif": one card per package with its colour dot and the lowest
/// price ("500 000 dan"); the selected tier lists what it includes below.
class TierPicker extends StatelessWidget {
  const TierPicker({
    super.key,
    required this.plans,
    required this.selectedId,
    required this.onSelected,
  });

  final List<BirthdayPlan> plans;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final selected = plans.where((pl) => pl.id == selectedId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final plan in plans) ...[
              if (plan != plans.first) const SizedBox(width: 10),
              Expanded(
                child: _TierCard(
                  plan: plan,
                  selected: plan.id == selectedId,
                  onTap: () => onSelected(plan.id),
                ),
              ),
            ],
          ],
        ),
        if (selected != null && selected.includedItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(l10n.birthdayIncludes, style: p.kicker),
          const SizedBox(height: 6),
          for (final item in selected.includedItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.check,
                    size: 14,
                    color: colorOf(selected.color, p.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item, style: p.body.copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final BirthdayPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final color = colorOf(plan.color, p.accent);
    final from = plan.sizes.isEmpty
        ? null
        : plan.sizes.map((s) => s.priceUzs).reduce((a, b) => a < b ? a : b);
    final radius = BorderRadius.circular(14);
    return Material(
      key: ValueKey('birthday-tier-${plan.id}'),
      color: selected ? color.withValues(alpha: 0.10) : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? color : p.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.name,
                      overflow: TextOverflow.ellipsis,
                      style: p.heading.copyWith(fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                from == null ? '' : l10n.birthdayFromPrice(groupDigits(from)),
                style: p.bodyMuted.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
