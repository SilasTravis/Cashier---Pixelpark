import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../products/domain/product.dart';
import '../../domain/customer.dart';
import '../bloc/pos_account_bloc.dart';
import 'add_child_dialog.dart';
import 'gate_pass_slip_dialog.dart';

class CustomerDetailPanel extends StatefulWidget {
  const CustomerDetailPanel({super.key});

  @override
  State<CustomerDetailPanel> createState() => _CustomerDetailPanelState();
}

class _CustomerDetailPanelState extends State<CustomerDetailPanel> {
  final Set<String> _selectedChildIds = {};
  Product? _selectedProduct;
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _resetSelectionFor(Customer? customer) {
    _selectedChildIds.clear();
    _selectedProduct = null;
    _cashController.clear();
    _cardController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.selectedCustomer?.id != current.selectedCustomer?.id,
          listener: (context, state) =>
              setState(() => _resetSelectionFor(state.selectedCustomer)),
        ),
        BlocListener<PosAccountBloc, PosAccountState>(
          listenWhen: (previous, current) =>
              previous.lastIssuedPasses != current.lastIssuedPasses &&
              current.lastIssuedPasses != null,
          listener: (context, state) async {
            final issued = state.lastIssuedPasses!;
            final childNames = {
              for (final child
                  in state.selectedCustomer?.children ?? const <Child>[])
                child.id: child.fullName,
            };
            await showGatePassSlipDialog(context, issued, childNames);
            if (context.mounted) {
              context.read<PosAccountBloc>().add(
                const PosAccountIssuedPassesAcknowledged(),
              );
              setState(() => _resetSelectionFor(state.selectedCustomer));
            }
          },
        ),
      ],
      child: BlocBuilder<PosAccountBloc, PosAccountState>(
        builder: (context, state) {
          final customer = state.selectedCustomer;
          if (customer == null) {
            return Center(
              child: Text(
                'Mijozni tanlang',
                style: AppTextStyles.muted(AppTextStyles.body),
              ),
            );
          }

          final cash = int.tryParse(_cashController.text) ?? 0;
          final card = int.tryParse(_cardController.text) ?? 0;
          final total = _selectedProduct == null
              ? 0
              : _selectedProduct!.priceUzs * _selectedChildIds.length;
          final canIssue =
              !state.isBusy &&
              _selectedProduct != null &&
              _selectedChildIds.isNotEmpty &&
              cash + card == total;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.fullName.isEmpty
                      ? customer.phoneNumber
                      : customer.fullName,
                  style: AppTextStyles.h4,
                ),
                const SizedBox(height: 2),
                Text(
                  customer.phoneNumber,
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 12),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Farzandlar', style: AppTextStyles.h6),
                    TextButton.icon(
                      onPressed: () => showAddChildDialog(context),
                      icon: const Icon(PhosphorIconsRegular.plus, size: 14),
                      label: const Text('Qo\'shish'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (customer.children.isEmpty)
                  Text(
                    'Hali farzand qo\'shilmagan',
                    style: AppTextStyles.muted(
                      AppTextStyles.body,
                    ).copyWith(fontSize: 12),
                  )
                else
                  for (final child in customer.children)
                    CheckboxListTile(
                      value: _selectedChildIds.contains(child.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selectedChildIds.add(child.id);
                        } else {
                          _selectedChildIds.remove(child.id);
                        }
                      }),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      activeColor: NocturneColors.accent,
                      title: Text(
                        child.fullName,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                    ),
                const SizedBox(height: 20),
                Text('QR chop etish', style: AppTextStyles.h6),
                const SizedBox(height: 8),
                DropdownButtonFormField<Product>(
                  initialValue: _selectedProduct,
                  isExpanded: true,
                  dropdownColor: NocturneColors.surface,
                  decoration: const InputDecoration(labelText: 'Tarif'),
                  items: [
                    for (final product in state.products)
                      DropdownMenuItem(
                        value: product,
                        child: Text(
                          '${product.name} — ${product.priceUzs} so\'m',
                        ),
                      ),
                  ],
                  onChanged: (product) =>
                      setState(() => _selectedProduct = product),
                ),
                const SizedBox(height: 10),
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
                const SizedBox(height: 6),
                Text(
                  'Jami: $total so\'m',
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 12),
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
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: canIssue
                        ? () => context.read<PosAccountBloc>().add(
                            PosAccountPassesRequested(
                              productId: _selectedProduct!.id,
                              childIds: _selectedChildIds.toList(),
                              cashUzs: cash,
                              cardUzs: card,
                            ),
                          )
                        : null,
                    icon: state.isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(PhosphorIconsRegular.qrCode, size: 16),
                    label: const Text('QR chop etish'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
