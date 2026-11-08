import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_plan.dart';

/// Step "Bolalar soni": one big tile per package size — child count, package
/// price and what each extra child costs at that size.
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
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(14);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final size in sizes)
          SizedBox(
            width: 168,
            child: Material(
              key: ValueKey('birthday-size-${size.childCount}'),
              color: size.childCount == selected
                  ? color.withValues(alpha: 0.10)
                  : p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: size.childCount == selected ? color : p.border,
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: () => onSelected(size.childCount),
                borderRadius: radius,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${size.childCount}',
                            style: p.title.copyWith(fontSize: 30),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              l10n.birthdayChildrenUnit,
                              overflow: TextOverflow.ellipsis,
                              style: p.bodyMuted.copyWith(fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        groupDigits(size.priceUzs),
                        style: p.heading.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.birthdayExtraPlusPrice(
                          groupDigits(size.extraChildUzs),
                        ),
                        style: p.bodyMuted.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
