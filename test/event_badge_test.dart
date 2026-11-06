import 'package:cashier_app/features/birthday_parties/presentation/model/event_badge.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/birthday_fixtures.dart';

void main() {
  test('a cancelled party is neutral, never Qarz 0 or To‘langan', () {
    final badge = eventBadge(
      fixtureParty(
        status: 'cancelled',
        paid: 800000,
        refunded: 500000,
        debt: 0,
        kept: 300000,
      ),
    );
    expect(badge.kind, EventBadgeKind.cancelled);
    expect(badge.stripe, EventStripe.neutral);
    expect(badge.keptUzs, 300000);
  });

  test('a cancelled party with nothing kept carries no kept amount', () {
    final badge = eventBadge(fixtureParty(status: 'cancelled', debt: 0));
    expect(badge.kind, EventBadgeKind.cancelled);
    expect(badge.keptUzs, 0);
  });

  test('paid / partial / unpaid keep their stripes', () {
    expect(
      eventBadge(fixtureParty(paid: 2240000, debt: 0)),
      const EventBadge(kind: EventBadgeKind.paid, stripe: EventStripe.positive),
    );
    expect(
      eventBadge(
        fixtureParty(
          paid: 100000,
          debt: 2140000,
          payments: [paymentJson(cash: 100000)],
        ),
      ),
      const EventBadge(kind: EventBadgeKind.debt, stripe: EventStripe.warning),
    );
    expect(
      eventBadge(fixtureParty()),
      const EventBadge(kind: EventBadgeKind.unpaid, stripe: EventStripe.faint),
    );
  });
}
