import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme_mode.dart';
import '../../../../core/theme/pos_light_theme.dart';
import '../../../../core/theme/pos_palette.dart';
import '../widgets/account_ui.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../injector_container.dart';
import '../../../pos_sale/domain/discount.dart';
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

  /// Wide enough for "+998 90 123 45 67" in the big phone field at every
  /// breakpoint — the customer list on the right takes what is left.
  static const _keypadPanel = ResponsivePanel(
    compact: 270,
    standard: 340,
    wide: 380,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final bloc = sl<PosAccountBloc>()
          ..add(const PosAccountRecentCustomersRequested())
          ..add(const PosAccountPlansRequested())
          ..add(const PosAccountProductsRequested())
          ..add(const PosAccountConfigRequested())
          ..add(const PosAccountDiscountsRequested())
          ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry))
          ..add(const PosAccountDiscountsRequested(scope: DiscountScope.check));
        if (initialCustomer != null) {
          bloc.add(PosAccountCustomerSelected(initialCustomer!));
        }
        return bloc;
      },
      // Everything below — dialogs and menus included — resolves the till's
      // current palette (light or night).
      child: Theme(
        data: AppThemeMode.dark ? posDarkTheme : posLightTheme,
        child: ColoredBox(
          color: PosPalette.current.bg,
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
                            : 16,
                      ),
                      decoration: accountCardDecoration(PosPalette.current),
                      child: const SingleChildScrollView(child: PhoneKeypad()),
                    ),
                    SizedBox(
                      width: breakpointOfContext(context) == Breakpoint.compact
                          ? 12
                          : 16,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: accountCardDecoration(PosPalette.current),
                        child: const CustomerResultsList(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
