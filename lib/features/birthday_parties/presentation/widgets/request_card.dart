import 'package:flutter/material.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_plan.dart';
import '../model/request_money.dart';

/// One parent request in the Tadbirlar "So'rovlar" section: amber, with the
/// money split and the two decisions.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.party,
    required this.onConfirm,
    required this.onReject,
  });

  final BirthdayParty party;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final tier = colorOf(party.planColor, p.accent);
    final child = party.childName;
    final kids = party.extraChildren > 0
        ? '${party.childCount} + ${party.extraChildren}'
        : '${party.childCount}';
    return Container(
      key: ValueKey('bd-request-${party.id}'),
      decoration: BoxDecoration(
        color: p.warningSoft,
        border: Border.all(color: p.warning.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        party.customerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tier.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        party.planName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tier,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    party.customerPhone,
                    if (child != null && child.isNotEmpty) child,
                    partyDateLabel(party.partyDate),
                    '$kids ${l10n.eventsChildUnit}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 13, color: p.textMuted),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 18,
                  children: [
                    _amount(
                      p,
                      l10n.bdRequestPaidInApp,
                      requestRefundUzs(party),
                    ),
                    _amount(p, l10n.bdRequestCashLeft, party.debtUzs),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            key: ValueKey('bd-request-reject-${party.id}'),
            style: OutlinedButton.styleFrom(foregroundColor: p.danger),
            onPressed: onReject,
            child: Text(l10n.bdRequestReject),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: ValueKey('bd-request-confirm-${party.id}'),
            onPressed: onConfirm,
            child: Text(l10n.bdRequestConfirm),
          ),
        ],
      ),
    );
  }

  Widget _amount(PosPalette p, String label, int uzs) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(color: p.textMuted),
        ),
        TextSpan(
          text: formatUzs(uzs),
          style: TextStyle(fontWeight: FontWeight.w700, color: p.text),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13),
  );
}
