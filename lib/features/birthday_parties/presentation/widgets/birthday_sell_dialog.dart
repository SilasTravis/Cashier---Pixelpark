import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../pos_account/domain/customer.dart';
import '../../../pos_account/presentation/widgets/account_ui.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../../domain/birthday_plan.dart';
import '../bloc/birthday_sell_cubit.dart';
import '../birthday_error_text.dart';
import 'birthday_payment_block.dart';
import 'birthday_total_card.dart';
import 'extra_children_stepper.dart';
import 'size_picker.dart';
import 'tier_picker.dart';

/// Opens "Tug'ilgan kun sotish". Resolves with the booked party (the caller
/// prints the receipt and refreshes the customer), null when cancelled.
Future<BirthdayParty?> showBirthdaySellDialog(
  BuildContext context, {
  required Customer customer,
}) {
  final theme = Theme.of(context);
  return showDialog<BirthdayParty>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: BlocProvider(
        create: (_) => BirthdaySellCubit(sl())..load(),
        child: BirthdaySellDialog(customer: customer),
      ),
    ),
  );
}

class BirthdaySellDialog extends StatefulWidget {
  const BirthdaySellDialog({super.key, required this.customer});

  final Customer customer;

  @override
  State<BirthdaySellDialog> createState() => _BirthdaySellDialogState();
}

class _BirthdaySellDialogState extends State<BirthdaySellDialog> {
  final _totalController = TextEditingController();
  final _depositController = TextEditingController();
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _totalController.dispose();
    _depositController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  BirthdaySellCubit get _cubit => context.read<BirthdaySellCubit>();

  Future<void> _pickDate(DateTime current) async {
    final today = DateTime.now();
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
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final customer = widget.customer;
    return BlocConsumer<BirthdaySellCubit, BirthdaySellState>(
      listenWhen: (a, b) =>
          a.listPriceUzs != b.listPriceUzs || a.party != b.party,
      listener: (context, state) {
        if (state.party != null) {
          Navigator.of(context).pop<BirthdayParty>(state.party);
          return;
        }
        // A re-priced sale starts the total field over at the list price.
        _totalController.text = state.listPriceUzs == 0
            ? ''
            : groupDigits(state.listPriceUzs);
      },
      builder: (context, state) {
        final payment = state.payment(customer.balance);
        final plan = state.plan;
        final size = state.size;
        final color = colorOf(plan?.color ?? '', p.accent);
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(p, l10n, customer),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StepHeader(step: 1, title: l10n.birthdayPlan),
                          const SizedBox(height: 10),
                          if (state.loading)
                            const Center(child: CircularProgressIndicator())
                          else if (state.plans.isEmpty)
                            Text(l10n.birthdayNoPlans, style: p.bodyMuted)
                          else
                            TierPicker(
                              plans: state.plans,
                              selectedId: state.selectedPlanId,
                              onSelected: _cubit.selectPlan,
                            ),
                          if (plan != null) ...[
                            const SizedBox(height: 18),
                            StepHeader(step: 2, title: l10n.birthdayChildCount),
                            const SizedBox(height: 10),
                            SizePicker(
                              sizes: plan.sizes,
                              selected: state.childCount,
                              color: color,
                              onSelected: _cubit.selectSize,
                            ),
                          ],
                          if (size != null) ...[
                            const SizedBox(height: 18),
                            StepHeader(step: 3, title: l10n.birthdayExtraChild),
                            const SizedBox(height: 10),
                            ExtraChildrenStepper(
                              count: state.extraChildren,
                              hint: l10n.birthdayExtraHint(
                                '${size.childCount}',
                                plan!.name,
                                groupDigits(size.extraChildUzs),
                              ),
                              onAdd: _cubit.addExtraChild,
                              onReset: _cubit.resetExtraChildren,
                            ),
                            const SizedBox(height: 18),
                            StepHeader(step: 4, title: l10n.birthdayDate),
                            const SizedBox(height: 10),
                            BirthdayTotalCard(
                              state: state,
                              size: size,
                              totalController: _totalController,
                              onPickDate: () => _pickDate(state.partyDate),
                              onTotalChanged: (v) =>
                                  _cubit.setAgreedPrice(parseUzs(v)),
                            ),
                            const SizedBox(height: 18),
                            StepHeader(step: 5, title: l10n.birthdayPayment),
                            const SizedBox(height: 10),
                            _payment(p, l10n, state, payment),
                          ],
                          if (state.errorMessage != null ||
                              state.errorCode != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              key: const ValueKey('birthday-error'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: p.dangerSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                birthdayErrorText(
                                  l10n,
                                  state.errorCode,
                                  state.errorMessage,
                                ),
                                style: TextStyle(color: p.danger, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _footer(l10n, state, payment),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(PosPalette p, AppLocalization l10n, Customer customer) => Row(
    children: [
      Icon(PhosphorIconsRegular.cake, color: p.accent, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.birthdaySell, style: p.title.copyWith(fontSize: 19)),
            Text(
              '${customer.fullName.isEmpty ? '' : '${customer.fullName} · '}'
              '${customer.phoneNumber}',
              style: p.bodyMuted.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
      StatusChip(
        label: l10n.currentBalanceValue(formatUzs(customer.balance)),
        tone: ChipTone.neutral,
      ),
    ],
  );

  Widget _payment(
    PosPalette p,
    AppLocalization l10n,
    BirthdaySellState state,
    BirthdayPayment payment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(PhosphorIconsRegular.wallet, size: 16),
              label: Text(
                l10n.birthdayPayFull,
                key: const ValueKey('birthday-mode-full'),
              ),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(PhosphorIconsRegular.lock, size: 16),
              label: Text(
                l10n.birthdayDeposit,
                key: const ValueKey('birthday-mode-deposit'),
              ),
            ),
          ],
          selected: {state.deposit},
          onSelectionChanged: (v) => _cubit.setDeposit(v.first),
        ),
        if (state.deposit) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final chip in birthdayDepositChips)
                ChoiceChip(
                  key: ValueKey('birthday-deposit-chip-$chip'),
                  label: Text(groupDigits(chip)),
                  selected: state.depositUzs == chip,
                  onSelected: (_) {
                    _depositController.text = groupDigits(chip);
                    _cubit.setDepositUzs(chip);
                  },
                ),
              SizedBox(
                width: 180,
                child: TextField(
                  key: const ValueKey('birthday-deposit-field'),
                  controller: _depositController,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.birthdayDepositAmount,
                    isDense: true,
                  ),
                  onChanged: (v) => _cubit.setDepositUzs(parseUzs(v) ?? 0),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        BirthdayPaymentBlock(
          payment: payment,
          balanceUzs: widget.customer.balance,
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
        const SizedBox(height: 12),
        Container(
          key: const ValueKey('birthday-remaining'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: p.warningSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  l10n.birthdayPaidBeforeParty,
                  style: p.heading.copyWith(color: p.warning),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatUzs(payment.remainingAfterUzs),
                    style: p.title.copyWith(fontSize: 26, color: p.warning),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(
    AppLocalization l10n,
    BirthdaySellState state,
    BirthdayPayment payment,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: state.busy ? null : () => Navigator.of(context).pop(),
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
              key: const ValueKey('birthday-submit'),
              onPressed: state.canSubmit(widget.customer.balance)
                  ? () => _cubit.submit(
                      customerId: widget.customer.id,
                      balanceUzs: widget.customer.balance,
                    )
                  : null,
              child: state.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(l10n.birthdayBookAndReceipt),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
