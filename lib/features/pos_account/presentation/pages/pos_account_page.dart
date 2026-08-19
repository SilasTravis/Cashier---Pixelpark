import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../bloc/pos_account_bloc.dart';
import '../widgets/customer_detail_panel.dart';
import '../widgets/customer_results_list.dart';
import '../widgets/phone_keypad.dart';

/// Two columns, matching the design: a fixed keypad card on the left, and a
/// center pane that swaps between the search results (hint / list / not
/// found) and the selected customer's detail — the search results are no
/// longer squeezed into the narrow keypad column.
class PosAccountPage extends StatelessWidget {
  const PosAccountPage({super.key});

  static const _keypadPanel = ResponsivePanel(
    compact: 220,
    standard: 286,
    wide: 320,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PosAccountBloc>()
        ..add(const PosAccountRecentCustomersRequested())
        ..add(const PosAccountPlansRequested())
        ..add(const PosAccountProductsRequested())
        ..add(const PosAccountConfigRequested()),
      child: Padding(
        padding: breakpointOfContext(context) == Breakpoint.compact
            ? const EdgeInsets.fromLTRB(12, 12, 12, 14)
            : const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _keypadPanel.of(context),
              padding: EdgeInsets.all(
                breakpointOfContext(context) == Breakpoint.compact ? 10 : 14,
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
            Expanded(
              child: BlocBuilder<PosAccountBloc, PosAccountState>(
                buildWhen: (previous, current) =>
                    previous.selectedCustomer != current.selectedCustomer,
                builder: (context, state) {
                  return state.selectedCustomer == null
                      ? const CustomerResultsList()
                      : const CustomerDetailPanel();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
