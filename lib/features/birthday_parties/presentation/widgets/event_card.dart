import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_account/presentation/widgets/account_ui.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_plan.dart';
import '../model/event_badge.dart';

/// One birthday party in the Tadbirlar list. Built to be scanned: left stripe
/// = payment state, date tile, tier, money progress, one primary action.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.party,
    required this.today,
    required this.onOpen,
  });

  final BirthdayParty party;

  /// Tashkent `YYYY-MM-DD`.
  final String today;

  /// Opens the party detail (Task C6 wires this); the card body and the
  /// primary button both call it.
  final ValueChanged<BirthdayParty> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final booked = party.status == BirthdayPartyStatus.booked;
    final due = party.partyDate.compareTo(today) <= 0;
    final isToday = party.partyDate == today;
    final badge = eventBadge(party);
    final stripe = switch (badge.stripe) {
      EventStripe.positive => p.positive,
      EventStripe.warning => p.warning,
      EventStripe.faint => p.textFaint,
      EventStripe.neutral => p.textMuted,
    };
    final net = party.paidUzs - party.refundedUzs;
    final progress = party.agreedPriceUzs <= 0
        ? 0.0
        : (net / party.agreedPriceUzs).clamp(0.0, 1.0);
    final tier = colorOf(party.planColor, p.accent);
    final kids = party.extraChildren > 0
        ? '${party.childCount} + ${party.extraChildren}'
        : '${party.childCount}';
    final (chipLabel, chipTone) = switch (badge.kind) {
      EventBadgeKind.paid => ('✓ ${l10n.eventsPaid}', ChipTone.positive),
      EventBadgeKind.debt => (
        '🔒 ${l10n.eventsDebt(groupDigits(party.debtUzs))}',
        ChipTone.warning,
      ),
      EventBadgeKind.cancelled => (l10n.bdCancelledChip, ChipTone.neutral),
      EventBadgeKind.unpaid => (l10n.eventsUnpaid, ChipTone.neutral),
    };

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpen(party),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: stripe),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: _DateTile(date: party.partyDate, highlight: isToday),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                party.customerName,
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
                            _TierChip(name: party.planName, color: tier),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$kids ${l10n.eventsChildUnit}'
                          '${party.comments.isEmpty ? '' : ' · 💬 ${party.comments.length}'}',
                          style: TextStyle(fontSize: 13, color: p.textMuted),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: p.surfaceMuted,
                            color: stripe,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(label: chipLabel, tone: chipTone),
                      if (badge.keptUzs > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.bdKeptChip(groupDigits(badge.keptUzs)),
                          key: const ValueKey('event-kept'),
                          style: TextStyle(fontSize: 12, color: p.textMuted),
                        ),
                      ],
                      if (booked) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => onOpen(party),
                          child: Text(
                            due ? l10n.eventsComplete : l10n.eventsAddPayment,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      name,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _DateTile extends StatelessWidget {
  const _DateTile({required this.date, required this.highlight});
  final String date;
  final bool highlight;

  String _month(BuildContext context, DateTime d) {
    try {
      return DateFormat.MMM(
        Localizations.localeOf(context).toString(),
      ).format(d);
    } catch (_) {
      return d.month.toString().padLeft(2, '0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final d = DateTime.utc(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(5, 7)),
      int.parse(date.substring(8, 10)),
    );
    final fg = highlight ? p.onAccent : p.text;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? p.accent : p.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: fg,
            ),
          ),
          Text(
            _month(context, d),
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
