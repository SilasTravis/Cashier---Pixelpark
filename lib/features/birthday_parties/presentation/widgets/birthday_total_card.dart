import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_account/presentation/widgets/account_ui.dart';
import '../../domain/birthday_plan.dart';
import '../bloc/birthday_sell_cubit.dart';

String birthdayDateLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Step "Bayram kuni": the party date and the price breakdown with the
/// editable "Jami" (the list price struck through when the cashier agreed on
/// another total).
class BirthdayTotalCard extends StatelessWidget {
  const BirthdayTotalCard({
    super.key,
    required this.state,
    required this.size,
    required this.totalController,
    required this.onPickDate,
    required this.onTotalChanged,
  });

  final BirthdaySellState state;
  final BirthdayPlanSize size;
  final TextEditingController totalController;
  final VoidCallback onPickDate;
  final ValueChanged<String> onTotalChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final extra = state.extraChildren;
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('birthday-date'),
              onPressed: onPickDate,
              icon: const Icon(PhosphorIconsRegular.calendarBlank, size: 16),
              label: Text(birthdayDateLabel(state.partyDate)),
            ),
          ),
          const SizedBox(height: 12),
          _row(
            p,
            '${state.plan!.name} · ${size.childCount}',
            formatUzs(size.priceUzs),
          ),
          if (extra > 0)
            _row(
              p,
              '+$extra × ${groupDigits(size.extraChildUzs)}',
              formatUzs(extra * size.extraChildUzs),
            ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(child: Text(l10n.birthdayTotal, style: p.heading)),
              if (state.discountUzs > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    formatUzs(state.listPriceUzs),
                    key: const ValueKey('birthday-list-struck'),
                    style: p.bodyMuted.copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              SizedBox(
                width: 190,
                child: TextField(
                  key: const ValueKey('birthday-total-field'),
                  controller: totalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  textAlign: TextAlign.end,
                  style: p.title.copyWith(fontSize: 24),
                  onChanged: onTotalChanged,
                ),
              ),
            ],
          ),
          if (state.discountUzs > 0) ...[
            const SizedBox(height: 6),
            Text(
              l10n.birthdayDiscountNote(formatUzs(state.discountUzs)),
              style: p.bodyMuted.copyWith(fontSize: 12, color: p.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(PosPalette p, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: p.bodyMuted),
        Text(value, style: p.body),
      ],
    ),
  );
}
