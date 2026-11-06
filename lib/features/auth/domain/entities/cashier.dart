import 'package:equatable/equatable.dart';

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.slug,
    required this.name,
    this.hasTurnstile = true,
  });

  final String id;
  final String slug;
  final String name;

  /// The dashboard's per-branch "Turniket bor" switch. False: the till
  /// prints no entry QR (stickers/tickets), only the payment receipt.
  final bool hasTurnstile;

  @override
  List<Object?> get props => [id, slug, name, hasTurnstile];
}

class Cashier extends Equatable {
  const Cashier({
    required this.id,
    required this.fullName,
    required this.username,
    required this.branchId,
    required this.active,
  });

  final String id;
  final String fullName;
  final String username;
  final String branchId;
  final bool active;

  @override
  List<Object?> get props => [id, fullName, username, branchId, active];
}

/// The signed-in cashier together with its branch — what the app shell
/// header and every POS action need.
class AuthSession extends Equatable {
  const AuthSession({required this.cashier, required this.branch});

  final Cashier cashier;
  final Branch branch;

  @override
  List<Object?> get props => [cashier, branch];
}
