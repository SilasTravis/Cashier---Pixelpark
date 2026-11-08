import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_plan.dart';
import 'birthday_ui.dart';

/// Step "Bolalar soni": one big tile per package size — the child count as
/// the largest text, the package price and what each extra child costs. The
/// picked tile wears the tier colour.
class SizePicker extends StatelessWidget {
  const SizePicker({
    super.key,
    required this.sizes,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final List<BirthdayPlanSize> sizes;
  final int selected;
  final Color color;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final fit = ((constraints.maxWidth + gap) / (150 + gap)).floor();
        final columns = sizes.length.clamp(1, fit.clamp(1, 4));
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final size in sizes)
              SizedBox(
                width: width,
                child: _SizeTile(
                  size: size,
                  selected: size.childCount == selected,
                  color: color,
                  onTap: () => onSelected(size.childCount),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.size,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final BirthdayPlanSize size;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final ink = tierInk(context, color);
    final radius = BorderRadius.circular(18);
    return Material(
      key: ValueKey('birthday-size-${size.childCount}'),
      color: selected
          ? tierTint(context, color, strength: 1.5)
          : p.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${size.childCount}',
                    style: tabular(
                      p.title.copyWith(
                        fontSize: 40,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: selected ? ink : p.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.birthdayChildrenUnit,
                      overflow: TextOverflow.ellipsis,
                      style: p.bodyMuted.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected ? ink : p.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatUzs(size.priceUzs),
                style: tabular(
                  p.heading.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.birthdayExtraPlusPrice(groupDigits(size.extraChildUzs)),
                style: tabular(p.bodyMuted.copyWith(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
