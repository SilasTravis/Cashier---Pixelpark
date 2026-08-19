import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../bloc/pos_sale_bloc.dart';
import 'receipt_dialog.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  PaymentMethod _method = PaymentMethod.cash;
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
    return BlocConsumer<PosSaleBloc, PosSaleState>(
      listenWhen: (previous, current) =>
          previous.lastReceipt != current.lastReceipt &&
          current.lastReceipt != null,
      listener: (context, state) async {
        await printSaleReceiptDirect(context, state.lastReceipt!);
        if (!context.mounted) return;
        await showReceiptDialog(context, state.lastReceipt!);
        if (context.mounted) {
          context.read<PosSaleBloc>().add(const PosSaleReceiptAcknowledged());
          setState(() {
            _method = PaymentMethod.cash;
            _cashController.clear();
            _cardController.clear();
          });
        }
      },
      builder: (context, state) {
        final subtotal = state.subtotalUzs;
        final split = PaymentSplit.compute(
          method: _method,
          totalUzs: subtotal,
          cashInput: _cashController.text,
          cardInput: _cardController.text,
        );
        final canCheckout =
            !state.isCheckingOut && state.cart.isNotEmpty && split.isValid;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.cartTitle, style: AppTextStyles.h5),
                  if (state.cart.isNotEmpty)
                    TextButton(
                      onPressed: () => _confirmClear(context),
                      child: Text(l10n.cartClear),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.cartLines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.cartEmpty,
                        style: AppTextStyles.muted(AppTextStyles.body),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final line in state.cartLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        line.product.name,
                                        style: AppTextStyles.body.copyWith(
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        formatUzs(line.lineTotalUzs),
                                        style: AppTextStyles.muted(
                                          AppTextStyles.body,
                                        ).copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                _QtyStepper(
                                  qty: line.qty,
                                  onChanged: (qty) =>
                                      context.read<PosSaleBloc>().add(
                                        PosSaleQtyChanged(
                                          productId: line.product.id,
                                          qty: qty,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.total, style: AppTextStyles.h6),
                      Text(
                        formatUzs(subtotal),
                        style: AppTextStyles.h5.copyWith(
                          color: NocturneColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PaymentMethodPills(
                    selected: _method,
                    onChanged: (m) => setState(() => _method = m),
                  ),
                  if (_method == PaymentMethod.split) ...[
                    const SizedBox(height: 8),
                    SplitAmountFields(
                      cashController: _cashController,
                      cardController: _cardController,
                      split: split,
                      totalUzs: subtotal,
                      onChanged: () => setState(() {}),
                    ),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      state.errorMessage!,
                      style: const TextStyle(
                        color: NocturneColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: canCheckout
                          ? () => context.read<PosSaleBloc>().add(
                              PosSaleCheckoutRequested(
                                cashUzs: split.cashUzs,
                                cardUzs: split.cardUzs,
                              ),
                            )
                          : null,
                      icon: state.isCheckingOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              PhosphorIconsRegular.checkCircle,
                              size: 18,
                            ),
                      label: Text(l10n.pay),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final l10n = AppLocalization.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cartClearTitle),
        content: Text(l10n.cartClearMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.cartClear),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PosSaleBloc>().add(const PosSaleCartCleared());
    }
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.qty, required this.onChanged});

  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: PhosphorIconsRegular.minus,
          onTap: () => onChanged(qty - 1),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(fontSize: 13),
          ),
        ),
        _StepperButton(
          icon: PhosphorIconsRegular.plus,
          onTap: () => onChanged(qty + 1),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: NocturneColors.bg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Icon(icon, size: 12, color: NocturneColors.neutral400),
        ),
      ),
    );
  }
}
