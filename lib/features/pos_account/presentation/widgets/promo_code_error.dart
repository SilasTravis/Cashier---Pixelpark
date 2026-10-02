import '../../../../core/utils/currency.dart';
import '../../../../generated/l10n.dart';
import '../../../pos_sale/domain/discount.dart';
import '../../domain/promo_code_check.dart';
import '../bloc/pos_account_bloc.dart';

/// "Fonus · Premium · −30%" — the chip text for a verified promo code (on
/// the promo child's row, in the checkout's promo section, and in the
/// search screen's held-blogger-code hint).
String promoCodeLabel(PromoCodeCheck promo) {
  final discount = promo.discount;
  final value = discount.kind == DiscountKind.percent
      ? '${discount.value}%'
      : formatUzs(discount.value);
  return '${promo.partnerName} · ${promo.tierName} · −$value';
}

/// The text under the "Promokod" field for the bloc's last promo failure —
/// the terminal's own checks are localized here, server refusals already
/// arrive as the backend's localized message.
String? promoCodeErrorText(AppLocalization l10n, PosAccountState state) {
  return switch (state.promoErrorCode) {
    'PROMO_CODE_INVALID_FORMAT' => l10n.promoCodeInvalid,
    'PROMO_CODE_OWNER_NOT_FOUND' => l10n.promoCodeOwnerNotFound,
    'PROMO_CODE_WRONG_CUSTOMER' => l10n.promoCodeWrongCustomer,
    'PROMO_CODE_NOT_STARTED' => l10n.promoCodeNotStarted,
    'PROMO_CODE_LIMIT_REACHED' => l10n.promoCodeLimitReached,
    'PROMO_CODE_ALREADY_USED_BY_CUSTOMER' =>
      l10n.promoCodeAlreadyUsedByCustomer,
    'PROMO_CODE_RELEASED' => l10n.promoCodeReleased(
      state.promoErrorMessage ?? '',
    ),
    _ => state.promoErrorMessage,
  };
}
