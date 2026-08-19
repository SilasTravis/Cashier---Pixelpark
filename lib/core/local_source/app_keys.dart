/// Hive box keys — one flat box, matching pexel_app's `LocalSource` pattern.
abstract final class AppKeys {
  static const String accessToken = 'accessToken';
  static const String refreshToken = 'refreshToken';
  static const String tokenType = 'tokenType';
  static const String expiresIn = 'expiresIn';

  static const String cashierId = 'cashierId';
  static const String cashierFullName = 'cashierFullName';
  static const String cashierUsername = 'cashierUsername';
  static const String branchId = 'branchId';
  static const String branchName = 'branchName';

  static const String apiBaseUrl = 'apiBaseUrl';
  static const String languageCode = 'languageCode';
  static const String qrPrinterName = 'qrPrinterName';
  static const String receiptPrinterName = 'receiptPrinterName';
}
