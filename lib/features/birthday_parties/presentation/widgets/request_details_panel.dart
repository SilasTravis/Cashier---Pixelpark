import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_plan.dart';
import '../model/event_groups.dart';
import '../model/request_details.dart';
import 'birthday_ui.dart';

/// "Batafsil": a side panel over the Tadbirlar page with everything the
/// parent asked for. Its Rad etish / Tasdiqlash close the panel and then run
/// the same flows as the card's own buttons.
Future<void> showRequestDetailsPanel(
  BuildContext context,
  BirthdayParty party, {
  required VoidCallback onConfirm,
  required VoidCallback onReject,
}) async {
  final theme = Theme.of(context);
  final action = await showGeneralDialog<_PanelAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x610F172A),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, _, _) => Theme(
      data: theme,
      child: Align(
        alignment: Alignment.centerRight,
        child: RequestDetailsPanel(party: party),
      ),
    ),
    transitionBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(0.35, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: animation, child: child),
    ),
  );
  switch (action) {
    case _PanelAction.confirm:
      onConfirm();
    case _PanelAction.reject:
      onReject();
    case null:
      break;
  }
}

enum _PanelAction { confirm, reject }

class RequestDetailsPanel extends StatelessWidget {
  const RequestDetailsPanel({super.key, required this.party, this.now});

  final BirthdayParty party;

  /// The clock for "N daqiqa oldin" and "N kundan keyin"; tests pin it.
  final DateTime? now;

  static const width = 520.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final navigator = Navigator.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): navigator.pop,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          key: const ValueKey('bd-details-panel'),
          color: p.surface,
          elevation: 12,
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(party: party, now: now ?? DateTime.now()),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                    children: [
                      _PartyBlock(party: party, now: now),
                      const SizedBox(height: 14),
                      _PackageBlock(party: party),
                      const SizedBox(height: 14),
                      _PaymentBlock(party: party),
                      if (party.comments.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _CommentsBlock(party: party),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          key: const ValueKey('bd-details-reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.danger,
                            side: BorderSide(
                              color: p.danger.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: () => navigator.pop(_PanelAction.reject),
                          child: Text(l10n.bdRequestReject),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 48,
                        child: FilledButton.icon(
                          key: const ValueKey('bd-details-confirm'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          onPressed: () => navigator.pop(_PanelAction.confirm),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: Text(l10n.bdRequestConfirm),
                        ),
                      ),
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

class _Header extends StatelessWidget {
  const _Header({required this.party, required this.now});
  final BirthdayParty party;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final from = party.source == 'app'
        ? l10n.bdDetailsFromApp
        : l10n.bdDetailsFromTill;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.customerLabel,
                      style: p.title.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${party.customerPhone} · $from, '
                      '${agoLabel(l10n, party.createdAt, now)}',
                      style: p.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: const ValueKey('bd-details-close'),
                tooltip: l10n.bdClose,
                style: IconButton.styleFrom(
                  backgroundColor: p.surfaceMuted,
                  foregroundColor: p.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.warningSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_top_rounded, size: 13, color: p.warning),
                const SizedBox(width: 4),
                Text(
                  l10n.bdDetailsAwaiting,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A bordered block with an uppercase kicker title.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children, super.key});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _PartyBlock extends StatelessWidget {
  const _PartyBlock({required this.party, this.now});
  final BirthdayParty party;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final date = ymdParts(party.partyDate);
    final child = party.childName?.trim();
    final hasChild = child != null && child.isNotEmpty;
    final birth = party.childBirthDate;
    final age = turningAge(birth, party.partyDate);
    final today = now == null ? null : tashkentToday(now);
    return _Block(
      key: const ValueKey('bd-details-party'),
      title: l10n.bdDetailsParty,
      children: [
        Row(
          children: [
            if (date != null) ...[
              Container(
                width: 58,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.surface,
                  border: Border.all(color: p.borderStrong),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      color: p.danger,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      alignment: Alignment.center,
                      child: Text(
                        monthShort(l10n, date.month),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 4),
                      child: Text(
                        '${date.day}',
                        style: tabular(
                          TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: p.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayDateLabel(l10n, party.partyDate),
                    style: p.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      daysAwayLabel(l10n, party.partyDate, today),
                      party.branchName,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: p.bodyMuted.copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (hasChild) ...[
          const SizedBox(height: 10),
          Row(
            key: const ValueKey('bd-details-child'),
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFDE68A), Color(0xFFF9A8D4)],
                  ),
                ),
                child: Text(
                  child.characters.first.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF7C2D12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child,
                      style: p.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (birth != null)
                      Text(
                        l10n.bdChildBirthDate(partyDateLabel(birth)),
                        style: p.bodyMuted.copyWith(fontSize: 13),
                      ),
                  ],
                ),
              ),
              if (age != null && age > 0)
                Container(
                  key: const ValueKey('bd-details-age'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '🎂 ${l10n.bdTurnsAge(age)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: p.accentStrong,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.total = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool total;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: total
                  ? p.body.copyWith(fontWeight: FontWeight.w700)
                  : p.bodyMuted,
            ),
          ),
          Text(
            value,
            style: tabular(
              p.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: total ? 16 : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageBlock extends StatelessWidget {
  const _PackageBlock({required this.party});
  final BirthdayParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final tier = colorOf(party.planColor, p.accent);
    return _Block(
      key: const ValueKey('bd-details-package'),
      title: l10n.bdDetailsPackage,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                party.planName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tierInk(context, tier),
                ),
              ),
            ),
            Text(
              party.extraChildren > 0
                  ? l10n.bdKidsWithExtra(party.childCount, party.extraChildren)
                  : l10n.bdKidsCount(party.childCount),
              style: p.bodyMuted,
            ),
          ],
        ),
        if (party.includedItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final item in party.includedItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 16, color: p.positive),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: p.bodyMuted.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 4),
        _MoneyRow(
          label: l10n.bdPackageLine(party.childCount),
          value: groupDigits(party.packagePriceUzs),
        ),
        if (party.extraChildren > 0)
          _MoneyRow(
            label: l10n.bdExtraChildLine(
              party.extraChildren,
              groupDigits(party.extraChildUzs),
            ),
            value: groupDigits(party.extraChildren * party.extraChildUzs),
          ),
        if (party.discountUzs > 0)
          _MoneyRow(
            label: l10n.bdDiscountLine,
            value: '−${groupDigits(party.discountUzs)}',
            valueColor: p.positive,
          ),
        const SizedBox(height: 8),
        _DashedLine(color: p.borderStrong),
        const SizedBox(height: 2),
        _MoneyRow(
          label: l10n.bdTotalLine,
          value: formatUzs(party.agreedPriceUzs),
          total: true,
        ),
      ],
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final n = (c.maxWidth / 7).floor();
      return Row(
        children: [
          for (var i = 0; i < n; i++)
            Container(
              width: 4,
              height: 1,
              margin: const EdgeInsets.only(right: 3),
              color: color,
            ),
        ],
      );
    },
  );
}

class _PaymentBlock extends StatelessWidget {
  const _PaymentBlock({required this.party});
  final BirthdayParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final split = RequestPaidSplit.of(party);
    final tiles = <(String, int, String)>[
      if (split.balanceUzs > 0)
        (l10n.bdPaidFromBalance, split.balanceUzs, 'balance'),
      if (split.cardUzs > 0) (l10n.bdPaidCard, split.cardUzs, 'card'),
      if (split.clickUzs > 0) ('Click', split.clickUzs, 'click'),
      if (split.paymeUzs > 0) ('Payme', split.paymeUzs, 'payme'),
      if (split.otherOnlineUzs > 0)
        (l10n.bdRequestPaidInApp, split.otherOnlineUzs, 'online'),
      if (split.totalUzs == 0) (l10n.bdNothingPaidInApp, 0, 'none'),
    ];
    return _Block(
      key: const ValueKey('bd-details-payment'),
      title: l10n.bdDetailsPayment,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 16) / 3;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in tiles)
                  _PayTile(
                    key: ValueKey('bd-details-pay-${t.$3}'),
                    width: w,
                    label: t.$1,
                    uzs: t.$2,
                    fill: p.surfaceMuted,
                  ),
                _PayTile(
                  key: const ValueKey('bd-details-pay-cash'),
                  width: w,
                  label: l10n.bdCashAtTill,
                  uzs: party.debtUzs,
                  fill: p.warningSoft,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PayTile extends StatelessWidget {
  const _PayTile({
    super.key,
    required this.width,
    required this.label,
    required this.uzs,
    required this.fill,
  });
  final double width;
  final String label;
  final int uzs;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: p.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            groupDigits(uzs),
            style: tabular(
              TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsBlock extends StatelessWidget {
  const _CommentsBlock({required this.party});
  final BirthdayParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return _Block(
      key: const ValueKey('bd-details-comments'),
      title: l10n.bdDetailsNote,
      children: [
        for (final c in party.comments)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.text, style: p.body.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(c.author, style: p.bodyMuted.copyWith(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
