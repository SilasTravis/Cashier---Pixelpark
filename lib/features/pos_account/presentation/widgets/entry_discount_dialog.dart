import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_sale/domain/discount.dart';

/// Result of [showEntryDiscountDialog]: `null` = dismissed, `(id: null)` =
/// the cashier cleared the child's discount, otherwise the picked id.
typedef EntryDiscountPick = ({String? id});

/// Picks one entry discount for a child. Tiles are grouped (free / percent /
/// fixed amount) and sorted so a long catalog stays scannable; past
/// [_searchFrom] discounts a name filter appears. The dialog never outgrows
/// the window: width and height are capped to the screen minus a margin and
/// the grid scrolls only if the catalog really is that long.
Future<EntryDiscountPick?> showEntryDiscountDialog(
  BuildContext context, {
  required List<Discount> discounts,
  required String? selectedId,
}) => showDialog<EntryDiscountPick>(
  context: context,
  builder: (_) =>
      _EntryDiscountDialog(discounts: discounts, selectedId: selectedId),
);

class _EntryDiscountDialog extends StatefulWidget {
  const _EntryDiscountDialog({
    required this.discounts,
    required this.selectedId,
  });

  final List<Discount> discounts;
  final String? selectedId;

  @override
  State<_EntryDiscountDialog> createState() => _EntryDiscountDialogState();
}

class _EntryDiscountDialogState extends State<_EntryDiscountDialog> {
  static const _gap = 8.0;
  static const _minTileWidth = 150.0;
  static const _searchFrom = 9;

  String _query = '';

  bool _isFree(Discount d) => d.kind == DiscountKind.percent && d.value >= 100;

  /// Biggest first, then by name — "50%" never hides between two "30%".
  int _byValueThenName(Discount a, Discount b) {
    final byValue = b.value.compareTo(a.value);
    return byValue != 0
        ? byValue
        : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  List<(String, List<Discount>)> _sections(AppLocalization l10n) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final d in widget.discounts)
        if (q.isEmpty || d.name.toLowerCase().contains(q)) d,
    ]..sort(_byValueThenName);
    final free = shown.where(_isFree).toList();
    final percent = shown
        .where((d) => d.kind == DiscountKind.percent && !_isFree(d))
        .toList();
    final fixed = shown.where((d) => d.kind == DiscountKind.fixed).toList();
    return [
      if (free.isNotEmpty) (l10n.discountGroupFree, free),
      if (percent.isNotEmpty) (l10n.discountGroupPercent, percent),
      if (fixed.isNotEmpty) (l10n.discountGroupFixed, fixed),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = (screen.width - 48).clamp(280.0, 640.0);
    final maxHeight = (screen.height - 48).clamp(240.0, 600.0);
    final sections = _sections(l10n);
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
                  Expanded(child: Text(l10n.discount, style: p.heading)),
                  IconButton(
                    tooltip: l10n.cancel,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(PhosphorIconsRegular.x, color: p.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              if (widget.discounts.length >= _searchFrom) ...[
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('discount-search'),
                  style: p.body,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.discountSearchHint,
                    prefixIcon: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 18,
                      color: p.textMuted,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
              const SizedBox(height: 8),
              Flexible(
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Whole columns that each stay >= _minTileWidth wide.
                    final columns =
                        ((box.maxWidth + _gap) / (_minTileWidth + _gap))
                            .floor()
                            .clamp(1, 4);
                    final tileWidth =
                        (box.maxWidth - _gap * (columns - 1)) / columns;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (title, group) in sections) ...[
                            _SectionHeader(title: title),
                            Wrap(
                              spacing: _gap,
                              runSpacing: _gap,
                              children: [
                                for (final discount in group)
                                  SizedBox(
                                    width: tileWidth,
                                    child: DiscountTile(
                                      title: discount.name,
                                      amount:
                                          discount.kind == DiscountKind.percent
                                          ? '${discount.value}%'
                                          : formatUzs(discount.value),
                                      selected:
                                          discount.id == widget.selectedId,
                                      onTap: () => Navigator.of(
                                        context,
                                      ).pop((id: discount.id)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (widget.selectedId != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.danger,
                    side: BorderSide(color: p.danger),
                    minimumSize: const Size(0, 44),
                  ),
                  icon: const Icon(PhosphorIconsRegular.x, size: 16),
                  label: Text(l10n.noDiscount),
                  onPressed: () => Navigator.of(context).pop((id: null)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Foizli ────────" — a label plus a hairline, so the groups read apart.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text(title, style: p.kicker),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: p.border)),
        ],
      ),
    );
  }
}

/// One discount as a tappable tile — name on top, amount (blue) below.
class DiscountTile extends StatelessWidget {
  const DiscountTile({
    super.key,
    required this.title,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Material(
      color: selected ? p.accentSoft : p.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? p.accent : p.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: p.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(amount, style: p.heading.copyWith(color: p.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
