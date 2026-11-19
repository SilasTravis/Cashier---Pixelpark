import 'cashier_model.dart';

class AuthTokensModel {
  const AuthTokensModel({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) =>
      AuthTokensModel(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        expiresIn: json['expiresIn'] as int,
      );
}

/// Older login responses omit the branch and require a separate /me call.
class LoginResponseModel {
  const LoginResponseModel({
    required this.cashier,
    required this.tokens,
    this.branch,
  });

  final CashierModel cashier;
  final AuthTokensModel tokens;
  final BranchModel? branch;

  factory LoginResponseModel.fromJson(Map<String, dynamic> json) =>
      LoginResponseModel(
        cashier: CashierModel.fromJson(json['cashier'] as Map<String, dynamic>),
        branch: json['branch'] is Map<String, dynamic>
            ? BranchModel.fromJson(json['branch'] as Map<String, dynamic>)
            : null,
        tokens: AuthTokensModel.fromJson(
          json['tokens'] as Map<String, dynamic>,
        ),
      );
}

/// `GET cashier/auth/me` response: the cashier plus its branch.
class CurrentSessionModel {
  const CurrentSessionModel({required this.cashier, required this.branch});

  final CashierModel cashier;
  final BranchModel branch;

  factory CurrentSessionModel.fromJson(Map<String, dynamic> json) =>
      CurrentSessionModel(
        cashier: CashierModel.fromJson(json['cashier'] as Map<String, dynamic>),
        branch: BranchModel.fromJson(json['branch'] as Map<String, dynamic>),
      );
}
