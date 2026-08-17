import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/printing/gate_pass_label_printer.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../products/domain/product.dart';
import '../../domain/active_pass.dart';
import '../../domain/customer.dart';
import '../../domain/kids_plan.dart';
import '../../domain/playing_child.dart';
import '../bloc/pos_account_bloc.dart';
import 'plan_conflict_dialog.dart';
import 'plan_entry_printing.dart';

const _quickTopupAmounts = [10000, 20000, 50000, 100000];

/// The center pane once a customer is selected — a summary strip (back,
/// avatar, name, balance) then two cards side by side (wrapping on narrow
/// widths): children/QR issuance, and balance top-up.
class CustomerDetailPanel extends StatefulWidget {
  const CustomerDetailPanel({super.key});

  @override
  State<CustomerDetailPanel> createState() => _CustomerDetailPanelState();
}

class _CustomerDetailPanelState extends State<CustomerDetailPanel> {
  final Set<String> _selectedChildIds = {};
  KidsPlan? _selectedPlan;

  bool _addingChild = false;
  final _childNameController = TextEditingController();

  /// Checkout also prints the free parent QR — default ON per customer.
  bool _printParentQr = true;

  PaymentMethod _topupMethod = PaymentMethod.cash;
  final _topupAmountController = TextEditingController();
  final _topupCashController = TextEditingController();
  final _topupCardController = TextEditingController();

  /// productId → qty of the extra goods (socks etc.) sold with this entry.
  final Map<String, int> _cart = {};

  /// "Balansdan yechish" — only offered while the balance covers the cart.
  bool _payFromBalance = true;

  PaymentMethod _payMethod = PaymentMethod.cash;
  final _payAmountController = TextEditingController();
  final _payCashController = TextEditingController();
  final _payCardController = TextEditingController();

  /// True once the cashier types in the payment field themselves — from
  /// then on the auto-prefill below keeps its hands off their value.
  bool _payEdited = false;

  @override
  void dispose() {
    _childNameController.dispose();
    _topupAmountController.dispose();
    _topupCashController.dispose();
    _topupCardController.dispose();
    _payAmountController.dispose();
    _payCashController.dispose();
    _payCardController.dispose();
    super.dispose();
  }

  void _resetFor(Customer? customer) {
    _selectedChildIds.clear();
    _selectedPlan = null;
    _addingChild = false;
    _childNameController.clear();
    _printParentQr = true;
    _topupMethod = PaymentMethod.cash;
    _topupAmountController.clear();
    _topupCashController.clear();
    _topupCardController.clear();
    _cart.clear();
    _payFromBalance = true;
    _payMethod = PaymentMethod.cash;
    _payEdited = false;
    _payAmountController.clear();
    _payCashController.clear();
    _payCardController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.selectedCustomer?.id != current.selectedCustomer?.id,
          listener: (context, state) =>
              setState(() => _resetFor(state.selectedCustomer)),
        ),
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.lastEntryResult != current.lastEntryResult &&
              current.lastEntryResult != null,
          listener: (context, state) {
            final result = state.lastEntryResult!;
            final childNames = {
              for (final child
                  in state.selectedCustomer?.children ?? const <Child>[])
                child.id: child.fullName,
            };
            printPlanEntryLabels(context, result, childNames);
            context.read<PosAccountBloc>().add(
              const PosAccountEntryAcknowledged(),
            );
            setState(() => _resetFor(state.selectedCustomer));
            if (result.conflicts.isNotEmpty) {
              final requestedKey = result.conflicts.first.requestedPlanKey;
              final requestedPlan = state.plans
                  .where((p) => p.key == requestedKey)
                  .firstOrNull;
              showPlanConflictDialog(
                context,
                conflicts: result.conflicts,
                childNamesById: childNames,
                requestedPlanName: requestedPlan?.name ?? requestedKey,
                requestedPlanFlatUzs:
                    requestedPlan?.kind == KidsPlanKind.flatDay
                    ? requestedPlan?.flatUzs
                    : null,
              );
            }
          },
        ),
        // Prints the free parent sticker the moment the bloc hands one
        // over — same no-preview flow as the child gate-pass labels.
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.lastParentPass != current.lastParentPass &&
              current.lastParentPass != null,
          listener: (context, state) {
            final pass = state.lastParentPass!;
            final messenger = ScaffoldMessenger.of(context);
            GatePassLabelPrinter.printDirect([
              (qrData: pass.code, name: pass.customerName, invertName: true),
            ]).then((ok) {
              if (ok) return;
              messenger.showSnackBar(
                const SnackBar(
                  backgroundColor: NocturneColors.surface,
                  content: Text(
                    'Stiker chop etilmadi — printerni tekshiring',
                    style: TextStyle(color: NocturneColors.danger),
                  ),
                ),
              );
            });
            context.read<PosAccountBloc>().add(
              const PosAccountParentQrAcknowledged(),
            );
          },
        ),
      ],
      child: BlocBuilder<PosAccountBloc, PosAccountState>(
        builder: (context, state) {
          final customer = state.selectedCustomer;
          if (customer == null) return const SizedBox.shrink();

          final productsById = {for (final p in state.products) p.id: p};
          final cartTotal = _cart.entries.fold<int>(
            0,
            (sum, line) =>
                sum + (productsById[line.key]?.priceUzs ?? 0) * line.value,
          );
          // VIP is debited from the balance at issuance (register prepay);
          // Standard has no upfront tariff — it bills per exit by actual
          // minutes. Children already holding today's pass on the SAME
          // flat-day plan are not charged again — the backend just
          // re-returns their pass.
          final activePlanByChild = {
            for (final p in state.activePasses) p.childId: p.planKey,
          };
          final alreadyOnSelectedPlan = <String>{
            if (_selectedPlan?.kind == KidsPlanKind.flatDay)
              for (final id in _selectedChildIds)
                if (activePlanByChild[id] == _selectedPlan!.key) id,
          };
          final vipTotal = _selectedPlan?.kind == KidsPlanKind.flatDay
              ? (_selectedPlan!.flatUzs ?? 0) *
                    (_selectedChildIds.length - alreadyOnSelectedPlan.length)
              : 0;
          final neededTotal = cartTotal + vipTotal;
          final shortfall = neededTotal - customer.balance;
          final balanceCovers = shortfall <= 0;
          // Money must be collected when the balance can't cover the total,
          // or when the cashier explicitly keeps the balance untouched.
          final requiredPayment = neededTotal == 0
              ? 0
              : balanceCovers
              ? (_payFromBalance ? 0 : neededTotal)
              : shortfall;

          // Default the payment field to exactly what's owed, so the
          // cashier confirms a number instead of typing it. Follows cart /
          // tariff changes until the cashier edits the field by hand.
          if (requiredPayment > 0 &&
              !_payEdited &&
              _payAmountController.text != '$requiredPayment') {
            _payAmountController.text = '$requiredPayment';
          }

          final payAmount =
              int.tryParse(_payAmountController.text.replaceAll(' ', '')) ?? 0;
          final paySplit = PaymentSplit.compute(
            method: _payMethod,
            totalUzs: payAmount,
            cashInput: _payCashController.text,
            cardInput: _payCardController.text,
          );
          final paymentOk =
              requiredPayment == 0 ||
              (payAmount >= requiredPayment && paySplit.isValid);

          final canEnter =
              !state.isBusy &&
              _selectedPlan != null &&
              _selectedChildIds.isNotEmpty &&
              paymentOk;

          final topupAmount =
              int.tryParse(_topupAmountController.text.replaceAll(' ', '')) ??
              0;
          final topupSplit = PaymentSplit.compute(
            method: _topupMethod,
            totalUzs: topupAmount,
            cashInput: _topupCashController.text,
            cardInput: _topupCardController.text,
          );
          final canTopup = !state.isBusy && topupAmount > 0 && topupSplit.isValid;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryStrip(
                  customer: customer,
                  isBusy: state.isBusy,
                  onParentQr: () => context.read<PosAccountBloc>().add(
                    const PosAccountParentQrRequested(),
                  ),
                  onBack: () => context.read<PosAccountBloc>().add(
                    const PosAccountSelectionCleared(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ChildrenCard(
                        customer: customer,
                        plans: state.plans,
                        isLoadingPlans: state.isLoadingPlans,
                        activePasses: state.activePasses,
                        selectedChildIds: _selectedChildIds,
                        onToggleChild: (id) => setState(
                          () => _selectedChildIds.contains(id)
                              ? _selectedChildIds.remove(id)
                              : _selectedChildIds.add(id),
                        ),
                        addingChild: _addingChild,
                        onStartAddChild: () =>
                            setState(() => _addingChild = true),
                        onCancelAddChild: () => setState(() {
                          _addingChild = false;
                          _childNameController.clear();
                        }),
                        childNameController: _childNameController,
                        onSubmitAddChild: () {
                          final today = DateTime.now();
                          final iso =
                              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                          context.read<PosAccountBloc>().add(
                            PosAccountChildAddRequested(
                              firstName: _childNameController.text.trim(),
                              birthDate: iso,
                            ),
                          );
                          setState(() {
                            _addingChild = false;
                            _childNameController.clear();
                          });
                        },
                        selectedPlan: _selectedPlan,
                        onSelectPlan: (p) => setState(() => _selectedPlan = p),
                        checkout: _CheckoutSection(
                          products: state.products,
                          cart: _cart,
                          cartTotal: cartTotal,
                          vipTotal: vipTotal,
                          neededTotal: neededTotal,
                          balance: customer.balance,
                          balanceCovers: balanceCovers,
                          shortfall: shortfall,
                          payFromBalance: _payFromBalance,
                          onPayFromBalanceChanged: (v) => setState(() {
                            _payFromBalance = v;
                            // Toggling re-arms the prefill for the new mode.
                            _payEdited = false;
                            if (v) _payAmountController.clear();
                          }),
                          onPayAmountEdited: () => _payEdited = true,
                          requiredPayment: requiredPayment,
                          payMethod: _payMethod,
                          onPayMethodChanged: (m) =>
                              setState(() => _payMethod = m),
                          payAmountController: _payAmountController,
                          payCashController: _payCashController,
                          payCardController: _payCardController,
                          paySplit: paySplit,
                          payAmount: payAmount,
                          onChanged: () => setState(() {}),
                          onAdd: (id) => setState(
                            () => _cart[id] = (_cart[id] ?? 0) + 1,
                          ),
                          onRemove: (id) => setState(() {
                            final qty = (_cart[id] ?? 0) - 1;
                            if (qty <= 0) {
                              _cart.remove(id);
                            } else {
                              _cart[id] = qty;
                            }
                          }),
                          selectedChildCount: _selectedChildIds.length,
                          alreadyVipNames: [
                            for (final child in customer.children)
                              if (alreadyOnSelectedPlan.contains(child.id))
                                child.fullName,
                          ],
                          printParentQr: _printParentQr,
                          onPrintParentQrChanged: (v) =>
                              setState(() => _printParentQr = v),
                          canSubmit: canEnter,
                          isBusy: state.isBusy,
                          onSubmit: () => context.read<PosAccountBloc>().add(
                            PosAccountCheckoutRequested(
                              planKey: _selectedPlan!.key,
                              childIds: _selectedChildIds.toList(),
                              withParentQr: _printParentQr,
                              products: [
                                for (final line in _cart.entries)
                                  (productId: line.key, qty: line.value),
                              ],
                              cashUzs: requiredPayment == 0
                                  ? 0
                                  : paySplit.cashUzs,
                              cardUzs: requiredPayment == 0
                                  ? 0
                                  : paySplit.cardUzs,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BalanceCard(
                        customer: customer,
                        amountController: _topupAmountController,
                        onAmountChanged: () => setState(() {}),
                        method: _topupMethod,
                        onMethodChanged: (m) => setState(() => _topupMethod = m),
                        cashController: _topupCashController,
                        cardController: _topupCardController,
                        split: topupSplit,
                        amount: topupAmount,
                        canTopup: canTopup,
                        isBusy: state.isBusy,
                        onTopup: () => context.read<PosAccountBloc>().add(
                          PosAccountTopupRequested(
                            amountUzs: topupAmount,
                            cashUzs: topupSplit.cashUzs,
                            cardUzs: topupSplit.cardUzs,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (state.playing.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _PlayingCard(
                    rows: state.playing,
                    balance: customer.balance,
                    onRefresh: () => context.read<PosAccountBloc>().add(
                      const PosAccountPlayingRequested(),
                    ),
                  ),
                ],
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    style: const TextStyle(
                      color: NocturneColors.danger,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        child,
      ]),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.customer,
    required this.isBusy,
    required this.onParentQr,
    required this.onBack,
  });

  final Customer customer;
  final bool isBusy;

  /// Prints the customer's free parent QR — the ruleless both-direction
  /// day sticker for the accompanying adult.
  final VoidCallback onParentQr;
  final VoidCallback onBack;

  String _initials(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = customer.fullName.isEmpty
        ? customer.phoneNumber
        : customer.fullName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: NocturneColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadow.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
              child: const Icon(PhosphorIconsRegular.arrowLeft, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: NocturneColors.accent900,
            child: Text(
              _initials(displayName),
              style: const TextStyle(
                color: NocturneColors.accent300,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.h4,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  customer.phoneNumber,
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onParentQr,
            icon: const Icon(PhosphorIconsRegular.qrCode, size: 16),
            label: const Text('Ota-ona QR'),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Balans',
                style: AppTextStyles.kicker.copyWith(
                  color: NocturneColors.text.withValues(alpha: 0.45),
                ),
              ),
              Text(
                formatUzs(customer.balance),
                style: AppTextStyles.h4.copyWith(color: NocturneColors.accent300),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChildrenCard extends StatelessWidget {
  const _ChildrenCard({
    required this.customer,
    required this.plans,
    required this.isLoadingPlans,
    required this.activePasses,
    required this.selectedChildIds,
    required this.onToggleChild,
    required this.addingChild,
    required this.onStartAddChild,
    required this.onCancelAddChild,
    required this.childNameController,
    required this.onSubmitAddChild,
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.checkout,
  });

  final Customer customer;

  /// Standard/VIP — always exactly these two once loaded (seeded on the
  /// backend). Standard starts a visit billed from the customer's balance
  /// at exit; VIP is debited from the balance immediately at printing.
  final List<KidsPlan> plans;
  final bool isLoadingPlans;

  /// Children's still-valid day passes — powers the per-row plan badge so
  /// staff see "already on Standart today" BEFORE picking a tariff.
  final List<ActivePass> activePasses;
  final Set<String> selectedChildIds;
  final ValueChanged<String> onToggleChild;
  final bool addingChild;
  final VoidCallback onStartAddChild;
  final VoidCallback onCancelAddChild;
  final TextEditingController childNameController;
  final VoidCallback onSubmitAddChild;
  final KidsPlan? selectedPlan;
  final ValueChanged<KidsPlan> onSelectPlan;

  /// Products + total + payment + the submit button — owned by the parent
  /// so this card doesn't have to thread a dozen more callbacks through.
  final Widget checkout;

  /// Standard only: nothing is due at the register — billing happens at
  /// exit by played time. VIP gets NO note here: it is debited immediately
  /// at printing, and the checkout section already says so.
  String _noPaymentNote() =>
      "Hozir hech narsa to'lanmaydi — chiqishda balansdan vaqtiga qarab yechiladi.";

  @override
  Widget build(BuildContext context) {
    final selCount = selectedChildIds.length;
    final passByChildId = {for (final pass in activePasses) pass.childId: pass};
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Farzandlar', style: AppTextStyles.h5),
              const SizedBox(width: 8),
              Text(
                selCount > 0
                    ? 'tanlangan: $selCount'
                    : customer.children.isEmpty
                    ? "farzand yo'q"
                    : 'QR uchun tanlang',
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final child in customer.children)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ChildRow(
                child: child,
                activePass: passByChildId[child.id],
                selected: selectedChildIds.contains(child.id),
                onToggle: () => onToggleChild(child.id),
              ),
            ),
          if (!addingChild)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: TextButton.icon(
                onPressed: onStartAddChild,
                icon: const Icon(PhosphorIconsRegular.plus, size: 14),
                label: const Text("Tez qo'shish"),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              // Listens to the controller directly so the submit button
              // enables the moment a valid name is typed — the parent
              // doesn't rebuild on keystrokes.
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: childNameController,
                builder: (context, value, _) {
                  final canSubmit = value.text.trim().length >= 2;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: childNameController,
                          autofocus: true,
                          style: AppTextStyles.body,
                          onSubmitted: (_) {
                            if (canSubmit) onSubmitAddChild();
                          },
                          decoration: const InputDecoration(
                            hintText: 'Bola ismi',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: canSubmit ? onSubmitAddChild : null,
                          icon: const Icon(PhosphorIconsRegular.plus, size: 14),
                          label: const Text("Qo'shish"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: onCancelAddChild,
                          child: const Text('Bekor qilish'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Text('Tarif', style: AppTextStyles.body.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          if (isLoadingPlans)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (plans.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: NocturneColors.divider),
              ),
              child: Text(
                'Tarif topilmadi.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: NocturneColors.text.withValues(alpha: 0.55),
                ),
              ),
            )
          else
            Row(
              children: [
                for (final plan in plans) ...[
                  if (plan.key != plans.first.key) const SizedBox(width: 8),
                  Expanded(
                    child: _TariffPill(
                      plan: plan,
                      selected: selectedPlan?.key == plan.key,
                      onTap: () => onSelectPlan(plan),
                    ),
                  ),
                ],
              ],
            ),
          if (selectedPlan != null &&
              selectedPlan!.kind != KidsPlanKind.flatDay) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: NocturneColors.bg,
              ),
              child: Text(
                _noPaymentNote(),
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: NocturneColors.text.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          checkout,
        ],
      ),
    );
  }
}

/// Products + running total + how the money is settled + the submit button.
///
/// The money model mirrors the backend's plan-entry checkout: everything
/// flows through the balance. Collected cash/card is credited to the
/// balance first, then products are debited from it; the Standard tariff
/// bills per exit, while VIP is debited from the balance at issuance.
class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.products,
    required this.cart,
    required this.cartTotal,
    required this.vipTotal,
    required this.neededTotal,
    required this.balance,
    required this.balanceCovers,
    required this.shortfall,
    required this.payFromBalance,
    required this.onPayFromBalanceChanged,
    required this.onPayAmountEdited,
    required this.requiredPayment,
    required this.payMethod,
    required this.onPayMethodChanged,
    required this.payAmountController,
    required this.payCashController,
    required this.payCardController,
    required this.paySplit,
    required this.payAmount,
    required this.onChanged,
    required this.onAdd,
    required this.onRemove,
    required this.selectedChildCount,
    required this.alreadyVipNames,
    required this.printParentQr,
    required this.onPrintParentQrChanged,
    required this.canSubmit,
    required this.isBusy,
    required this.onSubmit,
  });

  final List<Product> products;
  final Map<String, int> cart;
  final int cartTotal;

  /// VIP flat price × newly-covered children — debited from the balance
  /// the moment the stickers print. 0 for Standard.
  final int vipTotal;
  final int neededTotal;
  final int balance;
  final bool balanceCovers;
  final int shortfall;
  final bool payFromBalance;
  final ValueChanged<bool> onPayFromBalanceChanged;

  /// Fired on manual typing in the payment field — stops the auto-prefill
  /// from overwriting the cashier's own value.
  final VoidCallback onPayAmountEdited;
  final int requiredPayment;
  final PaymentMethod payMethod;
  final ValueChanged<PaymentMethod> onPayMethodChanged;
  final TextEditingController payAmountController;
  final TextEditingController payCashController;
  final TextEditingController payCardController;
  final PaymentSplit paySplit;
  final int payAmount;
  final VoidCallback onChanged;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final int selectedChildCount;

  /// Selected children already on today's selected flat-day plan — shown
  /// as "no second charge" notes and excluded from [vipTotal].
  final List<String> alreadyVipNames;

  /// The free parent sticker rides along with the checkout print.
  final bool printParentQr;
  final ValueChanged<bool> onPrintParentQrChanged;
  final bool canSubmit;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (products.isNotEmpty) ...[
          Text('Mahsulotlar', style: AppTextStyles.body.copyWith(fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final product in products)
                _ProductChip(
                  product: product,
                  qty: cart[product.id] ?? 0,
                  onAdd: () => onAdd(product.id),
                  onRemove: () => onRemove(product.id),
                ),
            ],
          ),
        ],
        for (final name in alreadyVipNames)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "«$name» allaqachon faol VIP tarifda — qayta to'lov olinmaydi.",
              style: AppTextStyles.muted(
                AppTextStyles.body,
              ).copyWith(fontSize: 11),
            ),
          ),
        if (neededTotal > 0) ...[
          const SizedBox(height: 12),
          if (cartTotal > 0 && vipTotal > 0) ...[
            _TotalRow(label: 'Mahsulotlar', amount: cartTotal),
            _TotalRow(label: 'VIP tarif', amount: vipTotal),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              Text('Jami', style: AppTextStyles.muted(AppTextStyles.body)),
              const Spacer(),
              Text(formatUzs(neededTotal), style: AppTextStyles.h5),
            ],
          ),
          if (vipTotal > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                "VIP tarif puli chop etilganda balansdan darhol yechiladi.",
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 11),
              ),
            ),
          const SizedBox(height: 8),
          if (balanceCovers)
            SwitchListTile(
              value: payFromBalance,
              onChanged: onPayFromBalanceChanged,
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: NocturneColors.accent,
              title: Text(
                'Balansdan yechish',
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
              subtitle: Text(
                'Joriy balans: ${formatUzs(balance)}',
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 11),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                color: NocturneColors.accent.withValues(alpha: 0.12),
                border: Border.all(color: NocturneColors.accent),
              ),
              child: Text(
                'Balansdan yechishga yetarli emas — '
                "kamida ${formatUzs(shortfall)} to'lov kerak.",
                style: AppTextStyles.body.copyWith(fontSize: 12),
              ),
            ),
          if (requiredPayment > 0) ...[
            const SizedBox(height: 8),
            TextField(
              controller: payAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.body.copyWith(fontFamily: null, fontSize: 16),
              onChanged: (_) {
                onPayAmountEdited();
                onChanged();
              },
              decoration: InputDecoration(
                labelText: "To'lov summasi",
                helperText:
                    "Kamida ${formatUzs(requiredPayment)} — ortig'i balansda qoladi",
              ),
            ),
            const SizedBox(height: 8),
            PaymentMethodPills(selected: payMethod, onChanged: onPayMethodChanged),
            if (payMethod == PaymentMethod.split) ...[
              const SizedBox(height: 8),
              SplitAmountFields(
                cashController: payCashController,
                cardController: payCardController,
                split: paySplit,
                totalUzs: payAmount,
                onChanged: onChanged,
              ),
            ],
          ],
        ],
        const SizedBox(height: 4),
        // Transparent Material keeps the tile's ink plumbing happy inside
        // the card's DecoratedBox (asserts in widget tests otherwise).
        Material(
          type: MaterialType.transparency,
          child: SwitchListTile(
            value: printParentQr,
            onChanged: onPrintParentQrChanged,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeThumbColor: NocturneColors.accent,
            title: Text(
              'Ota-ona QR ham chop etish',
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
            subtitle: Text(
              'Bepul — kirish-chiqishga cheklovsiz',
              style: AppTextStyles.muted(
                AppTextStyles.body,
              ).copyWith(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: canSubmit ? onSubmit : null,
            icon: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    neededTotal > 0
                        ? PhosphorIconsRegular.printer
                        : PhosphorIconsRegular.doorOpen,
                    size: 18,
                  ),
            label: Text(
              neededTotal > 0
                  ? "To'lov va chop etish"
                  : selectedChildCount > 0
                  ? 'Kirish ($selectedChildCount)'
                  : 'Kirish',
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 12),
          ),
          const Spacer(),
          Text(
            formatUzs(amount),
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// One product with an inline qty stepper — tap adds the first piece,
/// then − / + adjust.
class _ProductChip extends StatelessWidget {
  const _ProductChip({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final selected = qty > 0;
    return Material(
      color: selected
          ? NocturneColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: selected ? null : onAdd,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: selected
                          ? NocturneColors.accent
                          : NocturneColors.text,
                    ),
                  ),
                  Text(
                    formatUzs(product.priceUzs),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color:
                          (selected
                                  ? NocturneColors.accent
                                  : NocturneColors.text)
                              .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                _StepButton(
                  icon: PhosphorIconsRegular.minus,
                  onTap: onRemove,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$qty', style: AppTextStyles.h5),
                ),
                _StepButton(icon: PhosphorIconsRegular.plus, onTap: onAdd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: NocturneColors.accent),
        ),
        child: Icon(icon, size: 13, color: NocturneColors.accent),
      ),
    );
  }
}

/// The customer's currently-inside children with their live running cost —
/// the cashier's instant answer when a parent walks up because the exit QR
/// refused on a low balance. The top-up card sits right above it.
class _PlayingCard extends StatelessWidget {
  const _PlayingCard({
    required this.rows,
    required this.balance,
    required this.onRefresh,
  });

  final List<PlayingChild> rows;
  final int balance;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final totalDue = rows.fold<int>(0, (sum, row) => sum + row.dueUzs);
    final short = totalDue - balance;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Hozir ichkarida', style: AppTextStyles.h5),
              const SizedBox(width: 8),
              Text(
                '${rows.length} bola',
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 11),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: onRefresh,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(PhosphorIconsRegular.arrowsClockwise, size: 13),
                  label: const Text('Yangilash'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: NocturneColors.bg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: NocturneColors.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.childName,
                          style: AppTextStyles.body.copyWith(fontSize: 14),
                        ),
                        Text(
                          '${row.planName} · '
                          'kirdi ${row.enteredAt.hour.toString().padLeft(2, '0')}:${row.enteredAt.minute.toString().padLeft(2, '0')} · '
                          '${row.minutes} daq',
                          style: AppTextStyles.muted(
                            AppTextStyles.body,
                          ).copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(formatUzs(row.dueUzs), style: AppTextStyles.h5),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Jami hisob',
                style: AppTextStyles.muted(AppTextStyles.body),
              ),
              const Spacer(),
              Text(
                formatUzs(totalDue),
                style: AppTextStyles.h5.copyWith(
                  color: short > 0
                      ? NocturneColors.danger
                      : NocturneColors.accent300,
                ),
              ),
            ],
          ),
          if (short > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                "Balans yetarli emas — chiqish uchun kamida ${formatUzs(short)} to'ldirish kerak.",
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  color: NocturneColors.danger,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.child,
    required this.activePass,
    required this.selected,
    required this.onToggle,
  });

  final Child child;

  /// The child's still-valid day pass, or null — shown as a badge (plan +
  /// today's running cost) so the cashier both notices the existing tariff
  /// before printing and can answer a parent's "qancha bo'ldi?" on sight.
  final ActivePass? activePass;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: NocturneColors.bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: selected ? NocturneColors.accent : NocturneColors.divider,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              child.fullName,
              style: AppTextStyles.body.copyWith(fontSize: 14),
            ),
          ),
          if (activePass != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: NocturneColors.accent900,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                '${activePass!.planLabel} · '
                '${formatUzs(activePass!.dueTodayUzs)}',
                style: AppTextStyles.body.copyWith(
                  fontSize: 11,
                  color: NocturneColors.accent300,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            height: 34,
            child: OutlinedButton.icon(
              onPressed: onToggle,
              style: OutlinedButton.styleFrom(
                foregroundColor: NocturneColors.accent,
                side: const BorderSide(color: NocturneColors.accent),
                backgroundColor: selected
                    ? NocturneColors.accent.withValues(alpha: 0.2)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: Icon(
                selected ? PhosphorIconsRegular.check : PhosphorIconsRegular.plus,
                size: 15,
              ),
              label: const Text('QR'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TariffPill extends StatelessWidget {
  const _TariffPill({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final KidsPlan plan;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => plan.kind == KidsPlanKind.flatDay
      ? PhosphorIconsRegular.crownSimple
      : PhosphorIconsRegular.ticket;

  String get _priceLabel => plan.kind == KidsPlanKind.flatDay
      ? '${formatUzs(plan.flatUzs ?? 0)} / kun'
      : '${formatUzs(plan.firstMinuteUzs ?? 0)} / daq dan';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? NocturneColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _icon,
                size: 15,
                color: selected ? NocturneColors.accent : NocturneColors.text,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    plan.name,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: selected
                          ? NocturneColors.accent
                          : NocturneColors.text,
                    ),
                  ),
                  Text(
                    _priceLabel,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: (selected
                              ? NocturneColors.accent
                              : NocturneColors.text)
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.customer,
    required this.amountController,
    required this.onAmountChanged,
    required this.method,
    required this.onMethodChanged,
    required this.cashController,
    required this.cardController,
    required this.split,
    required this.amount,
    required this.canTopup,
    required this.isBusy,
    required this.onTopup,
  });

  final Customer customer;
  final TextEditingController amountController;
  final VoidCallback onAmountChanged;
  final PaymentMethod method;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final TextEditingController cashController;
  final TextEditingController cardController;
  final PaymentSplit split;
  final int amount;
  final bool canTopup;
  final bool isBusy;
  final VoidCallback onTopup;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Balansni to'ldirish", style: AppTextStyles.h5),
          const SizedBox(height: 4),
          Text(
            'Joriy balans: ${formatUzs(customer.balance)}',
            style: AppTextStyles.muted(AppTextStyles.body).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final quick in _quickTopupAmounts)
                _AmountChip(
                  amount: quick,
                  selected: amount == quick,
                  onTap: () => amountController.text = quick.toString(),
                  onChanged: onAmountChanged,
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.body.copyWith(fontFamily: null, fontSize: 18),
            onChanged: (_) => onAmountChanged(),
            decoration: const InputDecoration(labelText: 'Summa'),
          ),
          const SizedBox(height: 10),
          PaymentMethodPills(selected: method, onChanged: onMethodChanged),
          if (method == PaymentMethod.split) ...[
            const SizedBox(height: 8),
            SplitAmountFields(
              cashController: cashController,
              cardController: cardController,
              split: split,
              totalUzs: amount,
              onChanged: onAmountChanged,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text('Yangi balans', style: AppTextStyles.muted(AppTextStyles.body)),
              const Spacer(),
              Text(formatUzs(customer.balance + amount), style: AppTextStyles.h5),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: canTopup ? onTopup : null,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.wallet, size: 18),
              label: const Text("To'ldirish"),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.onTap,
    required this.onChanged,
  });

  final int amount;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? NocturneColors.accent.withValues(alpha: 0.12)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          onTap();
          onChanged();
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? NocturneColors.accent : NocturneColors.divider,
            ),
          ),
          child: Text(
            formatUzs(amount),
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              color: selected ? NocturneColors.accent : NocturneColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
