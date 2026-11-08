import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../pos_account/domain/customer.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../../domain/birthday_plan.dart';
import '../bloc/birthday_sell_cubit.dart';
import '../birthday_recovery.dart';
import '../birthday_error_text.dart';
import 'birthday_date_field.dart';
import 'birthday_payment_block.dart';
import 'birthday_summary.dart';
import 'birthday_ui.dart';
import 'extra_children_stepper.dart';
import 'size_picker.dart';
import 'tier_picker.dart';

/// Wide enough for choices on the left and the sticky summary on the right.
const birthdaySellTwoColumnWidth = 1100.0;

/// Opens "Tug'ilgan kun sotish" as a full-window screen. Resolves with the
/// booked party (the caller prints the receipt and refreshes the customer),
/// null when cancelled.
Future<BirthdayParty?> showBirthdaySellDialog(
  BuildContext context, {
  required Customer customer,
  DateTime? today,
}) {
  final theme = Theme.of(context);
  return showGeneralDialog<BirthdayParty>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (_, _, _) => Theme(
      data: theme,
      child: BlocProvider(
        create: (_) =>
            BirthdaySellCubit(sl(), customerId: customer.id, today: today)
              ..load(),
        child: BirthdaySellDialog(customer: customer, today: today),
      ),
    ),
  );
}

class BirthdaySellDialog extends StatefulWidget {
  const BirthdaySellDialog({super.key, required this.customer, this.today});

  final Customer customer;

  /// "Today" for the date chips; the real date when null.
  final DateTime? today;

  @override
  State<BirthdaySellDialog> createState() => _BirthdaySellDialogState();
}

class _BirthdaySellDialogState extends State<BirthdaySellDialog> {
  final _totalController = TextEditingController();
  final _depositController = TextEditingController();
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  /// The close re-check could not reach the server: the sheet stays locked.
  bool _offline = false;

  @override
  void dispose() {
    _totalController.dispose();
    _depositController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  BirthdaySellCubit get _cubit => context.read<BirthdaySellCubit>();

  DateTime get _today => widget.today ?? DateTime.now();

  /// Closing after an unclear failure first asks the server whether the sale
  /// went through, and hands the party back so it is printed and the customer
  /// refreshed.
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    setState(() => _offline = false);
    final lookup = await _cubit.resolveOnClose();
    if (!mounted) return;
    if (lookup is PartyUnreachable) {
      // Cannot tell whether the sale went through: stay locked.
      setState(() => _offline = true);
      return;
    }
    navigator.pop(lookup is PartyFound ? lookup.party : null);
  }

  Future<void> _pickDate(DateTime current) async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (picked != null) _cubit.setPartyDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return BlocConsumer<BirthdaySellCubit, BirthdaySellState>(
      listenWhen: (a, b) =>
          a.listPriceUzs != b.listPriceUzs ||
          a.party != b.party ||
          (a.agreedOverrideUzs != null && b.agreedOverrideUzs == null),
      listener: (context, state) {
        if (state.party != null) {
          Navigator.of(context).pop<BirthdayParty>(state.party);
          return;
        }
        // The total field always shows what will be submitted: a re-priced sale
        // or a dropped override starts it over at the list price.
        _totalController.text = state.listPriceUzs == 0
            ? ''
            : groupDigits(state.listPriceUzs);
      },
      builder: (context, state) {
        return Material(
          color: p.bg,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  customer: widget.customer,
                  onClose: state.busy ? null : _close,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= birthdaySellTwoColumnWidth
                        ? _wide(context, state)
                        : _narrow(context, state),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Choices scroll on the left; the summary + payment stay on the right with
  /// the big button always on screen.
  Widget _wide(BuildContext context, BirthdaySellState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 20, 28),
            child: _locked(state, _choices(context, state)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 28, 24),
          child: SizedBox(
            width: 470,
            child: SoftCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                      child: _checkout(context, state),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: PosPalette.of(context).border),
                      ),
                    ),
                    child: _pinned(context, state),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One column: everything scrolls, the buttons stay pinned at the bottom.
  Widget _narrow(BuildContext context, BirthdaySellState state) {
    final p = PosPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _locked(state, _choices(context, state)),
                const SizedBox(height: 16),
                SoftCard(child: _checkout(context, state)),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: _pinned(context, state),
        ),
      ],
    );
  }

  /// After an unclear failure the amounts are frozen: a retry must be the
  /// very same sale. ExcludeFocus also takes the keyboard away from a field
  /// that still had focus.
  Widget _locked(BirthdaySellState state, Widget child) => ExcludeFocus(
    excluding: state.unclear,
    child: IgnorePointer(
      ignoring: state.unclear,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: state.unclear ? 0.55 : 1,
        child: child,
      ),
    ),
  );

  Widget _choices(BuildContext context, BirthdaySellState state) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final plan = state.plan;
    final size = state.size;
    final color = colorOf(plan?.color ?? '', p.accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftStepHeader(
                step: 1,
                title: l10n.birthdayPlan,
                hint: l10n.birthdayStepPlanHint,
                done: plan != null,
              ),
              const SizedBox(height: 16),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.plans.isEmpty)
                Text(l10n.birthdayNoPlans, style: p.bodyMuted)
              else
                TierPicker(
                  plans: state.plans,
                  selectedId: state.selectedPlanId,
                  onSelected: _cubit.selectPlan,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SoftStepHeader(
                step: 2,
                title: l10n.birthdayChildCount,
                hint: l10n.birthdayStepSizeHint,
                done: size != null,
              ),
              const SizedBox(height: 16),
              if (plan == null)
                _placeholder(p, l10n.birthdayPickPlanFirst)
              else
                SizePicker(
                  sizes: plan.sizes,
                  selected: state.childCount,
                  color: color,
                  onSelected: _cubit.selectSize,
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final date = _dateCard(l10n, state, step: size == null ? 3 : 4);
            if (size == null) return date;
            final wide = constraints.maxWidth >= 820;
            final extra = _extraCard(
              l10n,
              state,
              size.extraChildUzs,
              color,
              fill: wide,
            );
            // Side by side when there is room: the whole sale fits on one
            // screen without scrolling.
            if (wide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: extra),
                    const SizedBox(width: 14),
                    Expanded(child: date),
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [extra, const SizedBox(height: 14), date],
            );
          },
        ),
      ],
    );
  }

  Widget _extraCard(
    AppLocalization l10n,
    BirthdaySellState state,
    int extraChildUzs,
    Color color, {
    required bool fill,
  }) => SoftCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftStepHeader(
          step: 3,
          title: l10n.birthdayExtraChild,
          hint: l10n.birthdayStepExtraHint,
          done: state.extraChildren > 0,
        ),
        const SizedBox(height: 14),
        if (fill)
          Expanded(child: _stepper(state, extraChildUzs, color))
        else
          _stepper(state, extraChildUzs, color),
      ],
    ),
  );

  Widget _stepper(BirthdaySellState state, int extraChildUzs, Color color) =>
      ExtraChildrenStepper(
        count: state.extraChildren,
        extraChildUzs: extraChildUzs,
        color: color,
        onAdd: _cubit.addExtraChild,
        onRemove: _cubit.removeExtraChild,
      );

  Widget _dateCard(
    AppLocalization l10n,
    BirthdaySellState state, {
    required int step,
  }) => SoftCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftStepHeader(
          step: step,
          title: l10n.birthdayDate,
          hint: l10n.birthdayStepDateHint,
        ),
        const SizedBox(height: 14),
        BirthdayDateField(
          date: state.partyDate,
          today: _today,
          onPick: () => _pickDate(state.partyDate),
          onDate: _cubit.setPartyDate,
        ),
      ],
    ),
  );

  Widget _placeholder(PosPalette p, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: p.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(text, style: p.bodyMuted.copyWith(fontSize: 14)),
  );

  /// Right side: the breakdown + Jami, the payment, what is taken now and
  /// what stays as debt.
  Widget _checkout(BuildContext context, BirthdaySellState state) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final size = state.size;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.birthdaySummary.toUpperCase(), style: _kicker(p)),
        const SizedBox(height: 10),
        if (size == null)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 22),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.cake, size: 30, color: p.textFaint),
                const SizedBox(height: 8),
                Text(
                  l10n.birthdaySummaryEmpty,
                  textAlign: TextAlign.center,
                  style: p.bodyMuted.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          )
        else
          _locked(
            state,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BirthdaySummary(
                  state: state,
                  size: size,
                  totalController: _totalController,
                  onTotalChanged: (v) => _cubit.setAgreedPrice(parseUzs(v)),
                ),
                const SizedBox(height: 22),
                Text(l10n.birthdayPayment.toUpperCase(), style: _kicker(p)),
                const SizedBox(height: 10),
                _payment(context, state, state.payment),
              ],
            ),
          ),
      ],
    );
  }

  /// Always on screen under the checkout: an error (if any), what is taken
  /// now and what stays owed, and the two buttons.
  Widget _pinned(BuildContext context, BirthdaySellState state) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ..._errors(p, l10n, state),
        if (state.errorMessage != null || state.errorCode != null)
          const SizedBox(height: 12),
        if (state.size != null) ...[
          _moneyTiles(p, l10n, state),
          const SizedBox(height: 12),
        ],
        _footer(state),
      ],
    );
  }

  TextStyle _kicker(PosPalette p) =>
      p.kicker.copyWith(fontSize: 11, color: p.textMuted);

  Widget _payment(
    BuildContext context,
    BirthdaySellState state,
    BirthdayPayment payment,
  ) {
    final l10n = AppLocalization.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModeToggle(
          deposit: state.deposit,
          onChanged: _cubit.setDeposit,
          fullLabel: l10n.birthdayPayFull,
          depositLabel: l10n.birthdayDeposit,
        ),
        if (state.deposit) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in birthdayDepositChips)
                SoftChoicePill(
                  key: ValueKey('birthday-deposit-chip-$chip'),
                  label: groupDigits(chip),
                  selected: state.depositUzs == chip,
                  onTap: () {
                    _depositController.text = groupDigits(chip);
                    _cubit.setDepositUzs(chip);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('birthday-deposit-field'),
            controller: _depositController,
            keyboardType: TextInputType.number,
            inputFormatters: const [ThousandsInputFormatter()],
            style: tabular(
              PosPalette.of(
                context,
              ).heading.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            decoration: InputDecoration(
              isDense: true,
              labelText: l10n.birthdayDepositAmount,
              suffixText: "so'm",
              prefixIcon: const Icon(PhosphorIconsRegular.lockSimple, size: 18),
            ),
            onChanged: (v) => _cubit.setDepositUzs(parseUzs(v) ?? 0),
          ),
        ],
        const SizedBox(height: 14),
        BirthdayPaymentBlock(
          showTakeNow: false,
          payment: payment,
          wallet: state.wallet,
          walletLoading: state.walletLoading,
          payFromBalance: state.payFromBalance,
          onPayFromBalance: _cubit.setPayFromBalance,
          method: state.method,
          onMethod: _cubit.setMethod,
          cashController: _cashController,
          cardController: _cardController,
          onChanged: () => _cubit.setSplitInputs(
            cash: _cashController.text,
            card: _cardController.text,
          ),
        ),
      ],
    );
  }

  /// "Hozir olinadi" (blue) and "Qoldi" (amber, green when nothing is
  /// left) side by side — the two numbers the cashier says out loud.
  Widget _moneyTiles(
    PosPalette p,
    AppLocalization l10n,
    BirthdaySellState state,
  ) {
    final payment = state.payment;
    final collect = payment.collectUzs;
    final owed = payment.remainingAfterUzs;
    final how = collect <= 0
        ? null
        : switch (state.method) {
            PaymentMethod.cash => l10n.paymentCash,
            PaymentMethod.card => l10n.paymentCard,
            PaymentMethod.split => l10n.paymentSplit,
          };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MoneyTile(
              key: const ValueKey('bd-take-now'),
              amountKey: const ValueKey('bd-take-now-amount'),
              label: how == null ? l10n.bdTakeNow : '${l10n.bdTakeNow} · $how',
              amountUzs: collect,
              bg: p.accentSoft,
              fg: p.accent,
              amountColor: p.accentStrong,
              icon: PhosphorIconsRegular.handCoins,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MoneyTile(
              key: const ValueKey('birthday-remaining'),
              label: l10n.bdLeftBeforeParty,
              amountUzs: owed,
              bg: owed > 0 ? p.warningSoft : p.positiveSoft,
              fg: owed > 0 ? p.warning : p.positive,
              amountColor: owed > 0 ? p.warning : p.positive,
              icon: owed > 0
                  ? PhosphorIconsRegular.hourglassMedium
                  : PhosphorIconsRegular.checkCircle,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _errors(
    PosPalette p,
    AppLocalization l10n,
    BirthdaySellState state,
  ) {
    if (state.errorMessage == null && state.errorCode == null) return const [];
    return [
      Container(
        key: const ValueKey('birthday-error'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: p.dangerSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(PhosphorIconsRegular.warningCircle, size: 18, color: p.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                birthdayErrorText(l10n, state.errorCode, state.errorMessage),
                style: TextStyle(color: p.danger, fontSize: 13.5),
              ),
            ),
          ],
        ),
      ),
      if (state.unclear) ...[
        const SizedBox(height: 6),
        Text(
          l10n.bdUnclearHint,
          key: const ValueKey('birthday-unclear-hint'),
          style: p.bodyMuted.copyWith(fontSize: 12.5),
        ),
      ],
      if (_offline) ...[
        const SizedBox(height: 6),
        Text(
          l10n.bdOfflineHint,
          key: const ValueKey('birthday-offline-hint'),
          style: TextStyle(color: p.danger, fontSize: 12.5),
        ),
      ],
    ];
  }

  Widget _footer(BirthdaySellState state) {
    final l10n = AppLocalization.of(context);
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 56,
            child: OutlinedButton(
              key: const ValueKey('birthday-close'),
              onPressed: state.busy ? null : _close,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(state.unclear ? l10n.bdClose : l10n.cancel),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 56,
            child: FilledButton(
              key: const ValueKey('birthday-submit'),
              onPressed: state.canSubmit
                  ? () => _cubit.submit(customerId: widget.customer.id)
                  : null,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: state.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.unclear
                                ? PhosphorIconsRegular.arrowsClockwise
                                : PhosphorIconsRegular.receipt,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.unclear
                                ? l10n.eventsRetry
                                : l10n.birthdayBookAndReceipt,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One pinned money number: small label with an icon, big amount.
class _MoneyTile extends StatelessWidget {
  const _MoneyTile({
    super.key,
    required this.label,
    required this.amountUzs,
    required this.bg,
    required this.fg,
    required this.amountColor,
    required this.icon,
    this.amountKey,
  });

  final String label;
  final int amountUzs;
  final Color bg;
  final Color fg;
  final Color amountColor;
  final IconData icon;
  final Key? amountKey;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatUzs(amountUzs),
              key: amountKey,
              style: tabular(
                p.title.copyWith(
                  fontSize: 24,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The modal's top bar: what this screen is, for whom, and a close X.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.customer, required this.onClose});

  final Customer customer;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final phone = formatPhoneNumber(customer.phoneNumber);
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 14, 20, 14),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(PhosphorIconsRegular.cake, size: 24, color: p.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.birthdaySell,
                  style: p.title.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  customer.fullName.isEmpty
                      ? phone
                      : '${customer.fullName} · $phone',
                  key: const ValueKey('birthday-customer'),
                  overflow: TextOverflow.ellipsis,
                  style: tabular(p.bodyMuted.copyWith(fontSize: 13.5)),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: const ValueKey('birthday-close-x'),
              tooltip: l10n.bdClose,
              onPressed: onClose,
              style: IconButton.styleFrom(
                backgroundColor: p.surfaceMuted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(PhosphorIconsRegular.x, size: 20, color: p.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// "To'liq to'lov | Zaklad" — a soft two-segment switch.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.deposit,
    required this.onChanged,
    required this.fullLabel,
    required this.depositLabel,
  });

  final bool deposit;
  final ValueChanged<bool> onChanged;
  final String fullLabel;
  final String depositLabel;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    Widget segment(bool value, String label, IconData icon, String key) {
      final on = deposit == value;
      return Expanded(
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on
                  ? (isNight(context) ? p.accentSoft : p.surface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              boxShadow: on && !isNight(context)
                  ? const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: on ? p.accent : p.textMuted),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: p.heading.copyWith(
                      fontSize: 14.5,
                      color: on ? p.text : p.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment(
            false,
            fullLabel,
            PhosphorIconsRegular.wallet,
            'birthday-mode-full',
          ),
          segment(
            true,
            depositLabel,
            PhosphorIconsRegular.lockSimple,
            'birthday-mode-deposit',
          ),
        ],
      ),
    );
  }
}
