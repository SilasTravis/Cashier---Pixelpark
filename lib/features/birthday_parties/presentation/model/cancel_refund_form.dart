/// Validation of the "Qaytarish" part of the cancel dialog.
///
/// Returns an error key (one of the constants below) or null when the refund
/// can be sent. Keeping the money (`refund: false`) always passes.
class CancelRefundForm {
  const CancelRefundForm._();

  static const cashTooLarge = 'cashTooLarge';
  static const totalTooLarge = 'totalTooLarge';
  static const empty = 'empty';

  static String? validate({
    required int netUzs,
    required int maxCashRefundUzs,
    required bool refund,
    required int balanceUzs,
    required int cashUzs,
  }) {
    if (!refund) return null;
    if (cashUzs > maxCashRefundUzs) return cashTooLarge;
    if (balanceUzs + cashUzs > netUzs) return totalTooLarge;
    if (balanceUzs + cashUzs <= 0) return empty;
    return null;
  }
}
