import '../../domain/birthday_party.dart';

enum EventBadgeKind { paid, debt, unpaid, cancelled }

enum EventStripe { positive, warning, faint, neutral }

/// What the list card shows for a party's money state: the left stripe, the
/// chip, and (cancelled with kept money) the amount the till held back.
class EventBadge {
  const EventBadge({
    required this.kind,
    required this.stripe,
    this.keptUzs = 0,
  });

  final EventBadgeKind kind;
  final EventStripe stripe;
  final int keptUzs;

  @override
  bool operator ==(Object other) =>
      other is EventBadge &&
      other.kind == kind &&
      other.stripe == stripe &&
      other.keptUzs == keptUzs;

  @override
  int get hashCode => Object.hash(kind, stripe, keptUzs);
}

/// A cancelled party is never "Qarz 0" / "To'langan": it gets a neutral
/// stripe, a "Bekor qilingan" chip and the kept amount.
EventBadge eventBadge(BirthdayParty party) {
  if (party.status == BirthdayPartyStatus.cancelled) {
    return EventBadge(
      kind: EventBadgeKind.cancelled,
      stripe: EventStripe.neutral,
      keptUzs: party.keptUzs,
    );
  }
  final net = party.paidUzs - party.refundedUzs;
  final hasPayment = party.payments.isNotEmpty;
  return switch (party.paymentState) {
    BirthdayPaymentState.paid => const EventBadge(
      kind: EventBadgeKind.paid,
      stripe: EventStripe.positive,
    ),
    BirthdayPaymentState.partial when hasPayment || net > 0 => const EventBadge(
      kind: EventBadgeKind.debt,
      stripe: EventStripe.warning,
    ),
    BirthdayPaymentState.partial => const EventBadge(
      kind: EventBadgeKind.unpaid,
      stripe: EventStripe.warning,
    ),
    BirthdayPaymentState.unpaid => const EventBadge(
      kind: EventBadgeKind.unpaid,
      stripe: EventStripe.faint,
    ),
  };
}
