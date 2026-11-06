import '../../../generated/l10n.dart';

/// Cashier text for a birthday API refusal. Codes whose server message carries
/// amounts (`params`, which `ServerException` does not keep) show the server's
/// own Uzbek message; the rest have a fixed ARB text.
String birthdayErrorText(AppLocalization l10n, String? code, String? message) {
  final fixed = switch (code) {
    'BIRTHDAY_PLAN_NOT_AVAILABLE' => l10n.birthdayErrPlanNotAvailable,
    'BIRTHDAY_SIZE_NOT_FOUND' => l10n.birthdayErrSizeNotFound,
    'BIRTHDAY_PAYMENT_EMPTY' => l10n.birthdayErrPaymentEmpty,
    'BIRTHDAY_PARTY_NOT_FOUND' => l10n.birthdayErrPartyNotFound,
    'BIRTHDAY_PARTY_NOT_BOOKED' => l10n.birthdayErrNotBooked,
    'BIRTHDAY_COMPLETE_TOO_EARLY' => l10n.birthdayErrCompleteTooEarly,
    'BIRTHDAY_REQUEST_CONFLICT' => l10n.bdRequestConflict,
    _ => null,
  };
  return fixed ?? message ?? l10n.birthdayErrGeneric;
}
