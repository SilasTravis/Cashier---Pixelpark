import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_plan.dart';
import '../bloc/birthday_sell_cubit.dart';
import 'birthday_ui.dart';

/// The price breakdown of a sale — package, extra children, a discount when
/// the cashier typed another total — and the editable "Jami" (the computed
/// price struck through beside it when changed).
class BirthdaySummary extends StatelessWidget {
  const BirthdaySummary({
    super.key,
    required this.state,
    required this.size,
    required this.totalController,
    required this.onTotalChanged,
  });

  final BirthdaySellState state;
  final BirthdayPlanSize size;
  final TextEditingController totalController;
  final ValueChanged<String> onTotalChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final plan = state.plan!;
    final color = colorOf(plan.color, p.accent);
    final extra = state.extraChildren;
    final surcharge = state.agreedUzs > state.listPriceUzs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _line(
          p,
          leading: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          label:
              '${plan.name} · ${size.childCount} ${l10n.birthdayChildrenUnit}',
          value: formatUzs(size.priceUzs),
          key: 'birthday-line-package',
        ),
        if (extra > 0)
          _line(
            p,
            label:
                '${l10n.birthdayExtraChild}  $extra × '
                '${groupDigits(size.extraChildUzs)}',
            value: formatUzs(extra * size.extraChildUzs),
            key: 'birthday-line-extra',
          ),
        if (state.discountUzs > 0)
          _line(
            p,
            label: l10n.birthdayDiscountLine,
            value: '−${formatUzs(state.discountUzs)}',
            color: p.positive,
            key: 'birthday-line-discount',
          ),
        const SizedBox(height: 10),
        Divider(height: 1, color: p.border),
        const SizedBox(height: 12),
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.birthdayTotal,
                  style: p.heading.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (state.discountUzs > 0 || surcharge)
                  Text(
                    formatUzs(state.listPriceUzs),
                    key: const ValueKey('birthday-list-struck'),
                    style: tabular(
                      p.bodyMuted.copyWith(
                        fontSize: 13,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: p.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Tooltip(
                message: l10n.birthdayTotalEditHint,
                child: TextField(
                  key: const ValueKey('birthday-total-field'),
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  textAlign: TextAlign.end,
                  style: tabular(
                    p.title.copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: p.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.pencilSimple,
                      size: 18,
                      color: p.textFaint,
                    ),
                    suffixText: "so'm",
                    suffixStyle: p.bodyMuted.copyWith(fontSize: 15),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: p.accent, width: 1.6),
                    ),
                  ),
                  onChanged: onTotalChanged,
                ),
              ),
            ),
          ],
        ),
        if (state.discountUzs > 0) ...[
          const SizedBox(height: 6),
          Text(
            l10n.birthdayDiscountNote(formatUzs(state.discountUzs)),
            textAlign: TextAlign.end,
            style: p.bodyMuted.copyWith(fontSize: 12, color: p.warning),
          ),
        ],
      ],
    );
  }

  Widget _line(
    PosPalette p, {
    required String label,
    required String value,
    required String key,
    Widget? leading,
    Color? color,
  }) => Padding(
    key: ValueKey(key),
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: tabular(
              p.body.copyWith(fontSize: 14.5, color: color ?? p.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: tabular(
            p.body.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color ?? p.text,
            ),
          ),
        ),
      ],
    ),
  );
}
