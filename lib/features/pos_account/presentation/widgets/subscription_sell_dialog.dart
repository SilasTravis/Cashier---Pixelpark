import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../domain/customer.dart';
import '../../domain/subscription.dart';
import '../bloc/pos_account_bloc.dart';
import 'balance_switch.dart';
import 'plan_conflict_dialog.dart' show checkoutCollectUzs;
import 'subscription_widgets.dart';

/// The money of one subscription sale, split exactly like the main
/// checkout splits its top-up: with "Balansdan yechish" on the balance pays
/// first and only the shortfall is collected; off, the whole price is
/// collected (credited, then debited right back). The collected amount is
/// divided over Naqd / Karta / Aralash by the shared [PaymentSplit].
class SubscriptionPayment {
  const SubscriptionPayment({
    required this.priceUzs,
    required this.collectUzs,
    required this.fromBalanceUzs,
    required this.topupCashUzs,
    required this.topupCardUzs,
    required this.isValid,
  });

  final int priceUzs;

  /// "Yetishmayotgan summa" — what the cashier takes in cash/card.
  final int collectUzs;

  /// The part the balance pays.
  final int fromBalanceUzs;

  /// Sent as `topupCashUzs` / `topupCardUzs`.
  final int topupCashUzs;
  final int topupCardUzs;

  /// Nothing to collect, or the split adds up.
  final bool isValid;

  static SubscriptionPayment compute({
    required int priceUzs,
    required int balanceUzs,
    required bool payFromBalance,
    required PaymentMethod method,
    String cashInput = '',
    String cardInput = '',
  }) {
    final collect = checkoutCollectUzs(
      neededUzs: priceUzs,
      balanceUzs: balanceUzs,
      payFromBalance: payFromBalance,
    );
    final split = PaymentSplit.compute(
      method: method,
      totalUzs: collect,
      cashInput: cashInput,
      cardInput: cardInput,
    );
    final valid = priceUzs > 0 && (collect == 0 || split.isValid);
    return SubscriptionPayment(
      priceUzs: priceUzs,
      collectUzs: collect,
      fromBalanceUzs: math.max(0, priceUzs - collect),
      topupCashUzs: collect == 0 ? 0 : split.cashUzs,
      topupCardUzs: collect == 0 ? 0 : split.cardUzs,
      isValid: valid,
    );
  }
}

/// What a successful sale hands back to the customer page for printing.
typedef SubscriptionSellOutcome = ({
  SubscriptionSaleResult sale,
  String childName,
  SellableSubscriptionPlan? plan,
});

/// Opens "Obuna sotish". Resolves with the sale once it went through (the
/// caller prints the receipt + sticker), null when cancelled.
Future<SubscriptionSellOutcome?> showSubscriptionSellDialog(
  BuildContext context,
) {
  final bloc = context.read<PosAccountBloc>()
    ..add(const PosAccountSellableSubscriptionsRequested());
  final theme = Theme.of(context);
  return showDialog<SubscriptionSellOutcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: BlocProvider.value(
        value: bloc,
        child: const SubscriptionSellDialog(),
      ),
    ),
  );
}

/// Maps the sale's refusal codes to cashier text; anything else shows the
/// server's own (Uzbek) message.
String subscriptionSaleErrorText(
  AppLocalization l10n,
  String? code,
  String? message,
) {
  if (code == 'SUBSCRIPTION_ALREADY_ACTIVE') {
    return l10n.subscriptionAlreadyActive;
  }
  if (code != null && code.contains('INSUFFICIENT')) {
    return l10n.subscriptionInsufficient;
  }
  return message ?? l10n.subscriptionInsufficient;
}

class SubscriptionSellDialog extends StatefulWidget {
  const SubscriptionSellDialog({super.key});

  @override
  State<SubscriptionSellDialog> createState() => _SubscriptionSellDialogState();
}

class _SubscriptionSellDialogState extends State<SubscriptionSellDialog> {
  String? _childId;
  String? _planId;
  bool _useToday = true;
  bool _payFromBalance = true;
  PaymentMethod _method = PaymentMethod.cash;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();
  bool _submitted = false;
  String? _error;

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
    return BlocConsumer<PosAccountBloc, PosAccountState>(
      listenWhen: (previous, current) =>
          _submitted && previous.isBusy && !current.isBusy,
      listener: (context, state) {
        _submitted = false;
        final sale = state.lastSubscriptionSale;
        if (sale != null) {
          final child = state.selectedCustomer?.children
              .where((c) => c.id == sale.subscription.childId)
              .firstOrNull;
          Navigator.of(context).pop<SubscriptionSellOutcome>((
            sale: sale,
            childName: child?.fullName ?? '',
            plan: state.sellableSubscriptions
                .where((plan) => plan.id == _planId)
                .firstOrNull,
          ));
          return;
        }
        setState(
          () => _error = subscriptionSaleErrorText(
            l10n,
            state.errorCode,
            state.errorMessage,
          ),
        );
      },
      builder: (context, state) {
        final customer = state.selectedCustomer;
        if (customer == null) return const SizedBox.shrink();
        final liveByChild = {for (final s in state.subscriptions) s.childId: s};
        final childId =
            _childId ??
            customer.children
                .where((c) => !liveByChild.containsKey(c.id))
                .firstOrNull
                ?.id;
        final plans = state.sellableSubscriptions;
        final plan =
            plans.where((pl) => pl.id == _planId).firstOrNull ??
            plans.firstOrNull;
        final child = customer.children
            .where((c) => c.id == childId)
            .firstOrNull;
        final payment = SubscriptionPayment.compute(
          priceUzs: plan?.priceUzs ?? 0,
          balanceUzs: customer.balance,
          payFromBalance: _payFromBalance,
          method: _method,
          cashInput: _cashController.text,
          cardInput: _cardController.text,
        );
        final canSubmit =
            !state.isBusy && child != null && plan != null && payment.isValid;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.ticket,
                        color: p.subscription,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.subscriptionSell,
                        style: p.title.copyWith(fontSize: 19),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.subscriptionSellSubtitle,
                    style: p.bodyMuted.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label(p, l10n.subscriptionWhichChild),
                          _children(p, l10n, customer, liveByChild, childId),
                          const SizedBox(height: 14),
                          _label(p, l10n.subscriptionType),
                          _plans(p, l10n, state, plan),
                          const SizedBox(height: 10),
                          _useTodayRow(p, l10n),
                          if (plan != null && child != null) ...[
                            const SizedBox(height: 12),
                            Divider(color: p.border, height: 1),
                            const SizedBox(height: 12),
                            _payment(p, l10n, customer, child, plan, payment),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              key: const ValueKey('subscription-sell-error'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: p.dangerSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: p.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: state.isBusy
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(l10n.cancel),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 52,
                          child: FilledButton(
                            key: const ValueKey('subscription-sell-submit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: p.subscription,
                              foregroundColor: p.onAccent,
                            ),
                            onPressed: canSubmit
                                ? () => _submit(child.id, plan.id, payment)
                                : null,
                            child: state.isBusy
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: p.onAccent,
                                    ),
                                  )
                                : FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      payment.collectUzs > 0
                                          ? l10n.subscriptionSellSubmit(
                                              formatUzs(payment.collectUzs),
                                            )
                                          : l10n.subscriptionSell,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _submit(String childId, String planId, SubscriptionPayment payment) {
    setState(() {
      _submitted = true;
      _error = null;
    });
    context.read<PosAccountBloc>().add(
      PosAccountSubscriptionSellRequested(
        childId: childId,
        subscriptionPlanId: planId,
        topupCashUzs: payment.topupCashUzs,
        topupCardUzs: payment.topupCardUzs,
        useToday: _useToday,
      ),
    );
  }

  Widget _label(PosPalette p, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: p.heading.copyWith(fontSize: 13.5)),
  );

  Widget _children(
    PosPalette p,
    AppLocalization l10n,
    Customer customer,
    Map<String, CustomerSubscription> liveByChild,
    String? selectedId,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final child in customer.children)
          SizedBox(
            width: 186,
            child: _RadioTile(
              key: ValueKey('subscription-child-${child.id}'),
              selected: child.id == selectedId,
              enabled: !liveByChild.containsKey(child.id),
              onTap: () => setState(() {
                _childId = child.id;
                _error = null;
              }),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      child.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: p.heading.copyWith(
                        fontSize: 14,
                        color: liveByChild.containsKey(child.id)
                            ? p.textMuted
                            : p.text,
                      ),
                    ),
                  ),
                  if (liveByChild[child.id] case final live?)
                    SubscriptionPill(
                      icon: false,
                      label: l10n.subscriptionHas(
                        live.entriesLeft,
                        live.entriesTotal,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _plans(
    PosPalette p,
    AppLocalization l10n,
    PosAccountState state,
    SellableSubscriptionPlan? selected,
  ) {
    if (state.isLoadingSellableSubscriptions &&
        state.sellableSubscriptions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (state.sellableSubscriptions.isEmpty) {
      return Text(
        l10n.subscriptionNoPlans,
        style: p.bodyMuted.copyWith(fontSize: 12.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final plan in state.sellableSubscriptions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RadioTile(
              key: ValueKey('subscription-plan-${plan.id}'),
              selected: plan.id == selected?.id,
              onTap: () => setState(() {
                _planId = plan.id;
                _error = null;
              }),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: p.heading.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            l10n.subscriptionEntries(plan.entriesCount),
                            if (plan.validityDays > 0)
                              l10n.subscriptionDays(plan.validityDays),
                            subscriptionLimitLabel(
                              l10n,
                              plan.limitKind,
                              plan.limitCount,
                            ),
                            if (plan.kidsPlan case final here?)
                              l10n.subscriptionHere(here.name),
                          ].join(' · '),
                          style: p.bodyMuted.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatUzs(plan.priceUzs),
                        style: p.heading.copyWith(
                          fontSize: 16,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (plan.perEntryUzs != null)
                        Text(
                          [
                            l10n.subscriptionPerEntry(
                              groupDigits(plan.perEntryUzs!),
                            ),
                            if ((plan.savingsPercent ?? 0) > 0)
                              '−${plan.savingsPercent!.round()}%',
                          ].join(' · '),
                          style: AppTextStyles.body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: p.positive,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _useTodayRow(PosPalette p, AppLocalization l10n) => Material(
    color: p.subscriptionSoft,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _useToday = !_useToday),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Checkbox(
              key: const ValueKey('subscription-use-today'),
              value: _useToday,
              activeColor: p.subscription,
              onChanged: (v) => setState(() => _useToday = v ?? false),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    color: p.subscription,
                  ),
                  children: [
                    TextSpan(
                      text: l10n.subscriptionUseToday,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' — ${l10n.subscriptionUseTodayHint}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _payment(
    PosPalette p,
    AppLocalization l10n,
    Customer customer,
    Child child,
    SellableSubscriptionPlan plan,
    SubscriptionPayment payment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${child.fullName} · ${plan.name}',
                overflow: TextOverflow.ellipsis,
                style: p.bodyMuted.copyWith(fontSize: 13),
              ),
            ),
            Text(
              formatUzs(plan.priceUzs),
              style: p.heading.copyWith(fontSize: 15),
            ),
          ],
        ),
        if (customer.balance > 0) ...[
          const SizedBox(height: 10),
          BalanceSwitch(
            value: _payFromBalance,
            balance: customer.balance,
            onChanged: (v) => setState(() {
              _payFromBalance = v;
              _error = null;
            }),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              l10n.subscriptionShortfall,
              style: p.body.copyWith(fontSize: 14),
            ),
            const Spacer(),
            Text(
              formatUzs(payment.collectUzs),
              key: const ValueKey('subscription-collect'),
              style: AppTextStyles.h3.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: payment.collectUzs == 0 ? p.positive : p.text,
              ),
            ),
          ],
        ),
        if (payment.collectUzs > 0) ...[
          const SizedBox(height: 10),
          PaymentMethodPills(
            selected: _method,
            onChanged: (m) => setState(() {
              // Same as the checkout: "Aralash" starts as all-cash.
              if (m == PaymentMethod.split &&
                  _cashController.text.isEmpty &&
                  _cardController.text.isEmpty) {
                _cashController.text = groupDigits(payment.collectUzs);
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
              split: PaymentSplit.compute(
                method: _method,
                totalUzs: payment.collectUzs,
                cashInput: _cashController.text,
                cardInput: _cardController.text,
              ),
              totalUzs: payment.collectUzs,
              onChanged: () => setState(() {}),
              autoComplete: true,
            ),
          ],
        ],
      ],
    );
  }
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(12);
    final on = selected && enabled;
    return Material(
      color: on ? p.subscriptionSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: on ? p.subscription : p.border,
          width: on ? 2 : 1.5,
        ),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                on
                    ? PhosphorIconsFill.radioButton
                    : PhosphorIconsRegular.circle,
                size: 20,
                color: on
                    ? p.subscription
                    : (enabled ? p.borderStrong : p.border),
              ),
              const SizedBox(width: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
