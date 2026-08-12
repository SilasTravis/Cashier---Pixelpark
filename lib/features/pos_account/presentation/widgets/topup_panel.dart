import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_account_bloc.dart';

const _quickAmounts = [10000, 20000, 50000, 100000];

class TopupPanel extends StatefulWidget {
  const TopupPanel({super.key});

  @override
  State<TopupPanel> createState() => _TopupPanelState();
}

class _TopupPanelState extends State<TopupPanel> {
  final _amountController = TextEditingController();
  final _cashController = TextEditingController();
  final _cardController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _cashController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    setState(() {
      _amountController.text = amount.toString();
      _cashController.text = amount.toString();
      _cardController.text = '0';
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PosAccountBloc, PosAccountState>(
      listenWhen: (previous, current) =>
          previous.selectedCustomer?.balance !=
          current.selectedCustomer?.balance,
      listener: (context, state) {
        setState(() {
          _amountController.clear();
          _cashController.clear();
          _cardController.clear();
        });
      },
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

        final amount = int.tryParse(_amountController.text) ?? 0;
        final cash = int.tryParse(_cashController.text) ?? 0;
        final card = int.tryParse(_cardController.text) ?? 0;
        final canTopup = !state.isBusy && amount > 0 && cash + card == amount;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Balansni to\'ldirish', style: AppTextStyles.h5),
              const SizedBox(height: 4),
              Text(
                'Joriy balans: ${customer.balance} so\'m',
                style: AppTextStyles.muted(
                  AppTextStyles.body,
                ).copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final quickAmount in _quickAmounts)
                    OutlinedButton(
                      onPressed: () => _setAmount(quickAmount),
                      child: Text('$quickAmount'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.body,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Summa (so\'m)'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: AppTextStyles.body,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Karta'),
                    ),
                  ),
                ],
              ),
              if (amount > 0) ...[
                const SizedBox(height: 6),
                Text(
                  'Yangi balans: ${customer.balance + amount} so\'m',
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 12),
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
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: canTopup
                      ? () => context.read<PosAccountBloc>().add(
                          PosAccountTopupRequested(
                            amountUzs: amount,
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
                      : const Icon(PhosphorIconsRegular.wallet, size: 16),
                  label: const Text('To\'ldirish'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
