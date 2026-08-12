import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_sale_bloc.dart';
import 'receipt_dialog.dart';

class CartPanel extends StatefulWidget {
  const CartPanel({super.key});

  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
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
    return BlocConsumer<PosSaleBloc, PosSaleState>(
      listenWhen: (previous, current) =>
          previous.lastReceipt != current.lastReceipt &&
          current.lastReceipt != null,
      listener: (context, state) async {
        await showReceiptDialog(context, state.lastReceipt!);
        if (context.mounted) {
          context.read<PosSaleBloc>().add(const PosSaleReceiptAcknowledged());
          setState(() {
            _cashController.clear();
            _cardController.clear();
          });
        }
      },
      builder: (context, state) {
        final subtotal = state.subtotalUzs;
        final cash = int.tryParse(_cashController.text) ?? 0;
        final card = int.tryParse(_cardController.text) ?? 0;
        final canCheckout =
            !state.isCheckingOut &&
            state.cart.isNotEmpty &&
            cash + card == subtotal;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chek', style: AppTextStyles.h5),
                  if (state.cart.isNotEmpty)
                    TextButton(
                      onPressed: () => context.read<PosSaleBloc>().add(
                        const PosSaleCartCleared(),
                      ),
                      child: const Text('Tozalash'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: state.cartLines.isEmpty
                  ? Center(
                      child: Text(
                        'Chek bo\'sh',
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
                                        '${line.lineTotalUzs} so\'m',
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
                      Text('Jami', style: AppTextStyles.h6),
                      Text(
                        '$subtotal so\'m',
                        style: AppTextStyles.h5.copyWith(
                          color: NocturneColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _cashController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppTextStyles.body,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Naqd'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _cardController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: AppTextStyles.body,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Karta'),
                        ),
                      ),
                    ],
                  ),
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
                                cashUzs: cash,
                                cardUzs: card,
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
                      label: const Text('To\'lash'),
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
