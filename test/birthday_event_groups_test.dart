import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/model/event_groups.dart';
import 'package:flutter_test/flutter_test.dart';

BirthdayParty _party(String id, String date, {String status = 'booked'}) =>
    BirthdayParty.fromJson({
      'id': id,
      'status': status,
      'paymentState': 'unpaid',
      'branchId': 'b1',
      'branchName': 'Megaplanet',
      'customer': {'id': 1, 'fullName': 'Ali', 'phoneNumber': '998901112233'},
      'plan': {
        'id': 'p',
        'name': 'VIP',
        'color': '#7C3AED',
        'includedItems': [],
      },
      'childCount': 10,
      'extraChildren': 0,
      'packagePriceUzs': 1,
      'extraChildUzs': 1,
      'listPriceUzs': 1,
      'agreedPriceUzs': 1,
      'discountUzs': 0,
      'paidUzs': 0,
      'refundedUzs': 0,
      'debtUzs': 1,
      'keptUzs': 0,
      'maxCashRefundUzs': 0,
      'partyDate': date,
      'soldBy': null,
      'createdAt': '2026-11-01T10:00:00.000Z',
      'completedAt': null,
      'cancelledAt': null,
      'cancelReason': null,
      'payments': [],
      'comments': [],
    });

void main() {
  test('tashkentToday rolls over at 19:00 UTC', () {
    expect(tashkentToday(DateTime.utc(2026, 11, 12, 19, 30)), '2026-11-13');
    expect(tashkentToday(DateTime.utc(2026, 11, 12, 18, 59)), '2026-11-12');
  });

  test('groups booked parties by Tashkent day, empty groups omitted', () {
    final groups = groupEvents([
      _party('late', '2026-11-17'),
      _party('week', '2026-11-12'),
      _party('tom', '2026-11-10'),
      _party('today', '2026-11-09'),
      _party('old', '2026-11-05'),
    ], '2026-11-09');
    expect(groups.map((g) => g.kind), [
      EventGroupKind.overdue,
      EventGroupKind.today,
      EventGroupKind.tomorrow,
      EventGroupKind.thisWeek,
      EventGroupKind.nextWeek,
    ]);
    expect(groups.last.parties.single.id, 'late');
  });

  test('later group starts after next Sunday; Sunday is still this week', () {
    final groups = groupEvents([
      _party('sun', '2026-11-15'),
      _party('far', '2026-11-30'),
    ], '2026-11-09');
    expect(groups.map((g) => g.kind), [
      EventGroupKind.thisWeek,
      EventGroupKind.later,
    ]);
  });

  test('non-booked segments are a single group, as given by the server', () {
    final groups = groupEvents([
      _party('a', '2026-11-05', status: 'completed'),
      _party('b', '2026-11-01', status: 'completed'),
    ], '2026-11-09');
    expect(groups.length, 1);
    expect(groups.single.kind, EventGroupKind.all);
    expect(groups.single.parties.map((p) => p.id), ['a', 'b']);
  });
}
