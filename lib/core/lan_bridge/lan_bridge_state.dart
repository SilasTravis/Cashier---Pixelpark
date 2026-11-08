/// Control-socket status of the LAN bridge on this terminal.
enum ControlStatus {
  /// No usable terminal token (never issued, forgotten, or revoked).
  disabled,

  /// Token present; dialling, waiting for a retry, or waiting to be online.
  connecting,

  /// Control socket open and `hello` sent.
  connected,
}

/// Immutable snapshot published by `LanBridgeControlClient`.
class LanBridgeState {
  const LanBridgeState({
    this.control = ControlStatus.disabled,
    this.activeSessionId,
    this.activeSince,
  });

  final ControlStatus control;

  /// Session whose relay agent is running (or being dialled); null when idle.
  final String? activeSessionId;
  final DateTime? activeSince;

  bool get hasActiveSession => activeSessionId != null;

  LanBridgeState copyWith({ControlStatus? control}) => LanBridgeState(
    control: control ?? this.control,
    activeSessionId: activeSessionId,
    activeSince: activeSince,
  );

  LanBridgeState withSession(String sessionId, DateTime since) =>
      LanBridgeState(
        control: control,
        activeSessionId: sessionId,
        activeSince: since,
      );

  LanBridgeState withoutSession() => LanBridgeState(control: control);

  @override
  bool operator ==(Object other) =>
      other is LanBridgeState &&
      other.control == control &&
      other.activeSessionId == activeSessionId &&
      other.activeSince == activeSince;

  @override
  int get hashCode => Object.hash(control, activeSessionId, activeSince);

  @override
  String toString() =>
      'LanBridgeState($control, session: $activeSessionId, since: $activeSince)';
}
