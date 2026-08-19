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
  });

  final String visitId;
  final String childName;
  final String parentName;
  final String parentPhone;
  final DateTime enteredAt;
  final int elapsedMinutes;
  final int accruedUzs;
  final String? planName;
}
