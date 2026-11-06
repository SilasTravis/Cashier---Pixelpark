import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';

/// "Tarifga kiradi": the package's items as they were when it was sold.
class IncludesBlock extends StatelessWidget {
  const IncludesBlock({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.birthdayIncludes.toUpperCase(), style: p.kicker),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final item in items)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.check, size: 15, color: p.positive),
                  const SizedBox(width: 4),
                  Text(item, style: p.body.copyWith(fontSize: 14)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Price, net paid and the amber "Qoldi" (or the cancel reason).
class PartySummary extends StatelessWidget {
  const PartySummary({super.key, required this.party});

  final BirthdayParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final net = party.paidUzs - party.refundedUzs;
    final cancelled = party.status == BirthdayPartyStatus.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(p, l10n.birthdayTotal, formatUzs(party.agreedPriceUzs)),
        if (party.discountUzs > 0)
          _row(
            p,
            l10n.discount,
            '−${formatUzs(party.discountUzs)}',
            key: const ValueKey('bd-discount'),
          ),
        _row(p, l10n.bdPaidNet, formatUzs(net)),
        if (party.keptUzs > 0)
          _row(
            p,
            l10n.bdKeptLabel,
            formatUzs(party.keptUzs),
            key: const ValueKey('bd-kept'),
          ),
        const SizedBox(height: 8),
        if (cancelled)
          Text(
            l10n.bdCancelledReason(party.cancelReason ?? ''),
            style: TextStyle(color: p.danger, fontWeight: FontWeight.w600),
          )
        else if (party.debtUzs > 0)
          Container(
            key: const ValueKey('bd-left'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.bdLeft, style: p.heading.copyWith(color: p.warning)),
                Text(
                  formatUzs(party.debtUzs),
                  style: p.title.copyWith(fontSize: 24, color: p.warning),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(PosPalette p, String label, String value, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: p.bodyMuted),
        Text(value, style: p.body.copyWith(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
