import '../../../../generated/l10n.dart';
import '../bloc/pos_account_bloc.dart';

/// The text under the "Promokod" field for the bloc's last promo failure —
/// the terminal's own checks are localized here, server refusals already
/// arrive as the backend's localized message.
String? promoCodeErrorText(AppLocalization l10n, PosAccountState state) {
  return switch (state.promoErrorCode) {
    'PROMO_CODE_INVALID_FORMAT' => l10n.promoCodeInvalid,
    'PROMO_CODE_OWNER_NOT_FOUND' => l10n.promoCodeOwnerNotFound,
    'PROMO_CODE_WRONG_CUSTOMER' => l10n.promoCodeWrongCustomer,
    'PROMO_CODE_RELEASED' => l10n.promoCodeReleased(
      state.promoErrorMessage ?? '',
    ),
    _ => state.promoErrorMessage,
  };
}
