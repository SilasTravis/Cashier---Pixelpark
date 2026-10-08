import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/local_source/local_source.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/discount_picker.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../core/widgets/promo_code_field.dart';
import '../../../pos_sale/presentation/widgets/product_grid.dart';
import '../../../pos_sale/presentation/widgets/receipt_dialog.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../../pos_sale/domain/sale_receipt.dart';
import '../../../products/domain/product.dart';
import '../../domain/active_pass.dart';
import '../../domain/customer.dart';
import '../../domain/kids_plan.dart';
import '../../domain/playing_child.dart';
import '../../domain/pos_entry.dart';
import '../../domain/promo_code_check.dart';
import 'account_ui.dart';
import 'check_discount_sheet.dart';
import 'entry_discount_dialog.dart';
import 'confirm_topup_dialog.dart';
import '../bloc/pos_account_bloc.dart';
import 'plan_conflict_dialog.dart';
import 'plan_entry_printing.dart';
import 'today_passes_card.dart';
import 'transactions_accordion.dart';
import 'promo_code_error.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';

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

  /// childId → an entry-scoped `Discount.id` — optional, picked from the
  /// row's 3-dots menu. Only the picks of SELECTED children are sent with
  /// the checkout.
  final Map<String, String> _childEntryDiscountIds = {};

  /// The cashier's "Qaysi bolaga" pick for the verified partner promo code
  /// (`state.promo`) — null (or deselected) falls back to the first
  /// selected child without a pass today; see `promoChildId` in build.
  String? _promoChildId;

  /// childId → the entry discount (catalog pick or promo tier) each child
  /// was sent to checkout with — snapshotted on submit because the bloc
  /// clears the promo in the same state that carries the entry result, and
  /// the fallback entry ticket must print the discounted price.
  Map<String, Discount> _checkoutEntryDiscounts = const {};

  /// Paid HAMROH companion stickers to buy with this checkout.
  int _companions = 0;

  bool _addingChild = false;
  final _childNameController = TextEditingController();

  /// Checkout also prints the free parent QR. Starts from the cashier's
  /// last choice on this till (OFF until first turned on) — see
  /// [LocalSource.getPrintParentQr].
  bool _printParentQr = _savedPrintParentQr();

  /// "Bugungi QR'lar" re-print in flight: the plan name its sticker / ticket
  /// carries (the pass's own plan, not whatever is picked in step 2), and the
  /// plan groups still to send — the bloc drops a request while busy, so
  /// "Hammasini" sends them one after another.
  String? _reprintPlanName;
  List<ReprintGroup> _reprintQueue = const [];

  void _startReprint(List<ReprintGroup> groups) {
    if (groups.isEmpty) return;
    final next = groups.first;
    _reprintQueue = groups.sublist(1);
    _reprintPlanName = next.planLabel;
    context.read<PosAccountBloc>().add(
      PosAccountPlanEntryRequested(
        planKey: next.planKey,
        childIds: next.childIds,
      ),
    );
  }

  void _clearReprint() {
    _reprintPlanName = null;
    _reprintQueue = const [];
  }

  /// Null in widget tests that don't register the local store.
  static LocalSource? get _local =>
      sl.isRegistered<LocalSource>() ? sl<LocalSource>() : null;

  static bool _savedPrintParentQr() => _local?.getPrintParentQr() ?? false;

  PaymentMethod _topupMethod = PaymentMethod.cash;
  final _topupAmountController = TextEditingController();
  final _topupCashController = TextEditingController();
  final _topupCardController = TextEditingController();

  /// productId → qty of the extra goods (socks etc.) sold with this entry.
  final Map<String, int> _cart = {};

  /// Applies ONLY to the goods cart above — never the VIP/plan price or the
  /// HAMROH companion price. Reset on cart-owning context changes: customer
  /// switch, checkout, or the server reporting it is no longer available.
  String? _selectedDiscountId;

  /// "Chek chegirmasi" (Butun chek): one check-scope discount for every
  /// selected child. While set, per-child picks and the promo code are off.
  String? _checkDiscountId;

  /// "Balansdan yechish" — only offered while the balance covers the cart.
  bool _payFromBalance = true;

  PaymentMethod _payMethod = PaymentMethod.cash;
  final _payAmountController = TextEditingController();
  final _payCashController = TextEditingController();
  final _payCardController = TextEditingController();

  /// True once the cashier types in the payment field themselves — from
  /// then on the auto-prefill below keeps its hands off their value.
  bool _payEdited = false;

  /// The money panel's open tab — false: "Kirish", true: "To'ldirish".
  bool _topupTab = false;

  /// The editable "collect a different amount" field is folded away until
  /// the cashier asks for it — the check shows the amount owed.
  bool _showPayAmount = false;

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

  /// Confirms before crediting, then mints the idempotency key for that one
  /// confirmed top-up. The key is what makes a retried request — a lost
  /// response, a flaky link — record one top-up instead of two.
  Future<void> _confirmAndTopup(
    BuildContext context, {
    required Customer customer,
    required int amountUzs,
    required PaymentSplit split,
    required PaymentMethod method,
  }) async {
    final confirmed = await showConfirmTopupDialog(
      context,
      customer: customer,
      amountUzs: amountUzs,
      cashUzs: split.cashUzs,
      cardUzs: split.cardUzs,
      method: method,
    );
    if (confirmed != true || !context.mounted) return;
    context.read<PosAccountBloc>().add(
      PosAccountTopupRequested(
        amountUzs: amountUzs,
        cashUzs: split.cashUzs,
        cardUzs: split.cardUzs,
        requestId: const Uuid().v4(),
      ),
    );
  }

  void _resetFor(Customer? customer) {
    _clearReprint();
    _selectedChildIds.clear();
    _selectedPlan = null;
    _childEntryDiscountIds.clear();
    _promoChildId = null;
    _companions = 0;
    _addingChild = false;
    _childNameController.clear();
    _printParentQr = _savedPrintParentQr();
    _topupMethod = PaymentMethod.cash;
    _topupAmountController.clear();
    _topupCashController.clear();
    _topupCardController.clear();
    _cart.clear();
    _selectedDiscountId = null;
    _checkDiscountId = null;
    _payFromBalance = true;
    _payMethod = PaymentMethod.cash;
    _payEdited = false;
    _payAmountController.clear();
    _payCashController.clear();
    _payCardController.clear();
    _topupTab = false;
    _showPayAmount = false;
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
        // A failed re-print (or any failed request mid-queue) must not leave
        // its plan name armed for the next real checkout.
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.isBusy &&
              !current.isBusy &&
              current.lastEntryResult == null &&
              current.errorMessage != null,
          listener: (context, state) => _clearReprint(),
        ),
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.lastEntryResult != current.lastEntryResult &&
              current.lastEntryResult != null,
          listener: (context, state) async {
            final result = state.lastEntryResult!;
            final productReceipt =
                result.productSale ?? _legacyProductReceipt(result, state);
            if (productReceipt != null) {
              await printSaleReceiptDirect(context, productReceipt);
              if (!context.mounted) return;
            }
            final childNames = {
              for (final child
                  in state.selectedCustomer?.children ?? const <Child>[])
                child.id: child.fullName,
            };
            final reprintPlanName = _reprintPlanName;
            if (reprintPlanName != null) {
              // A re-print: the same QR again, nothing was charged — so no
              // price or discount on the ticket, and the cashier's picks in
              // steps 1–3 stay as they were.
              printPlanEntryLabels(
                context,
                result,
                childNames,
                planName: reprintPlanName,
              );
              context.read<PosAccountBloc>().add(
                const PosAccountEntryAcknowledged(),
              );
              if (_reprintQueue.isEmpty) {
                _clearReprint();
              } else {
                _startReprint(_reprintQueue);
              }
              return;
            }
            printPlanEntryLabels(
              context,
              result,
              childNames,
              planName: _selectedPlan?.name,
              planPriceUzs: (_selectedPlan?.isPrepaid ?? false)
                  ? _selectedPlan?.flatUzs
                  : null,
              entryDiscountsByChild: _checkoutEntryDiscounts,
              companionPriceUzs: state.companionPriceUzs,
            );
            // One checkout's discounts only — a plan-conflict retry is a
            // fresh request that carries none.
            _checkoutEntryDiscounts = const {};
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
                hourPlanKeys: {
                  for (final p in state.plans)
                    if (p.kind == KidsPlanKind.flatHour) p.key,
                },
                // The code was released (its child only got a conflict) —
                // still on screen, so the confirmed switch can carry it.
                promoCode:
                    state.promo != null &&
                        result.promoCode != null &&
                        !result.promoCode!.applied
                    ? (
                        code: state.promo!.code,
                        childId: result.promoCode!.childId,
                      )
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
            printPassesWithTicketFallback(
              ScaffoldMessenger.of(context),
              AppLocalization.of(context),
              stickers: [
                (qrData: pass.code, name: pass.customerName, invertName: true),
              ],
              tickets: [
                (
                  qrData: pass.code,
                  childName: pass.customerName,
                  planName: 'OTA-ONA',
                  priceUzs: 0,
                  discountUzs: 0,
                  discountName: null,
                  ticketId: pass.code.length > 8
                      ? pass.code.substring(0, 8)
                      : pass.code,
                ),
              ],
            );
            context.read<PosAccountBloc>().add(
              const PosAccountParentQrAcknowledged(),
            );
          },
        ),
        // The picked discount was disabled/deleted between fetch and
        // checkout — the bloc already refetches the catalog; the local
        // pick just needs clearing so the cashier re-selects from it.
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              current.errorCode == 'DISCOUNT_NOT_AVAILABLE' &&
              previous.errorCode != current.errorCode,
          listener: (context, state) {
            setState(() {
              _selectedDiscountId = null;
              _checkDiscountId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalization.of(context).discountUnavailableMessage,
                ),
              ),
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
          // Products the admin flagged for the "Qo'shimcha" step — sold from
          // the balance with a receipt (never a QR, unlike HAMROH).
          final extrasProducts = [
            for (final product in state.products)
              if (product.showInExtras) product,
          ];
          final cartLines = [
            for (final line in _cart.entries)
              if (productsById[line.key] case final product?)
                (
                  name: product.name,
                  qty: line.value,
                  totalUzs: product.priceUzs * line.value,
                ),
          ];
          // VIP and 1 soat are debited from the balance at issuance
          // (register prepay); Standard has no upfront tariff — it bills per
          // exit by actual minutes. Children already holding a live pass on
          // the SAME prepaid plan are not charged again — the backend just
          // re-returns their pass. A live VIP pass also covers a 1 soat
          // sale: the backend re-prints the VIP sticker and charges nothing
          // (spec decision 7, VIP → hour).
          final activePlanByChild = {
            for (final p in state.activePasses) p.childId: p.planKey,
          };
          // Plans whose live pass covers a 1 soat sale: every unlimited day
          // pass (built-in VIP and VIP-style custom day plans) and any
          // VIP-flagged flat plan. Resolved by kind/flag, never by one key.
          final coveringPlanKeys = {
            for (final p in state.plans)
              if (p.kind == KidsPlanKind.flatDay || (p.isVip && p.isPrepaid))
                p.key,
          };
          final plansByKey = {for (final p in state.plans) p.key: p};
          final hourSelected = _selectedPlan?.kind == KidsPlanKind.flatHour;
          final alreadyOnSelectedPlan = <String>{
            if (_selectedPlan?.isPrepaid ?? false)
              for (final id in _selectedChildIds)
                if (activePlanByChild[id] == _selectedPlan!.key ||
                    (hourSelected &&
                        coveringPlanKeys.contains(activePlanByChild[id])))
                  id,
          };
          // The partner promo code discounts ONE selected child. A child
          // with a pass today can't take it — the backend would fail that
          // child (a plain re-print included) rather than burn the code —
          // so the default skips those, and with none left the code stays
          // unsent until the cashier selects a child who can.
          final promo = state.promo;
          // A live pass blocks the code unless the selected plan is a
          // flat-day UPGRADE of it (1 soat/Standard → VIP): the backend
          // then discounts the new pass once the switch is confirmed. A
          // discounted or already-covering pass stays frozen.
          final upgradeTarget =
              _selectedPlan != null &&
              _selectedPlan!.kind == KidsPlanKind.flatDay;
          final passChildIds = {
            for (final p in state.activePasses)
              if (!(upgradeTarget &&
                  p.freeReason == null &&
                  p.discountId == null &&
                  p.planKey != _selectedPlan!.key &&
                  !coveringPlanKeys.contains(p.planKey)))
                p.childId,
          };
          final selectedChildren = [
            for (final child in customer.children)
              if (_selectedChildIds.contains(child.id)) child,
          ];
          final checkDiscount = _checkDiscountId == null
              ? null
              : state.checkDiscounts
                    .where((d) => d.id == _checkDiscountId)
                    .firstOrNull;
          // The order `childIds` is sent in, so the fixed amount's remainder
          // lands on the same child here as on the server.
          final orderedChildIds = _selectedChildIds.toList();
          final checkShares =
              checkDiscount?.checkShares(orderedChildIds.length) ??
              const <Discount>[];
          // A child with a live pass on another plan the selected one doesn't
          // cover comes back as a plan-switch conflict: no pass in this
          // request, and the confirmed retry goes without the check discount
          // (full price). It still counts in the split above — the server
          // splits over every sent childId — it just never takes its share.
          final switchConflictIds = <String>{
            for (final id in _selectedChildIds)
              if (activePlanByChild.containsKey(id) &&
                  !alreadyOnSelectedPlan.contains(id))
                id,
          };
          Discount? checkShareFor(String childId) =>
              switchConflictIds.contains(childId)
              ? null
              : checkShares[orderedChildIds.indexOf(childId)];
          final promoChildId = promo == null || checkDiscount != null
              ? null
              : _selectedChildIds.contains(_promoChildId)
              ? _promoChildId
              // A child with no pass at all first — the code applies right
              // away; an upgrade only after the switch is confirmed.
              : (selectedChildren
                            .where(
                              (c) => !state.activePasses.any(
                                (p) => p.childId == c.id,
                              ),
                            )
                            .firstOrNull ??
                        selectedChildren
                            .where((c) => !passChildIds.contains(c.id))
                            .firstOrNull)
                    ?.id;

          // A child with an entry discount pays the VIP / 1 soat price net of
          // it — a 100% discount (PREVIEW ONLY, same formula as the backend)
          // zeroes it exactly like the old free-reason flow did. The promo
          // child's discount is the code's tier, replacing any 3-dots pick.
          Discount? entryDiscountFor(String childId) {
            if (checkDiscount != null) return checkShareFor(childId);
            if (childId == promoChildId) return promo!.discount;
            final id = _childEntryDiscountIds[childId];
            if (id == null) return null;
            return state.entryDiscounts.where((d) => d.id == id).firstOrNull;
          }

          final vipTotal = (_selectedPlan?.isPrepaid ?? false)
              ? _selectedChildIds
                    .where((id) => !alreadyOnSelectedPlan.contains(id))
                    .fold<int>(0, (sum, id) {
                      final flat = _selectedPlan!.flatUzs ?? 0;
                      final discount = entryDiscountFor(id);
                      final discountUzs =
                          discount?.appliedDiscountUzs(flat) ?? 0;
                      return sum + (flat - discountUzs);
                    })
              : 0;
          // What the promo code takes off the prepaid tariff — shown as its
          // own row so a 100% code reads "Bepul", not a bare 0.
          final promoDiscountUzs =
              promoChildId != null &&
                  (_selectedPlan?.isPrepaid ?? false) &&
                  !alreadyOnSelectedPlan.contains(promoChildId)
              ? promo!.discount.appliedDiscountUzs(_selectedPlan!.flatUzs ?? 0)
              : 0;
          // What the check discount takes off the prepaid tariff — its own
          // row, like the promo code ([vipTotal] is already net of it).
          final checkDiscountUzs =
              checkDiscount != null && (_selectedPlan?.isPrepaid ?? false)
              ? orderedChildIds
                    .where((id) => !alreadyOnSelectedPlan.contains(id))
                    .fold<int>(
                      0,
                      (sum, id) =>
                          sum +
                          (checkShareFor(id)?.appliedDiscountUzs(
                                _selectedPlan!.flatUzs ?? 0,
                              ) ??
                              0),
                    )
              : 0;
          // Each child's own share, shown on its row: what it takes off the
          // prepaid tariff, or — on Standard, billed at exit — the share
          // itself. Nothing for a child that takes none (re-print, plan
          // switch, a fixed amount that floors to 0).
          String? checkShareLabel(String childId) {
            final share = checkShareFor(childId);
            if (share == null || alreadyOnSelectedPlan.contains(childId)) {
              return null;
            }
            if (_selectedPlan?.isPrepaid ?? false) {
              final off = share.appliedDiscountUzs(_selectedPlan!.flatUzs ?? 0);
              return off > 0 ? '−${formatUzs(off)}' : null;
            }
            if (share.value <= 0) return null;
            return share.kind == DiscountKind.percent
                ? '−${share.value}%'
                : '−${formatUzs(share.value)}';
          }

          final checkShareLabels = <String, String>{
            if (checkDiscount != null)
              for (final id in orderedChildIds)
                if (checkShareLabel(id) case final String label) id: label,
          };
          final companionsTotal = _companions * state.companionPriceUzs;
          // Discount applies ONLY to the goods cart — never to vipTotal or
          // companionsTotal (see the design doc's decision #1 scope note).
          final selectedDiscount = _selectedDiscountId == null
              ? null
              : state.discounts
                    .where((d) => d.id == _selectedDiscountId)
                    .firstOrNull;
          final cartDiscountUzs =
              selectedDiscount?.appliedDiscountUzs(cartTotal) ?? 0;
          final netCartTotal = cartTotal - cartDiscountUzs;
          final neededTotal = netCartTotal + vipTotal + companionsTotal;
          final shortfall = neededTotal - customer.balance;
          final balanceCovers = shortfall <= 0;
          // Money must be collected when the balance can't cover the total,
          // or when the cashier explicitly keeps the balance untouched.
          // "Balansdan yechish" OFF collects the whole check in cash/card
          // even when the balance can't cover it — the money is credited to
          // the balance and debited right back, so the balance stays as is.
          final requiredPayment = neededTotal == 0
              ? 0
              : balanceCovers
              ? (_payFromBalance ? 0 : neededTotal)
              : (_payFromBalance || customer.balance <= 0
                    ? shortfall
                    : neededTotal);

          // Default the payment field to exactly what's owed, so the
          // cashier confirms a number instead of typing it. Follows cart /
          // tariff changes until the cashier edits the field by hand.
          if (requiredPayment > 0 &&
              !_payEdited &&
              parseUzs(_payAmountController.text) != requiredPayment) {
            _payAmountController.text = groupDigits(requiredPayment);
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

          // A sale with no child is HAMROH / "Qo'shimcha" products alone.
          final hasEntry =
              _selectedPlan != null && _selectedChildIds.isNotEmpty;
          final extrasOnly =
              _selectedChildIds.isEmpty &&
              (_cart.isNotEmpty || _companions > 0);
          final canEnter =
              !state.isBusy && (hasEntry || extrasOnly) && paymentOk;

          final topupAmount =
              int.tryParse(_topupAmountController.text.replaceAll(' ', '')) ??
              0;
          final topupSplit = PaymentSplit.compute(
            method: _topupMethod,
            totalUzs: topupAmount,
            cashInput: _topupCashController.text,
            cardInput: _topupCardController.text,
          );
          final canTopup =
              !state.isBusy && topupAmount > 0 && topupSplit.isValid;

          final l10n = AppLocalization.of(context);
          final p = PosPalette.of(context);
          // What the balance pays of this checkout — everything the cashier
          // does not collect in cash/card.
          final fromBalanceUzs = _payFromBalance && customer.balance > 0
              ? (neededTotal - requiredPayment).clamp(0, neededTotal)
              : 0;

          final childrenCard = _ChildrenCard(
            customer: customer,
            activePasses: state.activePasses,
            insideMinutes: {
              for (final row in state.playing) row.childId: row.minutes,
            },
            selectedChildIds: _selectedChildIds,
            onToggleChild: (id) => setState(
              () => _selectedChildIds.contains(id)
                  ? _selectedChildIds.remove(id)
                  : _selectedChildIds.add(id),
            ),
            onRenameChild: (id, name) => context.read<PosAccountBloc>().add(
              PosAccountChildNameUpdateRequested(id, name),
            ),
            entryDiscounts: checkDiscount == null
                ? state.entryDiscounts
                : const [],
            childEntryDiscountIds: checkDiscount == null
                ? _childEntryDiscountIds
                : const {},
            checkShareLabels: checkShareLabels,
            promoChildId: promoChildId,
            promoLabel: promo == null ? null : promoCodeLabel(promo),
            onChildEntryDiscountChanged: (id, discountId) => setState(() {
              if (discountId == null) {
                _childEntryDiscountIds.remove(id);
              } else {
                _childEntryDiscountIds[id] = discountId;
              }
            }),
            addingChild: _addingChild,
            onStartAddChild: () => setState(() => _addingChild = true),
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
          );

          final tariffCard = _TariffCard(
            plans: state.plans,
            isLoadingPlans: state.isLoadingPlans,
            selectedPlan: _selectedPlan,
            onSelectPlan: (plan) => setState(() => _selectedPlan = plan),
          );

          final extrasCard = _ExtrasCard(
            products: extrasProducts,
            cart: _cart,
            onProductAdd: (id) =>
                setState(() => _cart[id] = (_cart[id] ?? 0) + 1),
            onProductRemove: (id) => setState(() {
              final qty = (_cart[id] ?? 0) - 1;
              if (qty <= 0) {
                _cart.remove(id);
              } else {
                _cart[id] = qty;
              }
            }),
            companions: _companions,
            companionPriceUzs: state.companionPriceUzs,
            onCompanionAdd: () => setState(() => _companions += 1),
            onCompanionRemove: () => setState(
              () => _companions = _companions > 0 ? _companions - 1 : 0,
            ),
            promoSection: checkDiscount != null
                ? Text(
                    l10n.checkDiscountLocked,
                    style: p.bodyMuted.copyWith(fontSize: 11.5),
                  )
                : _PromoSection(
                    promo: promo,
                    isChecking: state.isCheckingPromo,
                    errorText: promoCodeErrorText(l10n, state),
                    label: promo == null ? null : promoCodeLabel(promo),
                    selectedChildren: selectedChildren,
                    passChildIds: passChildIds,
                    promoChildId: promoChildId,
                    onSubmit: (raw) => context.read<PosAccountBloc>().add(
                      PosAccountPromoCodeSubmitted(raw),
                    ),
                    onChildPicked: (id) => setState(() => _promoChildId = id),
                    onClear: () => context.read<PosAccountBloc>().add(
                      const PosAccountPromoCodeCleared(),
                    ),
                  ),
            // Always on screen; greyed with the reason until it can be used.
            checkDiscountHint: state.checkDiscounts.isEmpty
                ? l10n.accountNoCheckDiscounts
                : _selectedChildIds.isEmpty
                ? l10n.accountPickChildFirst
                : null,
            checkDiscountButton:
                state.checkDiscounts.isEmpty || _selectedChildIds.isEmpty
                ? null
                : CheckDiscountButton(
                    discounts: state.checkDiscounts,
                    selected: checkDiscount,
                    onChanged: (discount) {
                      setState(() {
                        _checkDiscountId = discount?.id;
                        if (discount != null) {
                          _childEntryDiscountIds.clear();
                        }
                      });
                      if (discount != null && state.promo != null) {
                        context.read<PosAccountBloc>().add(
                          const PosAccountPromoCodeCleared(),
                        );
                      }
                    },
                  ),
          );

          final checkout = _CheckoutSection(
            // Products are sold from the dedicated "Savdo" tab only — never
            // shown/sellable from this per-child plan-entry checkout. Passing
            // an empty list (not touching `_CheckoutSection` itself) keeps
            // every downstream total/discount/payment computation working
            // exactly as it already does for an empty cart.
            products: const [],
            checkDiscountUzs: checkDiscountUzs,
            checkDiscountName: checkDiscount == null
                ? null
                : checkDiscountLabel(checkDiscount),
            cart: _cart,
            cartTotal: cartTotal,
            cartLines: cartLines,
            discounts: state.discounts,
            selectedDiscount: selectedDiscount,
            cartDiscountUzs: cartDiscountUzs,
            onDiscountChanged: (discount) =>
                setState(() => _selectedDiscountId = discount?.id),
            vipTotal: vipTotal,
            promoDiscountUzs: promoDiscountUzs,
            promoName: promo == null ? null : promoCodeLabel(promo),
            planName: _selectedPlan?.name,
            planPrepaid: _selectedPlan?.isPrepaid ?? false,
            companions: _companions,
            companionsTotal: companionsTotal,
            neededTotal: neededTotal,
            balance: customer.balance,
            fromBalanceUzs: fromBalanceUzs,
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
            onPayMethodChanged: (m) => setState(() {
              // "Aralash" starts as all-cash; typing either half fills the
              // other with the remainder.
              if (m == PaymentMethod.split &&
                  _payCashController.text.isEmpty &&
                  _payCardController.text.isEmpty) {
                _payCashController.text = groupDigits(payAmount);
                _payCardController.text = '0';
              }
              _payMethod = m;
            }),
            payAmountController: _payAmountController,
            payCashController: _payCashController,
            payCardController: _payCardController,
            paySplit: paySplit,
            payAmount: payAmount,
            onChanged: () => setState(() {}),
            onAdd: (id) => setState(() => _cart[id] = (_cart[id] ?? 0) + 1),
            onRemove: (id) => setState(() {
              final qty = (_cart[id] ?? 0) - 1;
              if (qty <= 0) {
                _cart.remove(id);
              } else {
                _cart[id] = qty;
              }
            }),
            selectedChildCount: _selectedChildIds.length,
            alreadyNotes: [
              for (final child in customer.children)
                if (alreadyOnSelectedPlan.contains(child.id))
                  _alreadyActiveNote(
                    l10n,
                    child.fullName,
                    _selectedPlan!,
                    activePlanByChild[child.id],
                    plansByKey,
                  ),
            ],
            printParentQr: _printParentQr,
            onPrintParentQrChanged: (v) {
              setState(() => _printParentQr = v);
              _local?.setPrintParentQr(v);
            },
            showPayAmount: _showPayAmount,
            onShowPayAmount: () => setState(() => _showPayAmount = true),
            canSubmit: canEnter,
            isBusy: state.isBusy,
            onSubmit: () {
              // With a check discount, entryDiscountFor() is the child's
              // share — the printed ticket shows it.
              _checkoutEntryDiscounts = {
                for (final id in _selectedChildIds)
                  if (!alreadyOnSelectedPlan.contains(id))
                    id: ?entryDiscountFor(id),
              };
              context.read<PosAccountBloc>().add(
                PosAccountCheckoutRequested(
                  planKey: hasEntry ? _selectedPlan!.key : null,
                  childIds: hasEntry ? orderedChildIds : const [],
                  withParentQr: hasEntry && _printParentQr,
                  entryDiscounts: checkDiscount != null
                      ? const {}
                      : {
                          for (final entry in _childEntryDiscountIds.entries)
                            if (_selectedChildIds.contains(entry.key) &&
                                entry.key != promoChildId)
                              entry.key: entry.value,
                        },
                  checkDiscountId: checkDiscount?.id,
                  promoCode: promoChildId == null
                      ? null
                      : (code: promo!.code, childId: promoChildId),
                  companions: _companions,
                  products: [
                    for (final line in _cart.entries)
                      (productId: line.key, qty: line.value),
                  ],
                  cashUzs: requiredPayment == 0 ? 0 : paySplit.cashUzs,
                  cardUzs: requiredPayment == 0 ? 0 : paySplit.cardUzs,
                  discountId: _selectedDiscountId,
                ),
              );
            },
          );

          final topup = _BalanceCard(
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
            onTopup: () => _confirmAndTopup(
              context,
              customer: customer,
              amountUzs: topupAmount,
              split: topupSplit,
              method: _topupMethod,
            ),
          );

          _MoneyPanel moneyPanel({required bool pinned}) => _MoneyPanel(
            topupTab: _topupTab,
            onTabChanged: (topupTab) => setState(() => _topupTab = topupTab),
            entry: checkout,
            topup: topup,
            pinned: pinned,
          );

          final header = _SummaryStrip(
            customer: customer,
            isBusy: state.isBusy,
            insideCount: state.playing.length,
            onRename: (name) => context.read<PosAccountBloc>().add(
              PosAccountCustomerNameUpdateRequested(name),
            ),
            onRefresh: () => context.read<PosAccountBloc>().add(
              const PosAccountCustomerRefreshRequested(),
            ),
            onParentQr: () => context.read<PosAccountBloc>().add(
              const PosAccountParentQrRequested(),
            ),
            onBack: () => context.read<PosAccountBloc>().add(
              const PosAccountSelectionCleared(),
            ),
          );
          // Left: who + which tariff + extras, top-down. Right: money only —
          // enter or top up, one big button each.
          final steps = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              childrenCard,
              const SizedBox(height: 14),
              tariffCard,
              const SizedBox(height: 14),
              extrasCard,
            ],
          );
          // Everything that is reference, not part of the sale.
          final below = <Widget>[
            if (state.playing.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PlayingCard(
                rows: state.playing,
                balance: customer.balance,
                onRefresh: () => context.read<PosAccountBloc>().add(
                  const PosAccountPlayingRequested(),
                ),
              ),
            ],
            // Folded by default; keyed by customer so the next one starts
            // folded too.
            const SizedBox(height: 14),
            TodayPassesCard(
              passes: state.activePasses,
              childNames: {
                for (final child in customer.children) child.id: child.fullName,
              },
              busy: state.isBusy,
              onReprint: _startReprint,
              onStale: () => context.read<PosAccountBloc>().add(
                const PosAccountActivePassesRequested(),
              ),
            ),
            if (state.activePasses.isNotEmpty) const SizedBox(height: 14),
            TransactionsAccordion(key: ValueKey(customer.id)),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: p.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: p.danger, fontSize: 13),
                ),
              ),
            ],
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              // Too narrow for two panes (or hosted in something that gives
              // no height to split): one page, money panel after the steps.
              if (constraints.maxWidth < 720 || !constraints.hasBoundedHeight) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 14),
                      steps,
                      const SizedBox(height: 14),
                      moneyPanel(pinned: false),
                      ...below,
                    ],
                  ),
                );
              }
              // Two panes: the steps scroll on the left while the money panel
              // stays on screen on the right — at 800 px the cashier never
              // scrolls to find "To'lov va chop etish".
              final moneyWidth = constraints.maxWidth >= 1280
                  ? 420.0
                  : constraints.maxWidth >= 1000
                  ? 380.0
                  : 330.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [steps, ...below],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        SizedBox(
                          width: moneyWidth,
                          child: moneyPanel(pinned: true),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  SaleReceipt? _legacyProductReceipt(
    PosEntryResult result,
    PosAccountState state,
  ) {
    if (result.productsTotalUzs <= 0 || _cart.isEmpty) return null;
    final productsById = {
      for (final product in state.products) product.id: product,
    };
    final items = <SaleReceiptItem>[
      for (final line in _cart.entries)
        if (productsById[line.key] case final product?)
          SaleReceiptItem(
            productId: product.id,
            nameSnapshot: product.name,
            priceSnapshotUzs: product.priceUzs,
            qty: line.value,
            lineTotalUzs: product.priceUzs * line.value,
          ),
    ];
    if (items.isEmpty) return null;
    final now = DateTime.now();
    return SaleReceipt(
      id: 'account-${state.selectedCustomer?.id ?? 0}-${now.millisecondsSinceEpoch}',
      subtotalUzs: result.productsTotalUzs,
      cashUzs: 0,
      cardUzs: 0,
      balanceUzs: result.productsTotalUzs,
      createdAt: now,
      items: items,
    );
  }
}

class _InlineEditableName extends StatefulWidget {
  const _InlineEditableName({
    required this.value,
    required this.style,
    required this.onSave,
    this.enabled = true,
    this.pencilOnHover = false,
  });

  final String value;
  final TextStyle style;
  final ValueChanged<String> onSave;
  final bool enabled;

  /// Child tiles show the pencil only under the mouse — a column of
  /// pencils is noise; the name stays tap-to-rename either way.
  final bool pencilOnHover;

  @override
  State<_InlineEditableName> createState() => _InlineEditableNameState();
}

class _InlineEditableNameState extends State<_InlineEditableName> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _editing = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _InlineEditableName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled) return;
    setState(() => _editing = true);
    _controller.text = widget.value;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _cancel() {
    _controller.text = widget.value;
    setState(() => _editing = false);
  }

  void _save() {
    final value = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (value.isEmpty) return;
    setState(() => _editing = false);
    if (value != widget.value.trim()) widget.onSave(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    if (!_editing) {
      final showPencil = widget.enabled && (!widget.pencilOnHover || _hovered);
      return Tooltip(
        message: l10n.fullName,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: InkWell(
            onTap: _start,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.value,
                      style: widget.style,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.enabled) ...[
                    const SizedBox(width: 6),
                    // Space is kept while hidden so the name never jumps.
                    Opacity(
                      opacity: showPencil ? 1 : 0,
                      child: Icon(
                        PhosphorIconsRegular.pencilSimple,
                        size: 14,
                        color: PosPalette.of(context).textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 38,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        maxLength: 150,
        textInputAction: TextInputAction.done,
        style: widget.style,
        onSubmitted: (_) => _save(),
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 68),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.cancel,
                onPressed: _cancel,
                icon: const Icon(PhosphorIconsRegular.x, size: 16),
              ),
              IconButton(
                tooltip: l10n.save,
                onPressed: _save,
                icon: const Icon(PhosphorIconsRegular.check, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Already on a pass — no second charge" line for a child who holds a live
/// pass on the selected plan, or on a covering VIP/day pass. The built-in
/// VIP and 1 soat keep their own wording; any other plan is named.
String _alreadyActiveNote(
  AppLocalization l10n,
  String childName,
  KidsPlan selected,
  String? activeKey,
  Map<String, KidsPlan> plansByKey,
) {
  final holdKey = activeKey ?? selected.key;
  if (holdKey == 'vip') return l10n.vipAlreadyActive(childName);
  if (holdKey == 'hour') return l10n.hourAlreadyActive(childName);
  final name = (holdKey == selected.key ? selected : plansByKey[holdKey])?.name;
  return l10n.planAlreadyActive(childName, name ?? holdKey);
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.customer,
    required this.isBusy,
    required this.insideCount,
    required this.onParentQr,
    required this.onRename,
    required this.onRefresh,
    required this.onBack,
  });

  final Customer customer;
  final bool isBusy;

  /// Children of this customer inside the park right now.
  final int insideCount;

  /// Prints the customer's free parent QR — the ruleless both-direction
  /// day sticker for the accompanying adult.
  final VoidCallback onParentQr;
  final ValueChanged<String> onRename;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final displayName = customer.fullName.isEmpty
        ? customer.phoneNumber
        : customer.fullName;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Under ~900 px the name needs the room: the parent-QR button keeps
        // only its icon and the "inside" chip only its count.
        final narrow = constraints.maxWidth < 900;
        return AccountCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Icon(PhosphorIconsRegular.arrowLeft, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              AccountAvatar(name: displayName, size: 46),
              const SizedBox(width: 12),
              // Name block takes the free width, so the actions and the balance
              // box always sit flush right.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _InlineEditableName(
                            value: displayName,
                            enabled: !isBusy && customer.fullName.isNotEmpty,
                            style: p.title.copyWith(fontSize: 18),
                            onSave: onRename,
                          ),
                          Text(
                            formatPhoneNumber(customer.phoneNumber),
                            style: p.bodyMuted.copyWith(fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (insideCount > 0) ...[
                      const SizedBox(width: 12),
                      Tooltip(
                        message: l10n.accountInsideCount(insideCount),
                        child: StatusChip(
                          label: narrow
                              ? '$insideCount'
                              : l10n.accountInsideCount(insideCount),
                          icon: PhosphorIconsRegular.doorOpen,
                          tone: ChipTone.positive,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: l10n.refresh,
                  onPressed: isBusy ? null : onRefresh,
                  icon: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          PhosphorIconsRegular.arrowsClockwise,
                          size: 18,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              if (narrow)
                IconButton.outlined(
                  tooltip: l10n.parentQr,
                  onPressed: isBusy ? null : onParentQr,
                  icon: const Icon(PhosphorIconsRegular.qrCode, size: 18),
                )
              else
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onParentQr,
                    icon: const Icon(PhosphorIconsRegular.qrCode, size: 16),
                    label: Text(l10n.parentQr),
                  ),
                ),
              const SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: narrow ? 12 : 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.accentBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.balance.toUpperCase(),
                      style: AppTextStyles.kicker.copyWith(color: p.accent),
                    ),
                    Text(
                      formatUzs(customer.balance),
                      style: AppTextStyles.h4.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: p.accentStrong,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Step 1 — "Kim kiradi?": one tile per child (tap toggles it into the
/// checkout), its pass/discount badges, and the inline "add child" form.
class _ChildrenCard extends StatelessWidget {
  const _ChildrenCard({
    required this.customer,
    required this.activePasses,
    required this.selectedChildIds,
    required this.onToggleChild,
    required this.onRenameChild,
    required this.entryDiscounts,
    required this.childEntryDiscountIds,
    required this.onChildEntryDiscountChanged,
    required this.promoChildId,
    required this.promoLabel,
    required this.checkShareLabels,
    required this.addingChild,
    required this.onStartAddChild,
    required this.onCancelAddChild,
    required this.childNameController,
    required this.onSubmitAddChild,
    required this.insideMinutes,
  });

  final Customer customer;

  /// childId → minutes played so far, for children inside right now.
  final Map<String, int> insideMinutes;

  /// Children's still-valid day passes — powers the per-tile plan badge so
  /// staff see "already on Standart today" BEFORE picking a tariff.
  final List<ActivePass> activePasses;
  final Set<String> selectedChildIds;
  final ValueChanged<String> onToggleChild;
  final void Function(String childId, String fullName) onRenameChild;

  /// Active ENTRY-scoped discount catalog — the tile's 3-dots menu picks
  /// from this list; empty hides the menu (best-effort catalog fetch).
  final List<Discount> entryDiscounts;

  /// Optional per-child entry discount picked from the tile's 3-dots menu —
  /// null discountId in the callback clears the child's pick.
  final Map<String, String> childEntryDiscountIds;
  final void Function(String childId, String? discountId)
  onChildEntryDiscountChanged;

  /// The child the verified promo code discounts, and its chip text —
  /// both null without a code.
  final String? promoChildId;
  final String? promoLabel;

  /// childId → that child's share of the selected check discount
  /// ("−10 000 so'm" / "−10%"), shown as a badge on its tile. Empty when no
  /// check discount is picked.
  final Map<String, String> checkShareLabels;
  final bool addingChild;
  final VoidCallback onStartAddChild;
  final VoidCallback onCancelAddChild;
  final TextEditingController childNameController;
  final VoidCallback onSubmitAddChild;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final selCount = selectedChildIds.length;
    final passByChildId = {for (final pass in activePasses) pass.childId: pass};
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            step: 1,
            title: l10n.accountStepWho,
            trailing: Text(
              selCount > 0
                  ? l10n.selectedCount(selCount)
                  : customer.children.isEmpty
                  ? l10n.noChildren
                  : l10n.selectForQr,
              style: AppTextStyles.body.copyWith(
                fontSize: 12.5,
                fontWeight: selCount > 0 ? FontWeight.w600 : null,
                color: selCount > 0 ? p.accent : p.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 640
                  ? 3
                  : constraints.maxWidth >= 340
                  ? 2
                  : 1;
              final tiles = <Widget>[
                for (final child in customer.children)
                  _ChildRow(
                    child: child,
                    activePass: passByChildId[child.id],
                    selected: selectedChildIds.contains(child.id),
                    onToggle: () => onToggleChild(child.id),
                    onRename: (name) => onRenameChild(child.id, name),
                    entryDiscounts: entryDiscounts,
                    selectedDiscountId: childEntryDiscountIds[child.id],
                    onEntryDiscountChanged: (discountId) =>
                        onChildEntryDiscountChanged(child.id, discountId),
                    promoLabel: child.id == promoChildId ? promoLabel : null,
                    checkShareLabel: checkShareLabels[child.id],
                    insideMinutes: insideMinutes[child.id],
                  ),
                if (!addingChild)
                  _AddChildTile(label: l10n.quickAdd, onTap: onStartAddChild),
              ];
              // A grid whose rows share one height, so a tile with badges
              // never leaves its neighbours looking short.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var start = 0; start < tiles.length; start += columns)
                    Padding(
                      padding: EdgeInsets.only(top: start == 0 ? 0 : 10),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = start; i < start + columns; i++) ...[
                              if (i > start) const SizedBox(width: 10),
                              Expanded(
                                child: i < tiles.length
                                    ? tiles[i]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          if (addingChild) ...[
            const SizedBox(height: 12),
            // Listens to the controller directly so the submit button
            // enables the moment a valid name is typed — the parent
            // doesn't rebuild on keystrokes.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: childNameController,
              builder: (context, value, _) {
                final canSubmit = value.text.trim().length >= 2;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: childNameController,
                        autofocus: true,
                        style: p.body,
                        onSubmitted: (_) {
                          if (canSubmit) onSubmitAddChild();
                        },
                        decoration: InputDecoration(
                          hintText: l10n.childName,
                          prefixIcon: const Icon(
                            PhosphorIconsRegular.userPlus,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: canSubmit ? onSubmitAddChild : null,
                        icon: const Icon(PhosphorIconsRegular.plus, size: 15),
                        label: Text(l10n.add),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: onCancelAddChild,
                        child: Text(l10n.cancel),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AddChildTile extends StatelessWidget {
  const _AddChildTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.accentBorder, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: p.accentSoft,
        child: SizedBox(
          height: 74,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsRegular.plus, size: 16, color: p.accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: p.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One child as a selectable tile: checkbox, name (tap to rename), and
/// badges — today's pass, the promo code, a 3-dots entry discount or the
/// check discount share. The "QR" chip mirrors the selection.
class _ChildRow extends StatelessWidget {
  const _ChildRow({
    required this.child,
    required this.activePass,
    required this.selected,
    required this.onToggle,
    required this.onRename,
    required this.entryDiscounts,
    required this.selectedDiscountId,
    required this.onEntryDiscountChanged,
    this.promoLabel,
    this.checkShareLabel,
    this.insideMinutes,
  });

  final Child child;

  /// Minutes played so far when the child is inside right now, else null.
  final int? insideMinutes;

  /// The child's still-valid day pass, or null — shown as a badge (plan +
  /// today's running cost) so the cashier both notices the existing tariff
  /// before printing and can answer a parent's "qancha bo'ldi?" on sight.
  final ActivePass? activePass;
  final bool selected;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;

  /// Active ENTRY-scoped discount catalog — the menu below picks from this
  /// list instead of the old hardcoded `FreeReason` enum.
  final List<Discount> entryDiscounts;

  /// This checkout's entry-discount pick for the child, or null (bills
  /// normally). Chosen from the 3-dots menu; null in the callback clears.
  final String? selectedDiscountId;
  final ValueChanged<String?> onEntryDiscountChanged;

  /// Set on the child the partner promo code discounts — shown instead of
  /// the 3-dots pick (the code's tier replaces it), and the menu is hidden.
  final String? promoLabel;

  /// This child's share of the selected check discount ("−10 000 so'm"),
  /// or null — a badge, since the check discount replaces the 3-dots pick.
  final String? checkShareLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final hasPromo = promoLabel != null;
    final selectedDiscount = selectedDiscountId == null || hasPromo
        ? null
        : entryDiscounts.where((d) => d.id == selectedDiscountId).firstOrNull;
    final today = DateTime.now();
    final age =
        today.year -
        child.birthDate.year -
        ((today.month < child.birthDate.month ||
                (today.month == child.birthDate.month &&
                    today.day < child.birthDate.day))
            ? 1
            : 0);
    final radius = BorderRadius.circular(12);
    return Material(
      color: selected ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: selected ? p.accent : p.border, width: 1.5),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                key: const ValueKey('child-select'),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: selected ? p.accent : p.surface,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected ? p.accent : p.borderStrong,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(PhosphorIconsBold.check, size: 13, color: p.onAccent)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _InlineEditableName(
                      value: child.fullName,
                      style: p.heading.copyWith(fontSize: 14.5),
                      onSave: onRename,
                      pencilOnHover: true,
                    ),
                    if (age > 0)
                      Text(
                        l10n.accountAgeYears(age),
                        style: p.bodyMuted.copyWith(fontSize: 12),
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (insideMinutes != null)
                          StatusChip(
                            label: l10n.accountInsideMinutes(insideMinutes!),
                            icon: PhosphorIconsRegular.doorOpen,
                            tone: ChipTone.positive,
                          ),
                        // Inside right now → the "Hozir ichkarida" table
                        // already carries the pass and its running cost.
                        if (activePass != null && insideMinutes == null)
                          StatusChip(
                            label:
                                '${activePass!.planLabel} · ${_activePassBadge(l10n, activePass!)}',
                            icon: PhosphorIconsRegular.ticket,
                            tone: ChipTone.neutral,
                          ),
                        if (hasPromo)
                          StatusChip(
                            label: promoLabel!,
                            icon: PhosphorIconsRegular.qrCode,
                          ),
                        if (selectedDiscount != null)
                          StatusChip(
                            label: '${l10n.discount}: ${selectedDiscount.name}',
                            tone: ChipTone.positive,
                          ),
                        if (checkShareLabel != null)
                          StatusChip(
                            label: checkShareLabel!,
                            tone: ChipTone.positive,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!hasPromo &&
                  (entryDiscounts.isNotEmpty ||
                      selectedDiscountId != null)) ...[
                const SizedBox(width: 10),
                // Round 3-dots button (no label — it used to crowd the child's
                // name): opens the grid dialog; filled once a discount is set.
                Tooltip(
                  key: const ValueKey('child-discount-button'),
                  message: l10n.discount,
                  child: Material(
                    color: selectedDiscount == null ? p.accentSoft : p.accent,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: selectedDiscount == null
                            ? p.accentBorder
                            : p.accent,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () async {
                        final pick = await showEntryDiscountDialog(
                          context,
                          discounts: entryDiscounts,
                          selectedId: selectedDiscountId,
                        );
                        if (pick != null) onEntryDiscountChanged(pick.id);
                      },
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          PhosphorIconsBold.dotsThreeVertical,
                          size: 18,
                          color: selectedDiscount == null
                              ? p.accentStrong
                              : p.onAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// LEGACY passes show the raw free-reason label; new passes show the
  /// discount name when fully free, or the running due amount otherwise (a
  /// partial discount is already netted into `dueTodayUzs` server-side).
  String _activePassBadge(AppLocalization l10n, ActivePass pass) {
    if (pass.freeReason != null) return l10n.free;
    if (pass.dueTodayUzs == 0 && pass.discountName != null) return l10n.free;
    return formatUzs(pass.dueTodayUzs);
  }
}

/// Step 2 — the tariff. Standard bills at exit by played time; VIP / 1 soat
/// / custom plans are debited from the balance immediately at printing.
class _TariffCard extends StatelessWidget {
  const _TariffCard({
    required this.plans,
    required this.isLoadingPlans,
    required this.selectedPlan,
    required this.onSelectPlan,
  });

  /// Standard/VIP, plus 1 soat when the backend has it switched on.
  final List<KidsPlan> plans;
  final bool isLoadingPlans;
  final KidsPlan? selectedPlan;
  final ValueChanged<KidsPlan> onSelectPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(step: 2, title: l10n.tariff),
          const SizedBox(height: 14),
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
                borderRadius: BorderRadius.circular(10),
                color: p.surfaceMuted,
              ),
              child: Text(
                l10n.tariffNotFound,
                style: p.bodyMuted.copyWith(fontSize: 12.5),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Up to 3 cards per row; any number of custom plans wrap.
                final perRow = plans.length < 3 ? plans.length : 3;
                final width =
                    (constraints.maxWidth - 10 * (perRow - 1)) / perRow;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final plan in plans)
                      SizedBox(
                        width: width,
                        child: _TariffPill(
                          plan: plan,
                          selected: selectedPlan?.key == plan.key,
                          onTap: () => onSelectPlan(plan),
                        ),
                      ),
                  ],
                );
              },
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

  IconData get _icon => switch (plan.kind) {
    KidsPlanKind.flatDay => PhosphorIconsRegular.crownSimple,
    KidsPlanKind.flatHour =>
      plan.isVip
          ? PhosphorIconsRegular.crownSimple
          : PhosphorIconsRegular.timer,
    KidsPlanKind.perMinuteTiers => PhosphorIconsRegular.ticket,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final priceLabel = switch (plan.kind) {
      KidsPlanKind.flatDay => l10n.pricePerDay(formatUzs(plan.flatUzs ?? 0)),
      KidsPlanKind.flatHour =>
        plan.durationMinutes == null || plan.durationMinutes == 60
            ? l10n.pricePerHour(formatUzs(plan.flatUzs ?? 0))
            : '${l10n.minutesCount(plan.durationMinutes!)} · '
                  '${formatUzs(plan.flatUzs ?? 0)}',
      KidsPlanKind.perMinuteTiers => l10n.priceFromPerMinute(
        formatUzs(plan.firstMinuteUzs ?? 0),
      ),
    };
    final iconColor = switch (plan.kind) {
      _ when plan.isVip => p.warning,
      KidsPlanKind.flatHour => p.positive,
      _ => p.accent,
    };
    final radius = BorderRadius.circular(12);
    // The selected card gets a soft focus ring on top of its blue border.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: selected
            ? [BoxShadow(color: p.accentBorder, spreadRadius: 3)]
            : null,
      ),
      child: Material(
        color: selected ? p.accentSoft : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? p.accent : p.border, width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(_icon, size: 17, color: iconColor),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: p.heading.copyWith(
                          fontSize: 14,
                          color: selected ? p.accent : p.text,
                        ),
                      ),
                    ),
                    if (plan.isVip) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.warningSoft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'VIP',
                          style: AppTextStyles.body.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: p.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    priceLabel,
                    maxLines: 1,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: p.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.isPrepaid ? l10n.accountPayNow : l10n.accountPayAtExit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: p.bodyMuted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 3 — optional extras: paid HAMROH companion stickers and the
/// whole-check discount.
class _ExtrasCard extends StatelessWidget {
  const _ExtrasCard({
    required this.products,
    required this.cart,
    required this.onProductAdd,
    required this.onProductRemove,
    required this.companions,
    required this.companionPriceUzs,
    required this.onCompanionAdd,
    required this.onCompanionRemove,
    required this.checkDiscountButton,
    required this.checkDiscountHint,
    required this.promoSection,
  });

  /// The admin's "Qo'shimcha" products (e.g. a nanny service) and their
  /// qty in the checkout cart — debited from the balance, printed as a
  /// receipt line.
  final List<Product> products;
  final Map<String, int> cart;
  final ValueChanged<String> onProductAdd;
  final ValueChanged<String> onProductRemove;

  /// Paid HAMROH companion stickers: qty and unit price (server-owned) —
  /// joins the checkout total and the normal payment flow.
  final int companions;
  final int companionPriceUzs;
  final VoidCallback onCompanionAdd;
  final VoidCallback onCompanionRemove;

  /// "Chek chegirmasi" picker — null while it can't be used; then a greyed
  /// tile says why ([checkDiscountHint]).
  final Widget? checkDiscountButton;
  final String? checkDiscountHint;

  /// The "Promokod" field, the verified code's chip, or — with a check
  /// discount picked — the note that the code is off.
  final Widget promoSection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    // Paid HAMROH companion sticker — parent-QR door semantics, minted by
    // the same checkout and settled through the same payment flow.
    final hamroh = _ExtraItemTile(
      leading: Icon(PhosphorIconsRegular.usersThree, size: 20, color: p.accent),
      title: 'HAMROH QR',
      subtitle: l10n.companionDescription(formatUzs(companionPriceUzs)),
      qty: companions,
      onAdd: onCompanionAdd,
      onRemove: onCompanionRemove,
    );
    final productTiles = [
      for (final product in products)
        _ExtraItemTile(
          key: ValueKey('extra-${product.id}'),
          leading: SizedBox.square(
            dimension: 36,
            child: ProductImage(product: product),
          ),
          title: product.name,
          subtitle: formatUzs(product.priceUzs),
          qty: cart[product.id] ?? 0,
          onAdd: () => onProductAdd(product.id),
          onRemove: () => onProductRemove(product.id),
        ),
    ];
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            step: 3,
            title: l10n.accountStepExtras,
            subtitle: '— ${l10n.accountOptional}',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final discount =
                  checkDiscountButton ??
                  _UnavailableTile(
                    icon: PhosphorIconsRegular.percent,
                    title: l10n.checkDiscount,
                    hint: checkDiscountHint ?? '',
                  );
              final tiles = [hamroh, ...productTiles, discount];
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, tile) in tiles.indexed) ...[
                      if (i > 0) const SizedBox(height: 10),
                      tile,
                    ],
                  ],
                );
              }
              // Two per row, each pair as tall as its taller tile.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < tiles.length; i += 2) ...[
                    if (i > 0) const SizedBox(height: 10),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: tiles[i]),
                          const SizedBox(width: 10),
                          Expanded(
                            child: i + 1 < tiles.length
                                ? tiles[i + 1]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          promoSection,
        ],
      ),
    );
  }
}

/// One "Qo'shimcha" item with a − qty + stepper: HAMROH or a product.
class _ExtraItemTile extends StatelessWidget {
  const _ExtraItemTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final active = qty > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? p.accent : p.border,
          width: active ? 1.5 : 1,
        ),
        color: active ? p.accentSoft : Colors.transparent,
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: p.heading.copyWith(
                    fontSize: 13.5,
                    color: active ? p.accent : p.text,
                  ),
                ),
                Text(subtitle, style: p.bodyMuted.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          _StepButton(
            icon: PhosphorIconsRegular.minus,
            onTap: active ? onRemove : null,
          ),
          SizedBox(
            width: 34,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: p.heading.copyWith(color: active ? p.accent : p.text),
            ),
          ),
          _StepButton(icon: PhosphorIconsRegular.plus, onTap: onAdd),
        ],
      ),
    );
  }
}

/// A greyed picker tile that says why it can't be used yet.
class _UnavailableTile extends StatelessWidget {
  const _UnavailableTile({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: p.heading.copyWith(fontSize: 13.5, color: p.textMuted),
                ),
                Text(hint, style: p.bodyMuted.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          Icon(PhosphorIconsRegular.caretDown, size: 16, color: p.textFaint),
        ],
      ),
    );
  }
}

/// The right-hand money panel: "Kirish" (pay for this entry) and
/// "To'ldirish" (top up the balance) — one job per tab, one big button each.
class _MoneyPanel extends StatelessWidget {
  const _MoneyPanel({
    required this.topupTab,
    required this.onTabChanged,
    required this.entry,
    required this.topup,
    this.pinned = false,
  });

  final bool topupTab;
  final ValueChanged<bool> onTabChanged;
  final _CheckoutSection entry;
  final Widget topup;

  /// True in the two-pane layout: the panel fills the pane's height, its
  /// content scrolls and the submit button stays pinned at the bottom.
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final parts = topupTab
        ? null
        : entry.parts(context, amountOnAction: pinned);
    // Only the active tab is built — its controllers live in the panel's
    // state, so switching back keeps what was typed.
    final content = topupTab ? topup : parts!.body;
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: pinned ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PanelTab(
                    icon: PhosphorIconsRegular.doorOpen,
                    label: l10n.enter,
                    selected: !topupTab,
                    onTap: () => onTabChanged(false),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _PanelTab(
                    icon: PhosphorIconsRegular.wallet,
                    label: l10n.topup,
                    selected: topupTab,
                    onTap: () => onTabChanged(true),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (pinned)
            Expanded(child: SingleChildScrollView(child: content))
          else
            content,
          if (parts != null) ...[const SizedBox(height: 10), parts.action],
        ],
      ),
    );
  }
}

class _PanelTab extends StatelessWidget {
  const _PanelTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final fg = selected ? p.accent : p.textMuted;
    return Material(
      color: selected ? p.surface : Colors.transparent,
      elevation: selected ? 1 : 0,
      shadowColor: const Color(0x14000000),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 42,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tinted one-line hint — "balance covers it", "debited at exit".
class _Note extends StatelessWidget {
  const _Note({required this.text, this.tone = ChipTone.neutral, this.icon});

  final String text;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    final (bg, fg) = switch (tone) {
      ChipTone.accent => (p.accentSoft, p.accent),
      ChipTone.positive => (p.positiveSoft, p.positive),
      ChipTone.warning => (p.warningSoft, p.warning),
      ChipTone.neutral => (p.surfaceMuted, p.textMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? PhosphorIconsRegular.info, size: 15, color: fg),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(fontSize: 12.5, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Kirish" tab: promo code, check lines, the balance switch, what is
/// left to collect, how it is paid, and the submit button.
///
/// The money model mirrors the backend's plan-entry checkout: everything
/// flows through the balance. Collected cash/card is credited to the
/// balance first, then products are debited from it; the Standard tariff
/// bills per exit, while VIP / 1 soat are debited from the balance at
/// issuance.
class _CheckoutSection extends StatelessWidget {
  const _CheckoutSection({
    required this.products,
    required this.cart,
    required this.cartTotal,
    required this.cartLines,
    required this.discounts,
    required this.selectedDiscount,
    required this.cartDiscountUzs,
    required this.onDiscountChanged,
    required this.vipTotal,
    required this.promoDiscountUzs,
    required this.promoName,
    required this.checkDiscountUzs,
    required this.checkDiscountName,
    required this.planName,
    required this.planPrepaid,
    required this.companions,
    required this.companionsTotal,
    required this.neededTotal,
    required this.balance,
    required this.fromBalanceUzs,
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
    required this.alreadyNotes,
    required this.printParentQr,
    required this.onPrintParentQrChanged,
    required this.showPayAmount,
    required this.onShowPayAmount,
    required this.canSubmit,
    required this.isBusy,
    required this.onSubmit,
  });

  final List<Product> products;

  final Map<String, int> cart;
  final int cartTotal;

  /// The cart line by line ("Enaga ×2") — the check names what is sold
  /// instead of one "Mahsulotlar" sum.
  final List<({String name, int qty, int totalUzs})> cartLines;

  /// Active discount catalog — empty hides the picker entirely (best-effort
  /// fetch, same contract as `products`/`plans`).
  final List<Discount> discounts;

  /// The cashier's pick, scoped to THIS cart only — never applied to
  /// [vipTotal] or [companionsTotal].
  final Discount? selectedDiscount;

  /// PREVIEW ONLY (see `Discount.appliedDiscountUzs`) — how much of
  /// [cartTotal] the pick above takes off.
  final int cartDiscountUzs;
  final ValueChanged<Discount?> onDiscountChanged;

  /// VIP / 1 soat flat price × newly-covered children — debited from the
  /// balance the moment the stickers print. 0 for Standard. Children with a
  /// free-entry reason are already excluded.
  final int vipTotal;

  /// PREVIEW ONLY — what the promo code takes off the prepaid tariff
  /// ([vipTotal] is already net of it); 0 when no code applies.
  final int promoDiscountUzs;
  final String? promoName;

  /// PREVIEW ONLY — what the check discount takes off the prepaid tariff;
  /// 0 when none or Standard. [vipTotal] is already net of it.
  final int checkDiscountUzs;
  final String? checkDiscountName;

  /// The selected tariff's name for the "VIP × 2 bola" line — null until a
  /// tariff is picked. [planPrepaid] false (Standard) bills at exit.
  final String? planName;
  final bool planPrepaid;

  /// Paid HAMROH companion stickers and their subtotal — the qty is picked
  /// in step 3, the line shows here.
  final int companions;
  final int companionsTotal;
  final int neededTotal;
  final int balance;

  /// What the balance pays of [neededTotal] — 0 with the switch off.
  final int fromBalanceUzs;
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

  /// Selected children already covered by a live pass on the selected
  /// prepaid plan (or, for 1 soat, by a live VIP pass) — shown as "no second
  /// charge" notes and excluded from [vipTotal]. Split by the pass they
  /// hold so each note names the right tariff.
  final List<String> alreadyNotes;

  /// The free parent sticker rides along with the checkout print.
  final bool printParentQr;
  final ValueChanged<bool> onPrintParentQrChanged;

  /// Whether the "Boshqa summa olish" field is open.
  final bool showPayAmount;
  final VoidCallback onShowPayAmount;
  final bool canSubmit;
  final bool isBusy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final parts = this.parts(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [parts.body, const SizedBox(height: 10), parts.action],
    );
  }

  /// The check split in two so the money panel can scroll [body] while the
  /// big submit [action] stays pinned under it.
  ({Widget body, Widget action}) parts(
    BuildContext context, {
    bool amountOnAction = false,
  }) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final showPlanLine = planName != null && selectedChildCount > 0;
    final planGross = vipTotal + promoDiscountUzs + checkDiscountUzs;
    final hasLines =
        showPlanLine ||
        cartTotal > 0 ||
        companionsTotal > 0 ||
        cartDiscountUzs > 0 ||
        promoDiscountUzs > 0 ||
        checkDiscountUzs > 0;
    // Something is owed (or discounted away) — the check gets its totals.
    final hasTotals =
        neededTotal > 0 ||
        cartDiscountUzs > 0 ||
        promoDiscountUzs > 0 ||
        checkDiscountUzs > 0;
    final lineCount = [
      showPlanLine,
      cartTotal > 0,
      companionsTotal > 0,
      cartDiscountUzs > 0,
      promoDiscountUzs > 0,
      checkDiscountUzs > 0,
    ].where((shown) => shown).length;
    // "Jami" only when it adds something: several lines, or a balance
    // deduction between it and the amount to pay.
    final showTotal = lineCount > 1 || fromBalanceUzs > 0 || neededTotal == 0;
    final payDelta = payAmount - requiredPayment;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (products.isNotEmpty) ...[
          Text(l10n.products, style: p.bodyMuted.copyWith(fontSize: 12)),
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
          const SizedBox(height: 10),
        ],
        if (discounts.isNotEmpty && cart.isNotEmpty) ...[
          Row(
            children: [
              Text(l10n.discount, style: p.bodyMuted.copyWith(fontSize: 12)),
              const Spacer(),
              DiscountPicker(
                discounts: discounts,
                selectedDiscount: selectedDiscount,
                onChanged: onDiscountChanged,
              ),
            ],
          ),
          if (selectedDiscount != null && cartDiscountUzs > 0)
            DiscountSummaryRow(
              name: selectedDiscount!.name,
              amountUzs: cartDiscountUzs,
            ),
          const SizedBox(height: 10),
        ],
        if (neededTotal > 0 && balance > 0) ...[
          const SizedBox(height: 10),
          _BalanceSwitch(
            value: payFromBalance,
            onChanged: onPayFromBalanceChanged,
            balance: balance,
          ),
        ],
        // The check itself — read-only, top to bottom like a printed
        // receipt: lines, total, what the balance pays, what is left.
        if (hasLines) ...[
          const SizedBox(height: 12),
          _Receipt(
            children: [
              if (showPlanLine)
                _TotalRow(
                  label: l10n.accountPlanTimesKids(
                    planName!,
                    selectedChildCount,
                  ),
                  amount: planGross,
                  amountText: planPrepaid ? null : l10n.accountAtExit,
                ),
              if (cartLines.isNotEmpty)
                for (final line in cartLines)
                  _TotalRow(
                    label: '${line.name} ×${line.qty}',
                    amount: line.totalUzs,
                  )
              else if (cartTotal > 0)
                _TotalRow(label: l10n.products, amount: cartTotal),
              if (cartDiscountUzs > 0)
                _TotalRow(
                  label: '${l10n.discount} (${selectedDiscount!.name})',
                  amount: -cartDiscountUzs,
                  positive: true,
                ),
              if (promoDiscountUzs > 0)
                _TotalRow(
                  label: '${l10n.promoCode} ($promoName)',
                  amount: -promoDiscountUzs,
                  positive: true,
                ),
              if (checkDiscountUzs > 0)
                _TotalRow(
                  label: '${l10n.checkDiscount} ($checkDiscountName)',
                  amount: -checkDiscountUzs,
                  positive: true,
                ),
              if (companionsTotal > 0)
                _TotalRow(
                  label: 'HAMROH QR ×$companions',
                  amount: companionsTotal,
                ),
              if (hasTotals && showTotal) ...[
                const _ReceiptRule(),
                Row(
                  children: [
                    Text(l10n.total, style: p.body.copyWith(fontSize: 14)),
                    const Spacer(),
                    Text(
                      neededTotal == 0 ? l10n.free : formatUzs(neededTotal),
                      style: p.heading.copyWith(
                        fontSize: 15,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
              if (hasTotals) ...[
                if (fromBalanceUzs > 0) ...[
                  const SizedBox(height: 6),
                  _TotalRow(
                    label: l10n.accountFromBalanceLine,
                    amount: -fromBalanceUzs,
                    positive: true,
                  ),
                ],
                if (neededTotal > 0) ...[
                  const _ReceiptRule(strong: true),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        l10n.accountToPay,
                        style: p.heading.copyWith(fontSize: 15),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              formatUzs(requiredPayment),
                              key: const ValueKey('pay-due'),
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: requiredPayment == 0
                                    ? p.positive
                                    : p.text,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (requiredPayment == 0 && fromBalanceUzs > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${l10n.accountLeftOnBalance}: '
                        '${formatUzs(balance - fromBalanceUzs)}',
                        textAlign: TextAlign.end,
                        style: p.bodyMuted.copyWith(fontSize: 12),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ],
        // Standard only: nothing is due at the register — billing happens
        // at exit by played time.
        if (planName != null && !planPrepaid && neededTotal == 0) ...[
          const SizedBox(height: 10),
          _Note(
            text: l10n.noPaymentNow,
            tone: ChipTone.positive,
            icon: PhosphorIconsRegular.info,
          ),
        ],
        for (final note in alreadyNotes)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Note(text: note, icon: PhosphorIconsRegular.checkCircle),
          ),
        // How the customer pays what is left.
        if (requiredPayment > 0) ...[
          const SizedBox(height: 14),
          PaymentMethodPills(
            selected: payMethod,
            onChanged: onPayMethodChanged,
          ),
          if (payMethod == PaymentMethod.split) ...[
            const SizedBox(height: 10),
            SplitAmountFields(
              cashController: payCashController,
              cardController: payCardController,
              split: paySplit,
              totalUzs: payAmount,
              onChanged: onChanged,
              autoComplete: true,
            ),
          ],
          // Taking more than owed is rare (the rest stays on the balance) —
          // a quiet link, not a field on every sale.
          if (showPayAmount || payDelta != 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: payAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsInputFormatter()],
              style: p.body.copyWith(
                fontFamily: null,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              onChanged: (_) {
                onPayAmountEdited();
                onChanged();
              },
              decoration: InputDecoration(
                labelText: l10n.paymentAmount,
                suffixText: "so'm",
                errorText: payDelta < 0
                    ? l10n.paymentMinimumHint(formatUzs(requiredPayment))
                    : null,
                helperText: payDelta > 0
                    ? l10n.accountExcessToBalance(formatUzs(payDelta))
                    : null,
              ),
            ),
          ] else
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onShowPayAmount,
                icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 14),
                label: Text(
                  l10n.accountOtherAmount,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
        // Transparent Material keeps the row's ink plumbing happy inside
        // the card's DecoratedBox (asserts in widget tests otherwise).
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => onPrintParentQrChanged(!printParentQr),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: printParentQr,
                      onChanged: (v) => onPrintParentQrChanged(v ?? false),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Tooltip(
                      message: l10n.unlimitedFreeEntry,
                      child: Text(
                        l10n.printParentQr,
                        overflow: TextOverflow.ellipsis,
                        style: p.body.copyWith(fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
    final action = SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: canSubmit ? onSubmit : null,
        icon: isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.onAccent,
                ),
              )
            : Icon(
                neededTotal > 0
                    ? PhosphorIconsRegular.printer
                    : PhosphorIconsRegular.doorOpen,
                size: 20,
              ),
        // When the check scrolls away under the pinned button, the amount
        // to collect rides on the button itself.
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                neededTotal > 0
                    ? l10n.paymentAndPrint
                    : selectedChildCount > 0
                    ? l10n.enterCount(selectedChildCount)
                    : l10n.enter,
              ),
              if (amountOnAction && neededTotal > 0 && requiredPayment > 0)
                Text(' · ${formatUzs(requiredPayment)}'),
            ],
          ),
        ),
      ),
    );
    return (body: body, action: action);
  }
}

/// A printed-receipt look for the check: a quiet tinted slip.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: p.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// The receipt's dashed separator; [strong] is the solid rule above the
/// amount to pay.
class _ReceiptRule extends StatelessWidget {
  const _ReceiptRule({this.strong = false});

  final bool strong;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: strong
          ? Container(height: 1.5, color: p.borderStrong)
          : LayoutBuilder(
              builder: (context, constraints) {
                final dashes = (constraints.maxWidth / 8).floor();
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < dashes; i++)
                      Container(width: 4, height: 1, color: p.borderStrong),
                  ],
                );
              },
            ),
    );
  }
}

/// "Balansdan yechish" as a tappable row: switch and the current balance —
/// how much it pays is a line on the receipt below.
class _BalanceSwitch extends StatelessWidget {
  const _BalanceSwitch({
    required this.value,
    required this.onChanged,
    required this.balance,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(12);
    return Material(
      color: value ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: value ? p.accent : p.border, width: 1.5),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
          child: Row(
            children: [
              Switch(value: value, onChanged: onChanged),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.payFromBalance,
                      style: p.heading.copyWith(fontSize: 13.5),
                    ),
                    Text(
                      l10n.currentBalanceValue(formatUzs(balance)),
                      style: p.bodyMuted.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checkout's promo code (partner or blogger): the "Promokod" field
/// until a code is verified, then its chip — partner, tier, discount (plus a
/// "Blogger · ALI20" tag for a blogger code) — with the child it
/// goes to ("Qaysi bolaga") and ✕ to drop it. The code is only claimed when
/// the checkout runs.
class _PromoSection extends StatelessWidget {
  const _PromoSection({
    required this.promo,
    required this.isChecking,
    required this.errorText,
    required this.label,
    required this.selectedChildren,
    required this.passChildIds,
    required this.promoChildId,
    required this.onSubmit,
    required this.onChildPicked,
    required this.onClear,
  });

  final PromoCodeCheck? promo;
  final bool isChecking;
  final String? errorText;
  final String? label;

  /// Selected children in the card's order — the picker's choices.
  final List<Child> selectedChildren;

  /// Children holding a pass today — the code can't go to them.
  final Set<String> passChildIds;
  final String? promoChildId;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChildPicked;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    if (promo == null) {
      return PromoCodeField(
        busy: isChecking,
        errorText: errorText,
        onSubmit: onSubmit,
      );
    }
    final promoChild = selectedChildren
        .where((c) => c.id == promoChildId)
        .firstOrNull;
    final childStyle = p.body.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.positive.withValues(alpha: 0.35)),
        color: p.positiveSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                promo!.isBlogger
                    ? PhosphorIconsRegular.megaphone
                    : PhosphorIconsRegular.checkCircle,
                size: 18,
                color: p.positive,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A blogger code is typed, reusable and ownerless — name
                    // it so the cashier can read back what was entered.
                    if (promo!.isBlogger)
                      Text(
                        '${l10n.promoCodeBlogger} · ${promo!.code}',
                        style: p.bodyMuted.copyWith(fontSize: 11),
                      ),
                    Text(
                      label!,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.positive,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.promoCodeRemove,
                visualDensity: VisualDensity.compact,
                onPressed: onClear,
                icon: Icon(PhosphorIconsRegular.x, size: 16, color: p.danger),
              ),
            ],
          ),
          if (promoChild == null)
            Text(
              selectedChildren.isNotEmpty &&
                      selectedChildren.every((c) => passChildIds.contains(c.id))
                  ? l10n.promoCodeChildHasPass
                  : l10n.promoCodeNoChild,
              style: p.bodyMuted.copyWith(fontSize: 11.5),
            )
          else
            Row(
              children: [
                Text(
                  '${l10n.promoCodeForChild}: ',
                  style: p.bodyMuted.copyWith(fontSize: 12),
                ),
                if (selectedChildren.length == 1)
                  Flexible(
                    child: Text(
                      promoChild.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: childStyle,
                    ),
                  )
                else
                  Flexible(
                    child: PopupMenuButton<String>(
                      tooltip: l10n.promoCodeForChild,
                      color: p.surface,
                      onSelected: onChildPicked,
                      itemBuilder: (context) => [
                        for (final child in selectedChildren)
                          PopupMenuItem<String>(
                            value: child.id,
                            // A child with a pass today would only get the
                            // code refused (and returned) by the server.
                            enabled: !passChildIds.contains(child.id),
                            child: Row(
                              children: [
                                Icon(
                                  child.id == promoChildId
                                      ? PhosphorIconsRegular.checkCircle
                                      : PhosphorIconsRegular.circle,
                                  size: 16,
                                  color: child.id == promoChildId
                                      ? p.accent
                                      : p.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  child.fullName,
                                  style: p.body.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                      ],
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              promoChild.fullName,
                              overflow: TextOverflow.ellipsis,
                              style: childStyle,
                            ),
                          ),
                          Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 14,
                            color: p.text,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                errorText!,
                style: TextStyle(color: p.danger, fontSize: 11.5),
              ),
            ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    this.positive = false,
    this.amountText,
  });

  final String label;
  final int amount;

  /// Discount lines read green.
  final bool positive;

  /// Shown instead of [amount] — "chiqishda" for a tariff billed at exit.
  final String? amountText;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: p.bodyMuted.copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            amountText ?? formatUzs(amount),
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: positive ? p.positive : p.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
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
    final p = PosPalette.of(context);
    final selected = qty > 0;
    final fg = selected ? p.accent : p.text;
    return Material(
      color: selected ? p.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: selected ? null : onAdd,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? p.accent : p.border),
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
                    style: AppTextStyles.body.copyWith(fontSize: 13, color: fg),
                  ),
                  Text(
                    formatUzs(product.priceUzs),
                    style: AppTextStyles.body.copyWith(
                      fontSize: 11,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                _StepButton(icon: PhosphorIconsRegular.minus, onTap: onRemove),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$qty', style: p.heading),
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

  /// Null greys the button out (e.g. "−" at zero).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PosPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: p.borderStrong),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 15,
            color: onTap == null ? p.textFaint : p.accent,
          ),
        ),
      ),
    );
  }
}

/// The customer's currently-inside children with their live running cost —
/// the cashier's instant answer when a parent walks up because the exit QR
/// refused on a low balance. A table: child · tariff · entered · time · due.
class _PlayingCard extends StatelessWidget {
  const _PlayingCard({
    required this.rows,
    required this.balance,
    required this.onRefresh,
  });

  final List<PlayingChild> rows;
  final int balance;
  final VoidCallback onRefresh;

  static const _flex = [5, 4, 3, 3, 4];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final totalDue = rows.fold<int>(0, (sum, row) => sum + row.dueUzs);
    final short = totalDue - balance;
    final headStyle = AppTextStyles.kicker.copyWith(
      fontSize: 10.5,
      color: p.textFaint,
    );
    Widget cells(List<Widget> children) => Row(
      children: [
        for (var i = 0; i < children.length; i++)
          Expanded(flex: _flex[i], child: children[i]),
      ],
    );
    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StepHeader(
            icon: PhosphorIconsRegular.doorOpen,
            title: l10n.currentlyInside,
            subtitle: l10n.childCount(rows.length),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.totalBill}: ',
                  style: p.bodyMuted.copyWith(fontSize: 12.5),
                ),
                Text(
                  formatUzs(totalDue),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: short > 0 ? p.danger : p.text,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.refresh,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRefresh,
                  icon: const Icon(
                    PhosphorIconsRegular.arrowsClockwise,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          cells([
            Text(l10n.accountColChild.toUpperCase(), style: headStyle),
            Text(l10n.tariff.toUpperCase(), style: headStyle),
            Text(l10n.enteredAt.toUpperCase(), style: headStyle),
            Text(l10n.accountColTime.toUpperCase(), style: headStyle),
            Text(
              l10n.accountColSoFar.toUpperCase(),
              textAlign: TextAlign.end,
              style: headStyle,
            ),
          ]),
          const SizedBox(height: 6),
          for (final row in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: cells([
                Text(
                  row.childName,
                  overflow: TextOverflow.ellipsis,
                  style: p.heading.copyWith(fontSize: 14),
                ),
                Text(
                  row.planName,
                  overflow: TextOverflow.ellipsis,
                  style: p.body.copyWith(fontSize: 13),
                ),
                Text(
                  '${row.enteredAt.hour.toString().padLeft(2, '0')}:${row.enteredAt.minute.toString().padLeft(2, '0')}',
                  style: p.body.copyWith(fontSize: 13),
                ),
                Text(
                  l10n.minutesCount(row.minutes),
                  style: p.body.copyWith(fontSize: 13),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatUzs(row.dueUzs),
                      style: p.heading.copyWith(
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (row.discountName != null)
                      Text(
                        '${l10n.discount}: ${row.discountName}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          color: p.positive,
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          if (short > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _Note(
                text: l10n.exitBalanceInsufficient(formatUzs(short)),
                tone: ChipTone.warning,
                icon: PhosphorIconsRegular.warning,
              ),
            ),
        ],
      ),
    );
  }
}

/// The "To'ldirish" tab: amount (quick picks or typed), how it's paid, the
/// resulting balance, and the button.
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
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.currentBalanceValue(formatUzs(customer.balance)),
          style: p.bodyMuted.copyWith(fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsInputFormatter()],
          style: p.body.copyWith(
            fontFamily: null,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          onChanged: (_) => onAmountChanged(),
          decoration: InputDecoration(
            labelText: l10n.amount,
            suffixText: "so'm",
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final quick in _quickTopupAmounts) ...[
              if (quick != _quickTopupAmounts.first) const SizedBox(width: 6),
              Expanded(
                child: _AmountChip(
                  amount: quick,
                  selected: amount == quick,
                  onTap: () => amountController.text = groupDigits(quick),
                  onChanged: onAmountChanged,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Row(
            children: [
              Text(l10n.newBalance, style: p.bodyMuted),
              const Spacer(),
              Text(
                formatUzs(customer.balance + amount),
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: p.accentStrong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: canTopup ? onTopup : null,
            icon: isBusy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.onAccent,
                    ),
                  )
                : const Icon(PhosphorIconsRegular.wallet, size: 20),
            label: Text(l10n.topup),
          ),
        ),
      ],
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
    final p = PosPalette.of(context);
    final radius = BorderRadius.circular(10);
    return Material(
      color: selected ? p.accentSoft : p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? p.accent : p.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          onTap();
          onChanged();
        },
        borderRadius: radius,
        child: SizedBox(
          height: 42,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  formatUzs(amount).replaceAll(" so'm", ''),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? p.accent : p.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
