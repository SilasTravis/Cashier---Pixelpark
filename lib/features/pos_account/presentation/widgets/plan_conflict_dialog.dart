import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../domain/pos_entry.dart';
import '../bloc/pos_account_bloc.dart';
import '../../../../generated/l10n.dart';

/// What the checkout panel would collect in cash/card for [neededUzs] — the
/// panel's own rule, shared with the plan-switch modal so both split money
/// the same way: with "Balansdan yechish" on the balance pays first and
/// only the shortfall is collected; with it off the whole amount is
/// collected (credited and debited right back, the balance stays as is).
int checkoutCollectUzs({
  required int neededUzs,
  required int balanceUzs,
  required bool payFromBalance,
}) {
  if (neededUzs <= 0) return 0;
  final shortfall = neededUzs - balanceUzs;
  if (shortfall <= 0) return payFromBalance ? 0 : neededUzs;
  return payFromBalance || balanceUzs <= 0 ? shortfall : neededUzs;
}

/// What the confirmed switch itself debits: per switchable child the
/// surcharge plus the settled running time. The server's conflict quotes
/// the surcharge off the LIST price, but the switch debits the child's
/// discounted price (promo / entry / check share) minus what the live pass
/// already paid — so with [netFlatByChild] (that discounted price) the
/// surcharge is recomputed as `max(0, net − credit)`, never more than
/// quoted. Older backends omit the surcharge and charge the whole
/// (discounted) new price.
int planSwitchDueUzs(
  List<PosEntryConflict> conflicts, {
  Map<String, int> netFlatByChild = const {},
  int? requestedPlanFlatUzs,
}) => conflicts.where((c) => c.switchable).fold<int>(0, (sum, c) {
  final net = netFlatByChild[c.childId];
  final quoted = c.upgradeDueUzs;
  final due = quoted == null
      ? net ?? requestedPlanFlatUzs ?? 0
      : net == null
      ? quoted
      : math.min(quoted, math.max(0, net - c.upgradeCreditUzs));
  return sum + due + c.accruedDueUzs;
});

/// The checkout press that came back with plan-switch conflicts, kept so
/// "Almashtirish" re-sends the SAME checkout (children, goods, HAMROH,
/// discounts, promo) with `replacePlan` — and knows what the rest of it
/// costs. The backend moves no money on a conflicted press, so the modal
/// collects everything then: the other children + goods + HAMROH at their
/// panel price and, for the switched children, only the surcharge.
class PlanSwitchCheckout {
  const PlanSwitchCheckout({
    required this.request,
    this.childDueUzs = const {},
    this.extrasDueUzs = 0,
    this.payFromBalance = true,
    this.payMethod = PaymentMethod.cash,
  });

  /// The first press as sent (its cash/card is ignored — the retry
  /// carries what the modal collects).
  final PosAccountCheckoutRequested request;

  /// childId → every newly-covered child's plan price net of the discount
  /// the server applies to its pass (promo / entry pick / check share). A
  /// child the server reports as a conflict is priced by its surcharge
  /// instead — see [planSwitchDueUzs].
  final Map<String, int> childDueUzs;

  /// Goods (net of their discount) + paid HAMROH stickers.
  final int extrasDueUzs;

  /// The panel's "Balansdan yechish" switch and payment method.
  final bool payFromBalance;
  final PaymentMethod payMethod;

  /// What everything but the switched children costs.
  int othersDueUzs(Iterable<String> conflictChildIds) {
    final conflicted = conflictChildIds.toSet();
    return extrasDueUzs +
        childDueUzs.entries
            .where((e) => !conflicted.contains(e.key))
            .fold<int>(0, (sum, e) => sum + e.value);
  }

  /// [request] re-sent as the confirmed switch, carrying [cashUzs] /
  /// [cardUzs] as its top-up.
  PosAccountCheckoutRequested confirmed({
    required int cashUzs,
    required int cardUzs,
  }) => PosAccountCheckoutRequested(
    planKey: request.planKey,
    childIds: request.childIds,
    products: request.products,
    cashUzs: cashUzs,
    cardUzs: cardUzs,
    withParentQr: request.withParentQr,
    entryDiscounts: request.entryDiscounts,
    companions: request.companions,
    discountId: request.discountId,
    promoCode: request.promoCode,
    checkDiscountId: request.checkDiscountId,
    replacePlan: true,
  );
}

/// The plan-switch confirmation: the child already holds today's pass on
/// ANOTHER plan, so nothing was printed and no money moved. Shows what the
/// child is on now, what the switch costs and how much to collect NOW
/// (Naqd / Karta / Aralash); "Almashtirish" re-sends the same checkout
/// ([checkout]) with `replacePlan` and exactly that amount — the backend
/// settles + kills the old pass and the fresh QR prints through the normal
/// result flow. Nothing is ever collected beyond what is debited, so no
/// surplus lands on the balance.
///
/// Downgrades arrive with `switchable == false`; there the modal instead
/// offers re-printing the CURRENT pass — the everyday reason a cashier
/// lands here is a lost sticker, and a blocked switch must not leave them
/// with no way to print at all. The re-print goes through the same
/// plan-entry request with the child's current plan, which the backend
/// answers with the existing pass (same code, old sticker keeps working,
/// no money moves). [onReprint] fires right before it is sent.
Future<void> showPlanConflictDialog(
  BuildContext context, {
  required List<PosEntryConflict> conflicts,
  required Map<String, String> childNamesById,
  required String requestedPlanName,

  /// The requested plan's flat day price when it is VIP — older backends
  /// report no surcharge and charge this full price on the switch.
  int? requestedPlanFlatUzs,

  /// Keys of the 1 soat (`flat_hour`) plans. A switchable conflict whose
  /// CURRENT plan is one of them is a live hour → VIP upgrade: the row adds
  /// that the hour price is not refunded. Empty leaves every row as before.
  Set<String> hourPlanKeys = const {},

  /// The conflicted checkout to re-send. Null re-sends a bare checkout of
  /// just the switchable children (no goods, companions or discounts).
  PlanSwitchCheckout? checkout,
  VoidCallback? onReprint,
}) {
  final bloc = context.read<PosAccountBloc>();
  final switchable = conflicts.where((c) => c.switchable).toList();
  final effective =
      checkout ??
      PlanSwitchCheckout(
        request: PosAccountCheckoutRequested(
          planKey: switchable.isEmpty
              ? null
              : switchable.first.requestedPlanKey,
          childIds: [for (final c in switchable) c.childId],
          products: const [],
          cashUzs: 0,
          cardUzs: 0,
        ),
      );
  final switchDueUzs = planSwitchDueUzs(
    conflicts,
    netFlatByChild: effective.childDueUzs,
    requestedPlanFlatUzs: requestedPlanFlatUzs,
  );
  final neededUzs =
      effective.othersDueUzs(conflicts.map((c) => c.childId)) + switchDueUzs;
  final collectUzs = checkoutCollectUzs(
    neededUzs: neededUzs,
    balanceUzs: bloc.state.selectedCustomer?.balance ?? 0,
    payFromBalance: effective.payFromBalance,
  );
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => _PlanConflictDialog(
      bloc: bloc,
      conflicts: conflicts,
      childNamesById: childNamesById,
      requestedPlanName: requestedPlanName,
      requestedPlanFlatUzs: requestedPlanFlatUzs,
      hourPlanKeys: hourPlanKeys,
      checkout: effective,
      collectUzs: collectUzs,
      onReprint: onReprint,
    ),
  );
}

class _PlanConflictDialog extends StatefulWidget {
  const _PlanConflictDialog({
    required this.bloc,
    required this.conflicts,
    required this.childNamesById,
    required this.requestedPlanName,
    required this.requestedPlanFlatUzs,
    required this.hourPlanKeys,
    required this.checkout,
    required this.collectUzs,
    required this.onReprint,
  });

  final PosAccountBloc bloc;
  final List<PosEntryConflict> conflicts;
  final Map<String, String> childNamesById;
  final String requestedPlanName;
  final int? requestedPlanFlatUzs;
  final Set<String> hourPlanKeys;
  final PlanSwitchCheckout checkout;

  /// What the cashier takes in cash/card before the switch prints.
  final int collectUzs;
  final VoidCallback? onReprint;

  @override
  State<_PlanConflictDialog> createState() => _PlanConflictDialogState();
}

class _PlanConflictDialogState extends State<_PlanConflictDialog> {
  late PaymentMethod _method = widget.checkout.payMethod;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final conflicts = widget.conflicts;
    final switchable = conflicts.where((c) => c.switchable).toList();
    // A backend that reports the surcharge charges ONLY the difference (what
    // the live pass already paid is credited) — say that sum, not the full
    // VIP price. Older backends omit it and keep the full-price wording.
    final upgradeDues = [
      for (final c in switchable)
        if (c.upgradeDueUzs != null) c.upgradeDueUzs!,
    ];
    final upgradeDueUzs = upgradeDues.length == switchable.length
        ? upgradeDues.fold<int>(0, (sum, due) => sum + due)
        : null;
    // currentPlanKey is null only when the plan row was deleted — nothing to
    // re-print against then.
    final reprintable = conflicts
        .where((c) => c.currentPlanKey != null)
        .toList();
    final collectUzs = widget.collectUzs;
    final split = PaymentSplit.compute(
      method: _method,
      totalUzs: collectUzs,
      cashInput: _cashController.text,
      cardInput: _cardController.text,
    );
    final canSwitch = collectUzs == 0 || split.isValid;
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text(
        l10n.planSwitch,
        style: AppTextStyles.h4.copyWith(color: p.text),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final conflict in conflicts) ...[
              _ConflictRow(
                conflict: conflict,
                childName:
                    widget.childNamesById[conflict.childId] ?? conflict.childId,
                fromHourPlan: widget.hourPlanKeys.contains(
                  conflict.currentPlanKey,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (switchable.isNotEmpty)
              Text(
                widget.requestedPlanFlatUzs == null
                    ? l10n.planSwitchQuestion(widget.requestedPlanName)
                    : upgradeDueUzs != null
                    // Collected now in cash/card — unless the balance pays
                    // it ("Balansdan yechish" on and it covers).
                    ? (collectUzs > 0
                          ? l10n.planSwitchUpgradeCollectQuestion(
                              widget.requestedPlanName,
                              formatUzs(upgradeDueUzs),
                            )
                          : l10n.planSwitchUpgradeQuestion(
                              widget.requestedPlanName,
                              formatUzs(upgradeDueUzs),
                            ))
                    : l10n.planSwitchVipQuestion(
                        widget.requestedPlanName,
                        formatUzs(widget.requestedPlanFlatUzs!),
                      ),
                style: p.body.copyWith(fontSize: 13),
              ),
            if (switchable.isNotEmpty && collectUzs > 0) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    l10n.planSwitchCollectNow,
                    style: p.heading.copyWith(fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    formatUzs(collectUzs),
                    key: const ValueKey('switch-collect'),
                    style: p.heading.copyWith(
                      fontSize: 18,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PaymentMethodPills(
                selected: _method,
                onChanged: (m) => setState(() {
                  // "Aralash" starts as all-cash, like the panel.
                  if (m == PaymentMethod.split &&
                      _cashController.text.isEmpty &&
                      _cardController.text.isEmpty) {
                    _cashController.text = groupDigits(collectUzs);
                    _cardController.text = '0';
                  }
                  _method = m;
                }),
              ),
              if (_method == PaymentMethod.split) ...[
                const SizedBox(height: 10),
                SplitAmountFields(
                  cashController: _cashController,
                  cardController: _cardController,
                  split: split,
                  totalUzs: collectUzs,
                  onChanged: () => setState(() {}),
                  autoComplete: true,
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (reprintable.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onReprint?.call();
              // Children may sit on different current plans — one
              // same-plan re-print request per plan key.
              final childIdsByPlan = <String, List<String>>{};
              for (final c in reprintable) {
                childIdsByPlan
                    .putIfAbsent(c.currentPlanKey!, () => [])
                    .add(c.childId);
              }
              for (final entry in childIdsByPlan.entries) {
                widget.bloc.add(
                  PosAccountPlanEntryRequested(
                    planKey: entry.key,
                    childIds: entry.value,
                  ),
                );
              }
            },
            icon: const Icon(PhosphorIconsRegular.printer, size: 16),
            label: Text(l10n.reprint),
          ),
        if (switchable.isNotEmpty)
          FilledButton.icon(
            onPressed: canSwitch
                ? () {
                    Navigator.of(context).pop();
                    widget.bloc.add(
                      widget.checkout.confirmed(
                        cashUzs: collectUzs == 0 ? 0 : split.cashUzs,
                        cardUzs: collectUzs == 0 ? 0 : split.cardUzs,
                      ),
                    );
                  }
                : null,
            icon: const Icon(PhosphorIconsRegular.printer, size: 16),
            label: Text(
              collectUzs > 0
                  ? '${l10n.switchAndPrint} · ${formatUzs(collectUzs)}'
                  : l10n.switchAndPrint,
            ),
          ),
      ],
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    required this.conflict,
    required this.childName,
    required this.fromHourPlan,
  });

  final PosEntryConflict conflict;
  final String childName;

  /// The child's live pass is a 1 soat one.
  final bool fromHourPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final details = <String>[
      l10n.currentPlanToday(
        childName,
        conflict.currentPlanLabel,
        conflict.isInside ? l10n.insideSuffix : '',
      ),
      if (!conflict.switchable) l10n.downgradeForbidden,
      if (conflict.switchable && conflict.accruedDueUzs > 0)
        l10n.accruedDue(formatUzs(conflict.accruedDueUzs)),
      // What the live pass already paid is credited: only the difference is
      // charged (1 soat 60 000 → VIP 75 000 = 15 000).
      if (conflict.switchable &&
          conflict.upgradeDueUzs != null &&
          conflict.upgradeCreditUzs > 0)
        l10n.upgradeCredit(
          formatUzs(conflict.upgradeCreditUzs),
          formatUzs(conflict.upgradeDueUzs!),
        ),
      // Older backends: live hour → VIP at the full VIP price, no refund.
      if (conflict.switchable && fromHourPlan && conflict.upgradeDueUzs == null)
        l10n.planSwitchHourToVipNote,
    ];
    final p = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            conflict.switchable
                ? PhosphorIconsRegular.arrowsClockwise
                : PhosphorIconsRegular.warning,
            size: 16,
            color: p.accentStrong,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              details.join(' '),
              style: p.body.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
