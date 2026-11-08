import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_plan.dart';
import 'birthday_ui.dart';

/// Step "Tarif": one big soft card per package, tinted with its colour, with
/// the lowest price ("1 200 000 so'm dan") and its sizes. The selected one
/// gets a colour border and a check, and what it includes opens right below.
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
    final selected = plans.where((pl) => pl.id == selectedId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final plan in plans) ...[
                if (plan != plans.first) const SizedBox(width: 12),
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
        ),
        if (selected != null && selected.includedItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Included(plan: selected),
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
    final ink = tierInk(context, color);
    final from = plan.sizes.isEmpty
        ? null
        : plan.sizes.map((s) => s.priceUzs).reduce((a, b) => a < b ? a : b);
    final radius = BorderRadius.circular(20);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: isNight(context) ? 0 : 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: Material(
        key: ValueKey('birthday-tier-${plan.id}'),
        color: tierTint(context, color, strength: selected ? 1.5 : 0.75),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // The colour accent bar on the left edge.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: color),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            overflow: TextOverflow.ellipsis,
                            style: p.title.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: selected ? 1 : 0,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              PhosphorIconsBold.check,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (from != null)
                      Text(
                        l10n.birthdayFromPrice(formatUzs(from)),
                        style: tabular(
                          p.body.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (plan.sizes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${plan.sizes.map((s) => s.childCount).join(' · ')} '
                        '${l10n.birthdayChildrenUnit}',
                        style: tabular(p.bodyMuted.copyWith(fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "VIP tarifiga kiradi" — the selected tier's list, two columns.
class _Included extends StatelessWidget {
  const _Included({required this.plan});

  final BirthdayPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final color = colorOf(plan.color, p.accent);
    return Container(
      key: const ValueKey('birthday-includes'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: tierTint(context, color, strength: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.birthdayIncludesTier(plan.name).toUpperCase(),
            style: p.kicker.copyWith(
              fontSize: 11,
              color: tierInk(context, color),
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760
                  ? 3
                  : constraints.maxWidth >= 480
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  for (final item in plan.includedItems)
                    SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              PhosphorIconsBold.check,
                              size: 15,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              style: p.body.copyWith(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
