import 'package:equatable/equatable.dart';

/// One issued Standard-plan entrance QR — the same kind of token the mobile
/// app itself generates, just triggered by the cashier for a walk-in.
class PosEntry extends Equatable {
  const PosEntry({
    required this.childId,
    required this.token,
    required this.expiresAt,
  });

  final String childId;
  final String token;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [childId, token, expiresAt];
}

/// One child that failed to enter — surfaced alongside any successes in the
/// same batch rather than failing the whole request (see
/// `PosController.issuePlanEntry` on the backend).
class PosEntryFailure extends Equatable {
  const PosEntryFailure({
    required this.childId,
    required this.code,
    required this.message,
  });

  final String childId;
  final String code;
  final String message;

  @override
  List<Object?> get props => [childId, code, message];
}

class PosEntryResult extends Equatable {
  const PosEntryResult({
    required this.entries,
    required this.failures,
    this.balance,
  });

  final List<PosEntry> entries;
  final List<PosEntryFailure> failures;

  /// The customer's balance after a combined checkout (top-up + products) —
  /// null for the plain plan-entry path, which moves no money.
  final int? balance;

  @override
  List<Object?> get props => [entries, failures, balance];
}
