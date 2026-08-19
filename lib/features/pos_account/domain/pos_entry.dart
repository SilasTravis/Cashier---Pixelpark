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

/// One child whose live day pass is on ANOTHER plan than the cashier just
/// picked — the backend printed nothing and expects a confirmed retry with
/// `replacePlan` before it settles the old pass and reissues.
class PosEntryConflict extends Equatable {
  const PosEntryConflict({
    required this.childId,
    required this.currentPlanKey,
    required this.currentPlanLabel,
    required this.requestedPlanKey,
    required this.isInside,
    required this.accruedDueUzs,
    required this.switchable,
  });

  final String childId;
  final String? currentPlanKey;
  final String currentPlanLabel;
  final String requestedPlanKey;

  /// The old pass currently owns the child's open in-park cycle.
  final bool isInside;

  /// What settling that cycle costs the balance at switch time.
  final int accruedDueUzs;

  /// False for downgrades (VIP → Standart) — no switch is offered.
  final bool switchable;

  @override
  List<Object?> get props => [
    childId,
    currentPlanKey,
    currentPlanLabel,
    requestedPlanKey,
    isInside,
    accruedDueUzs,
    switchable,
  ];
}

/// One paid HAMROH companion sticker minted by a checkout — parent-QR door
/// semantics (both lanes, unlimited, free at the door, dead at 22:00).
class CompanionPass extends Equatable {
  const CompanionPass({required this.code, required this.expiresAt});

  final String code;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [code, expiresAt];
}

class PosEntryResult extends Equatable {
  const PosEntryResult({
    required this.entries,
    required this.failures,
    this.conflicts = const [],
    this.companionPasses = const [],
    this.balance,
  });

  final List<PosEntry> entries;
  final List<PosEntryFailure> failures;

  /// Children needing the plan-switch confirmation modal — see
  /// [PosEntryConflict].
  final List<PosEntryConflict> conflicts;

  /// Paid HAMROH stickers bought with this checkout, print-ready.
  final List<CompanionPass> companionPasses;

  /// The customer's balance after a combined checkout (top-up + products) —
  /// null for the plain plan-entry path, which moves no money.
  final int? balance;

  @override
  List<Object?> get props => [
    entries,
    failures,
    conflicts,
    companionPasses,
    balance,
  ];
}
