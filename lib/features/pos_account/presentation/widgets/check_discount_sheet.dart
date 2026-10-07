import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_sale/domain/discount.dart';

/// The sheet's "Chegirmasiz" row — a null pop means the sheet was dismissed.
final Object _noCheckDiscount = Object();

/// "Oila · 10%" / "Aksiya · 30 000 so'm".
String checkDiscountLabel(Discount discount) =>
    '${discount.name} · ${_amount(discount)}';

String _amount(Discount discount) => discount.kind == DiscountKind.percent
    ? '${discount.value}%'
    : formatUzs(discount.value);

/// "Chek chegirmasi" (Butun chek) — right above the pay button. Opens a
/// bottom sheet with every active check-scope discount; the cashier picks
/// one, no conditions. The panel hides it when the catalog is empty.
class CheckDiscountButton extends StatelessWidget {
  const CheckDiscountButton({
    super.key,
    required this.discounts,
    required this.selected,
    required this.onChanged,
  });

  final List<Discount> discounts;
  final Discount? selected;
  final ValueChanged<Discount?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return OutlinedButton(
      onPressed: () async {
        final picked = await showModalBottomSheet<Object>(
          context: context,
          backgroundColor: NocturneColors.surface,
          showDragHandle: true,
          // Lets the sheet grow past the default 9/16 of the window; the
          // list itself scrolls once the catalog outgrows the cap below.
          isScrollControlled: true,
          builder: (_) =>
              _CheckDiscountSheet(discounts: discounts, selected: selected),
        );
        if (picked == null) return;
        onChanged(
          identical(picked, _noCheckDiscount) ? null : picked as Discount,
        );
      },
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.percent, size: 18),
          const SizedBox(width: 8),
          Text(l10n.checkDiscount),
          const Spacer(),
          Flexible(
            child: Text(
              selected == null
                  ? l10n.checkDiscountNone
                  : checkDiscountLabel(selected!),
              overflow: TextOverflow.ellipsis,
              style: selected == null
                  ? AppTextStyles.muted(
                      AppTextStyles.body,
                    ).copyWith(fontSize: 13)
                  : AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: NocturneColors.accent,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckDiscountSheet extends StatelessWidget {
  const _CheckDiscountSheet({required this.discounts, required this.selected});

  final List<Discount> discounts;
  final Discount? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    Widget option(
      String title,
      String? amount,
      bool isSelected,
      Object value,
    ) => ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (amount != null) Text(amount, style: AppTextStyles.h5),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Icon(
              PhosphorIconsRegular.check,
              color: NocturneColors.accent,
            ),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.checkDiscount, style: AppTextStyles.h5),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    option(
                      l10n.noDiscount,
                      null,
                      selected == null,
                      _noCheckDiscount,
                    ),
                    for (final discount in discounts)
                      option(
                        discount.name,
                        _amount(discount),
                        discount.id == selected?.id,
                        discount,
                      ),
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
