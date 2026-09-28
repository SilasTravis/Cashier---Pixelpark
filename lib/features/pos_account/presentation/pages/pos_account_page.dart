import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/nocturne_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/promo_code_field.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../pos_sale/domain/discount.dart';
import '../bloc/pos_account_bloc.dart';
import '../widgets/customer_detail_panel.dart';
import '../widgets/customer_results_list.dart';
import '../widgets/phone_keypad.dart';
import '../widgets/promo_code_error.dart';
import '../../domain/customer.dart';
import '../../domain/promo_code_check.dart';

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
          ..add(const PosAccountConfigRequested())
          ..add(const PosAccountDiscountsRequested())
          ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry));
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
                  // Scrolls only if a short window can't fit the promo
                  // field's error line on top of the keypad.
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Scanning a partner code here opens its owner's
                        // account straight away; a blogger code has no
                        // owner, so it is held (hint below) until the
                        // cashier opens or creates a customer — see
                        // PosAccountBloc.
                        BlocBuilder<PosAccountBloc, PosAccountState>(
                          buildWhen: (previous, current) =>
                              previous.isCheckingPromo !=
                                  current.isCheckingPromo ||
                              previous.promoErrorCode !=
                                  current.promoErrorCode ||
                              previous.promoErrorMessage !=
                                  current.promoErrorMessage ||
                              previous.promo != current.promo,
                          builder: (context, state) {
                            final held = state.promo;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PromoCodeField(
                                  autofocus: true,
                                  busy: state.isCheckingPromo,
                                  errorText: promoCodeErrorText(
                                    AppLocalization.of(context),
                                    state,
                                  ),
                                  onSubmit: (raw) => context
                                      .read<PosAccountBloc>()
                                      .add(PosAccountPromoCodeSubmitted(raw)),
                                ),
                                if (held != null && held.isBlogger) ...[
                                  const SizedBox(height: 8),
                                  _HeldPromoHint(promo: held),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        const PhoneKeypad(),
                      ],
                    ),
                  ),
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

/// A blogger code accepted on the search screen: it has no owner, so it
/// waits for the cashier to open or create the customer it is for, then
/// rides into that account. ✕ drops it.
class _HeldPromoHint extends StatelessWidget {
  const _HeldPromoHint({required this.promo});

  final PromoCodeCheck promo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: NocturneColors.accent),
        color: NocturneColors.accent.withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.megaphone,
            size: 16,
            color: NocturneColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.promoCodeBloggerPending(promo.code),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                    color: NocturneColors.accent,
                  ),
                ),
                Text(
                  promoCodeLabel(promo),
                  style: AppTextStyles.muted(
                    AppTextStyles.body,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.promoCodeRemove,
            visualDensity: VisualDensity.compact,
            onPressed: () => context.read<PosAccountBloc>().add(
              const PosAccountPromoCodeCleared(),
            ),
            icon: const Icon(
              PhosphorIconsRegular.x,
              size: 16,
              color: NocturneColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
