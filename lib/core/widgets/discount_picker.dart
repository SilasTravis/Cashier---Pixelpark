import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../features/pos_sale/domain/discount.dart';
import '../../generated/l10n.dart';
import '../theme/app_text_styles.dart';
import '../theme/nocturne_colors.dart';
import '../utils/currency.dart';

/// Sentinel for the "no discount" menu item — a null-valued `PopupMenuItem`
/// is read by Flutter as a cancel, not a selection, so clearing needs its
/// own non-null value. Same trick as `customer_detail_panel.dart`'s
/// `_clearFreeReason`.
const _clearDiscount = Object();

String _valueLabel(Discount discount) => discount.kind == DiscountKind.percent
    ? '${discount.value}%'
    : formatUzs(discount.value);

/// One discount per receipt, picked from a popup menu — mirrors the
/// free-reason picker's UI idiom in `customer_detail_panel.dart`. The
/// caller hides this entirely when `discounts` is empty (best-effort
/// catalog fetch failed, returned none, or the backend predates it).
class DiscountPicker extends StatelessWidget {
  const DiscountPicker({
    super.key,
    required this.discounts,
    required this.selectedDiscount,
    required this.onChanged,
  });

  final List<Discount> discounts;
  final Discount? selectedDiscount;
  final ValueChanged<Discount?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return PopupMenuButton<Object>(
      tooltip: l10n.discount,
      color: NocturneColors.surface,
      onSelected: (value) => onChanged(value is Discount ? value : null),
      itemBuilder: (context) => [
        PopupMenuItem<Object>(
          value: _clearDiscount,
          child: Row(
            children: [
              Icon(
                selectedDiscount == null
                    ? PhosphorIconsRegular.checkCircle
                    : PhosphorIconsRegular.circle,
                size: 16,
                color: selectedDiscount == null
                    ? NocturneColors.accent
                    : NocturneColors.text,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.noDiscount,
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
        for (final discount in discounts)
          PopupMenuItem<Object>(
            value: discount,
            child: Row(
              children: [
                Icon(
                  selectedDiscount?.id == discount.id
                      ? PhosphorIconsRegular.checkCircle
                      : PhosphorIconsRegular.circle,
                  size: 16,
                  color: selectedDiscount?.id == discount.id
                      ? NocturneColors.accent
                      : NocturneColors.text,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${discount.name} (${_valueLabel(discount)})',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectedDiscount != null
                ? NocturneColors.accent
                : NocturneColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.tag,
              size: 14,
              color: selectedDiscount != null
                  ? NocturneColors.accent
                  : NocturneColors.text,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selectedDiscount?.name ?? l10n.noDiscount,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: selectedDiscount != null
                      ? NocturneColors.accent
                      : NocturneColors.text,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretDown,
              size: 12,
              color: selectedDiscount != null
                  ? NocturneColors.accent
                  : NocturneColors.text,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "Chegirma (name) −X so'm" row shown under the picker once one is
/// selected — shared by the cart panel and the plan-entry goods cart.
class DiscountSummaryRow extends StatelessWidget {
  const DiscountSummaryRow({
    super.key,
    required this.name,
    required this.amountUzs,
  });

  final String name;
  final int amountUzs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${l10n.discount} ($name)',
              style: AppTextStyles.muted(
                AppTextStyles.body,
              ).copyWith(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '−${formatUzs(amountUzs)}',
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              color: NocturneColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
