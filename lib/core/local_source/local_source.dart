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
}
