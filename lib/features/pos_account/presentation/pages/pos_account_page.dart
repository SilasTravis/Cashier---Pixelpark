import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../bloc/pos_account_bloc.dart';
import '../widgets/customer_detail_panel.dart';
import '../widgets/customer_results_list.dart';
import '../widgets/phone_keypad.dart';
import '../../domain/customer.dart';

/// Search uses a keypad + results layout. Once a customer is selected the
/// search UI leaves the screen and the account workspace gets the full width;
/// the detail header's back button returns to search.
class PosAccountPage extends StatelessWidget {
  const PosAccountPage({super.key, this.initialCustomer});

  final Customer? initialCustomer;

  static const _keypadPanel = ResponsivePanel(
    compact: 220,
    standard: 286,
    wide: 320,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = sl<PosAccountBloc>()
          ..add(const PosAccountRecentCustomersRequested())
          ..add(const PosAccountPlansRequested())
          ..add(const PosAccountProductsRequested())
          ..add(const PosAccountConfigRequested());
        if (initialCustomer != null) {
          bloc.add(PosAccountCustomerSelected(initialCustomer!));
        }
        return bloc;
      },
      child: Padding(
        padding: breakpointOfContext(context) == Breakpoint.compact
            ? const EdgeInsets.fromLTRB(12, 12, 12, 14)
            : const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: BlocBuilder<PosAccountBloc, PosAccountState>(
          buildWhen: (previous, current) =>
              previous.selectedCustomer != current.selectedCustomer,
          builder: (context, state) {
            if (state.selectedCustomer != null) {
              return const CustomerDetailPanel(
                key: ValueKey('customer-detail'),
              );
            }
            return Row(
              key: const ValueKey('customer-search'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: _keypadPanel.of(context),
                  padding: EdgeInsets.all(
                    breakpointOfContext(context) == Breakpoint.compact
                        ? 10
                        : 14,
                  ),
                  decoration: BoxDecoration(
                    color: NocturneColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadow.sm,
                  ),
                  child: const PhoneKeypad(),
                ),
                SizedBox(
                  width: breakpointOfContext(context) == Breakpoint.compact
                      ? 12
                      : 16,
                ),
                const Expanded(child: CustomerResultsList()),
              ],
            );
          },
        ),
      ),
    );
  }
}
