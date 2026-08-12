import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../bloc/pos_account_bloc.dart';
import 'new_customer_dialog.dart';

class CustomerResultsList extends StatelessWidget {
  const CustomerResultsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosAccountBloc, PosAccountState>(
      buildWhen: (previous, current) =>
          previous.results != current.results ||
          previous.isSearching != current.isSearching ||
          previous.selectedCustomer != current.selectedCustomer,
      builder: (context, state) {
        if (state.isSearching) {
          return const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (state.results.isEmpty) {
          if (state.phoneDigits.length < 7) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Mijoz topilmadi',
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => showNewCustomerDialog(context),
                  icon: const Icon(PhosphorIconsRegular.userPlus, size: 16),
                  label: const Text('Yangi mijoz qo\'shish'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final customer in state.results)
                _CustomerTile(
                  name: customer.fullName,
                  phone: customer.phoneNumber,
                  selected: state.selectedCustomer?.id == customer.id,
                  onTap: () => context.read<PosAccountBloc>().add(
                    PosAccountCustomerSelected(customer),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.name,
    required this.phone,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final String phone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? NocturneColors.accent.withValues(alpha: 0.12)
            : NocturneColors.bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.user,
                  size: 16,
                  color: selected
                      ? NocturneColors.accent
                      : NocturneColors.neutral500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name.isEmpty ? phone : name,
                        style: AppTextStyles.body.copyWith(fontSize: 13),
                      ),
                      Text(
                        phone,
                        style: AppTextStyles.muted(
                          AppTextStyles.body,
                        ).copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
