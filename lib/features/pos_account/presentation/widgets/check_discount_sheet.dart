import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_sale/domain/discount.dart';
import 'entry_discount_dialog.dart';

/// The dialog's "Chegirmasiz" button — a null pop means it was dismissed.
final Object _noCheckDiscount = Object();

/// "Oila · 10%" / "Aksiya · 30 000 so'm".
String checkDiscountLabel(Discount discount) =>
    '${discount.name} · ${_amount(discount)}';

String _amount(Discount discount) => discount.kind == DiscountKind.percent
    ? '${discount.value}%'
    : formatUzs(discount.value);

/// "Chek chegirmasi" (Butun chek) — next to HAMROH in step 3. Opens a dialog
/// with every active check-scope discount as a grid of tiles; the cashier
/// picks one, no conditions. The panel hides it when the catalog is empty.
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
    final p = PosPalette.of(context);
    final picked = selected != null;
    final radius = BorderRadius.circular(12);
    return Material(
      color: picked ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: picked ? p.accent : p.borderStrong,
          width: picked ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () async {
          final result = await showDialog<Object>(
            context: context,
            builder: (_) =>
                _CheckDiscountDialog(discounts: discounts, selected: selected),
          );
          if (result == null) return;
          onChanged(
            identical(result, _noCheckDiscount) ? null : result as Discount,
          );
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: picked ? p.accent : p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsRegular.percent,
                  size: 16,
                  color: picked ? p.onAccent : p.accentStrong,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.checkDiscount,
                      style: p.heading.copyWith(fontSize: 13.5),
                    ),
                    Text(
                      picked
                          ? checkDiscountLabel(selected!)
                          : l10n.checkDiscountNone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: picked
                          ? p.body.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: p.accent,
                            )
                          : p.bodyMuted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                PhosphorIconsRegular.caretDown,
                size: 16,
                color: p.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid of the check discounts, in the admin's catalog order. Same sizing
/// rules as the per-child dialog: capped to the window, scrolls past that.
class _CheckDiscountDialog extends StatelessWidget {
  const _CheckDiscountDialog({required this.discounts, required this.selected});

  final List<Discount> discounts;
  final Discount? selected;

  static const _gap = 8.0;
  static const _minTileWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = (screen.width - 48).clamp(280.0, 640.0);
    final maxHeight = (screen.height - 48).clamp(240.0, 560.0);
    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.checkDiscount, style: p.heading)),
                  IconButton(
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(PhosphorIconsRegular.x, color: p.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final columns =
                        ((box.maxWidth + _gap) / (_minTileWidth + _gap))
                            .floor()
                            .clamp(1, 4);
                    final tileWidth =
                        (box.maxWidth - _gap * (columns - 1)) / columns;
                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: _gap,
                        runSpacing: _gap,
                        children: [
                          for (final discount in discounts)
                            SizedBox(
                              width: tileWidth,
                              child: DiscountTile(
                                title: discount.name,
                                amount: _amount(discount),
                                selected: discount.id == selected?.id,
                                onTap: () =>
                                    Navigator.of(context).pop(discount),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.danger,
                    side: BorderSide(color: p.danger),
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                  label: Text(l10n.noDiscount),
                  onPressed: () => Navigator.of(context).pop(_noCheckDiscount),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
