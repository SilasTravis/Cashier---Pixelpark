import 'package:hive_ce/hive.dart';

import 'app_keys.dart';

/// Session + device-config persistence — tokens, the signed-in cashier, and
/// its branch. Cleared wholesale on logout.
class LocalSource {
  LocalSource(this.box);

  final Box<dynamic> box;

  Future<void> clearSession() async {
    await box.deleteAll([
      AppKeys.accessToken,
      AppKeys.refreshToken,
      AppKeys.tokenType,
      AppKeys.expiresIn,
      AppKeys.cashierId,
      AppKeys.cashierFullName,
      AppKeys.cashierUsername,
      AppKeys.branchId,
      AppKeys.branchName,
    ]);
  }

  void setAccessToken(String? value) {
    if (value == null) return;
    box.put(AppKeys.accessToken, value);
  }

  String? getAccessToken() => box.get(AppKeys.accessToken) as String?;

  void setRefreshToken(String? value) {
    if (value == null) return;
    box.put(AppKeys.refreshToken, value);
  }

  String? getRefreshToken() => box.get(AppKeys.refreshToken) as String?;

  void setCashier({
    required String id,
    required String fullName,
    required String username,
    required String branchId,
    required String branchName,
  }) {
    box.putAll({
      AppKeys.cashierId: id,
      AppKeys.cashierFullName: fullName,
      AppKeys.cashierUsername: username,
      AppKeys.branchId: branchId,
      AppKeys.branchName: branchName,
    });
  }

  String? getCashierId() => box.get(AppKeys.cashierId) as String?;
  String? getCashierFullName() => box.get(AppKeys.cashierFullName) as String?;
  String? getCashierUsername() => box.get(AppKeys.cashierUsername) as String?;
  String? getBranchId() => box.get(AppKeys.branchId) as String?;
  String? getBranchName() => box.get(AppKeys.branchName) as String?;

  Future<void> setApiBaseUrl(String value) async {
    await box.put(AppKeys.apiBaseUrl, value);
  }

  String? getApiBaseUrl() => box.get(AppKeys.apiBaseUrl) as String?;

  Future<void> setLanguageCode(String value) async {
    await box.put(AppKeys.languageCode, value);
  }

  String getLanguageCode() =>
      box.get(AppKeys.languageCode, defaultValue: 'uz') as String;

  Future<void> setQrPrinterName(String? value) async {
    if (value == null) return box.delete(AppKeys.qrPrinterName);
    await box.put(AppKeys.qrPrinterName, value);
  }

  String? getQrPrinterName() => box.get(AppKeys.qrPrinterName) as String?;

  Future<void> setReceiptPrinterName(String? value) async {
    if (value == null) return box.delete(AppKeys.receiptPrinterName);
    await box.put(AppKeys.receiptPrinterName, value);
  }

  String? getReceiptPrinterName() =>
      box.get(AppKeys.receiptPrinterName) as String?;

  String? _customerSearchHistoryKey() {
    final cashierId = getCashierId();
    final branchId = getBranchId();
    if (cashierId == null || branchId == null) return null;
    return '${AppKeys.customerSearchHistory}:$cashierId:$branchId';
  }

  /// JSON-compatible customer snapshots, scoped to the signed-in cashier
  /// and branch. The feature owns their schema; LocalSource only persists
  /// the raw maps in the existing Hive box.
  List<Map<String, dynamic>> getCustomerSearchHistory() {
    final key = _customerSearchHistoryKey();
    if (key == null) return const [];
    final raw = box.get(key);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> setCustomerSearchHistory(
    List<Map<String, dynamic>> customers,
  ) async {
    final key = _customerSearchHistoryKey();
    if (key == null) return;
    await box.put(key, customers);
  }
}
