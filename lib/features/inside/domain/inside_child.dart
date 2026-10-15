class InsideChild {
  const InsideChild({
    required this.visitId,
    required this.childName,
    required this.parentName,
    required this.parentPhone,
    required this.enteredAt,
    required this.elapsedMinutes,
    required this.accruedUzs,
    required this.planName,
    this.planKind,
    this.hourEndsAt,
    this.durationMinutes,
  });

  final String visitId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final DateTime enteredAt;
  final int elapsedMinutes;
  final int accruedUzs;
  final String? planName;

  /// `per_minute_tiers` / `flat_day` / `flat_hour`; null on older backends.
  final String? planKind;

  /// 1 soat only: when the child's hour ends (null = not started / other
  /// plan). Past it the child is over time — exit is still free, but the
  /// cashier should call the parent.
  final DateTime? hourEndsAt;

  /// 1 soat only: the plan's length in minutes.
  final int? durationMinutes;

  bool get isHourPlan => planKind == 'flat_hour';

  /// Whole minutes past the end of the hour (0 while time remains).
  int overtimeMinutes(DateTime now) {
    final end = hourEndsAt;
    if (!isHourPlan || end == null || !now.isAfter(end)) return 0;
    return now.difference(end).inMinutes.clamp(1, 1 << 20);
  }

  bool isOvertime(DateTime now) {
    final end = hourEndsAt;
    return isHourPlan && end != null && !now.isBefore(end);
  }

  /// Minutes left on the hour, rounded up (null for non-hour plans).
  int? remainingMinutes(DateTime now) {
    final end = hourEndsAt;
    if (!isHourPlan || end == null) return null;
    final seconds = end.difference(now).inSeconds;
    return seconds <= 0 ? 0 : (seconds + 59) ~/ 60;
  }

  /// Share of the hour used, 0..1 (null when unknown).
  double? hourProgress(DateTime now) {
    final end = hourEndsAt;
    final minutes = durationMinutes;
    if (!isHourPlan || end == null || minutes == null || minutes <= 0) {
      return null;
    }
    final start = end.subtract(Duration(minutes: minutes));
    final used = now.difference(start).inSeconds / (minutes * 60);
    return used.clamp(0.0, 1.0);
  }
}

/// Inside-list order: over-time 1 soat children first (longest over time
/// on top), then running 1 soat children (least time left first), then
/// everyone else in their original order.
List<InsideChild> sortInsideChildren(List<InsideChild> children, DateTime now) {
  int bucket(InsideChild c) => c.isOvertime(now)
      ? 0
      : c.isHourPlan
      ? 1
      : 2;
  final indexed = children.asMap().entries.toList();
  indexed.sort((a, b) {
    final ba = bucket(a.value), bb = bucket(b.value);
    if (ba != bb) return ba.compareTo(bb);
    final ea = a.value.hourEndsAt, eb = b.value.hourEndsAt;
    if (ba < 2 && ea != null && eb != null && ea != eb) {
      return ea.compareTo(eb);
    }
    return a.key.compareTo(b.key);
  });
  return [for (final e in indexed) e.value];
}
