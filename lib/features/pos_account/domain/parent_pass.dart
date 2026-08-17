/// The customer's free parent day-sticker as returned by the backend —
/// both door lanes, no rules, dead at the park's 22:00 close.
class ParentPass {
  const ParentPass({
    required this.code,
    required this.expiresAt,
    required this.customerName,
  });

  final String code;
  final DateTime expiresAt;
  final String customerName;
}
