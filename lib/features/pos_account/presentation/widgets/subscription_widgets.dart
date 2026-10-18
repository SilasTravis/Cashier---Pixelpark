import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../domain/subscription.dart';

/// Small "Obuna" pieces of the customer page. Kept out of the (large)
/// customer detail panel: a customer without subscriptions renders none of
/// them, so the page stays exactly as before.

/// Why a child's subscription can't be used at this till today.
String subscriptionBlockedText(
  AppLocalization l10n,
  CustomerSubscription subscription,
) => switch (subscription.blockedReason) {
  SubscriptionBlockedReason.notMappedHere => l10n.subscriptionBlockedNotHere,
  SubscriptionBlockedReason.usedToday => l10n.subscriptionBlockedUsedToday,
  SubscriptionBlockedReason.weeklyLimit => l10n.subscriptionBlockedWeekly,
  _ when !subscription.usableHere => l10n.subscriptionBlockedNotHere,
  _ => l10n.subscriptionBlockedOther,
};

/// The second line under the chip: "17.11.2026 gacha · bugun bepul",
/// "Bugun faollashadi → 30 kun", or the blocked reason.
String subscriptionHintText(
  AppLocalization l10n,
  CustomerSubscription subscription,
) {
  if (!subscription.usable) return subscriptionBlockedText(l10n, subscription);
  final last = subscription.lastValidDay;
  if (subscription.isActivated && last != null) {
    return l10n.subscriptionUntilFree(_dmy(last));
  }
  final days = subscription.validityDays;
  return days == null || days <= 0
      ? l10n.subscriptionActivatesToday
      : l10n.subscriptionActivatesTodayDays(days);
}

/// dd.MM.yyyy without locale data — numeric only, so it needs no
/// `initializeDateFormatting` for any UI locale.
String _dmy(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.${date.year}';

/// "kuniga 1" / "haftasiga 2" / "cheklovsiz".
String subscriptionLimitLabel(
  AppLocalization l10n,
  SubscriptionLimitKind kind,
  int? count,
) => switch (kind) {
  SubscriptionLimitKind.perDay => l10n.subscriptionLimitPerDay,
  SubscriptionLimitKind.perWeek => l10n.subscriptionLimitPerWeek(count ?? 1),
  SubscriptionLimitKind.none => l10n.subscriptionLimitNone,
};

/// The violet pill: ticket icon + text. [muted] greys it out (subscription
/// exists but is not usable now, or the cashier chose "Obunasiz sotish").
class SubscriptionPill extends StatelessWidget {
  const SubscriptionPill({
    super.key,
    required this.label,
    this.muted = false,
    this.icon = true,
  });

  final String label;
  final bool muted;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final fg = muted ? p.textMuted : p.subscription;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? p.surfaceMuted : p.subscriptionSoft,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon) ...[
            Icon(PhosphorIconsRegular.ticket, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// On a child's tile: "VIP 5 kirish · 3/5 qoldi" + the hint line.
class SubscriptionChildBadge extends StatelessWidget {
  const SubscriptionChildBadge({
    super.key,
    required this.subscription,
    this.skipped = false,
  });

  final CustomerSubscription subscription;

  /// "Obunasiz sotish" is on for this stop — shown, but greyed.
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final muted = skipped || !subscription.usable;
    return Column(
      key: ValueKey('subscription-badge-${subscription.childId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SubscriptionPill(
          label: l10n.subscriptionChip(
            subscription.name,
            subscription.entriesLeft,
            subscription.entriesTotal,
          ),
          muted: muted,
        ),
        const SizedBox(height: 3),
        Text(
          skipped && subscription.usable
              ? l10n.subscriptionSkipped
              : subscriptionHintText(l10n, subscription),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: p.bodyMuted.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

/// The tariff step's one-line violet hint while subscription children are
/// selected, with the "Obunasiz sotish" toggle for this stop.
class SubscriptionTariffHint extends StatelessWidget {
  const SubscriptionTariffHint({
    super.key,
    required this.subscriptionNames,
    required this.paidNames,
    required this.skipped,
    required this.onToggleSkipped,
  });

  /// Selected children who enter on their subscription.
  final List<String> subscriptionNames;

  /// Selected children who still need a tariff.
  final List<String> paidNames;
  final bool skipped;
  final VoidCallback onToggleSkipped;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final text = skipped
        ? l10n.subscriptionSkipped
        : paidNames.isEmpty
        ? l10n.subscriptionTariffHintAll(subscriptionNames.join(', '))
        : l10n.subscriptionTariffHintSome(
            subscriptionNames.join(', '),
            paidNames.join(', '),
          );
    return Row(
      key: const ValueKey('subscription-tariff-hint'),
      children: [
        Icon(
          PhosphorIconsRegular.ticket,
          size: 15,
          color: skipped ? p.textMuted : p.subscription,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: skipped ? p.textMuted : p.subscription,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey('subscription-skip-toggle'),
          onPressed: onToggleSkipped,
          style: TextButton.styleFrom(
            foregroundColor: p.subscription,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            skipped ? l10n.subscriptionUseAgain : l10n.subscriptionSellWithout,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

/// One subscription child of the checkout: name, the plan it gets here.
typedef SubscriptionCheckoutLine = ({
  String childName,
  String planLabel,
  CustomerSubscription subscription,
});

/// The checkout lines of subscription children — "Samira · VIP [obuna]
/// 0 so'm" — and the "Obunadan yechiladi: Samira 3 → 2" box.
class SubscriptionCheckoutBlock extends StatelessWidget {
  const SubscriptionCheckoutBlock({super.key, required this.lines});

  final List<SubscriptionCheckoutLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final startsToday = lines.any((l) => !l.subscription.isActivated);
    return Column(
      key: const ValueKey('subscription-checkout-block'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '${line.childName} · ${line.planLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: p.bodyMuted.copyWith(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 6),
                SubscriptionPill(label: l10n.subscriptionTag, icon: false),
                const Spacer(),
                Text(
                  formatUzs(0),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: p.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: p.subscriptionSoft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: p.subscriptionBorder),
          ),
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.body.copyWith(
                fontSize: 12.5,
                color: p.subscription,
              ),
              children: [
                TextSpan(text: '${l10n.subscriptionDeducts} '),
                TextSpan(
                  text: [
                    for (final line in lines)
                      l10n.subscriptionDeductLine(
                        line.childName,
                        line.subscription.entriesLeft,
                        line.subscription.entriesLeft - 1,
                      ),
                  ].join(' · '),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (startsToday)
                  TextSpan(text: ' (${l10n.subscriptionStartsToday})'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The top-bar "Obuna sotish" button — outlined violet. Null [onPressed]
/// disables it ([disabledReason] as tooltip, e.g. offline).
class SellSubscriptionButton extends StatelessWidget {
  const SellSubscriptionButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.disabledReason,
  });

  final VoidCallback? onPressed;
  final bool compact;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final style = OutlinedButton.styleFrom(
      foregroundColor: p.subscription,
      side: BorderSide(
        color: onPressed == null ? p.border : p.subscriptionBorder,
        width: 1.5,
      ),
    );
    const icon = Icon(PhosphorIconsRegular.ticket, size: 16);
    final button = compact
        ? IconButton.outlined(
            key: const ValueKey('sell-subscription-button'),
            tooltip: l10n.subscriptionSell,
            onPressed: onPressed,
            style: style,
            icon: icon,
          )
        : SizedBox(
            height: 40,
            child: OutlinedButton.icon(
              key: const ValueKey('sell-subscription-button'),
              onPressed: onPressed,
              style: style,
              icon: icon,
              label: Text(l10n.subscriptionSell),
            ),
          );
    if (onPressed == null && disabledReason != null) {
      return Tooltip(message: disabledReason!, child: button);
    }
    return button;
  }
}
