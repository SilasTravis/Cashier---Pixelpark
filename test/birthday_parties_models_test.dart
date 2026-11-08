import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_plan.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> sampleParty() => {
  'id': 'p1',
  'status': 'booked',
  'paymentState': 'partial',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {
    'id': 42,
    'fullName': 'Ali Valiyev',
    'phoneNumber': '998901112233',
  },
  'plan': {
    'id': 'pl1',
    'name': 'VIP',
    'color': '#7C3AED',
    'includedItems': ['Tort', 'Animator'],
  },
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 3000000,
  'extraChildUzs': 150000,
  'listPriceUzs': 3300000,
  'agreedPriceUzs': 3000000,
  'discountUzs': 300000,
  'paidUzs': 1000000,
  'refundedUzs': 100000,
  'debtUzs': 2000000,
  'keptUzs': 0,
  'maxCashRefundUzs': 500000,
  'partyDate': '2026-11-20',
  'soldBy': {'id': 'c1', 'username': 'kassir1'},
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [
    {
      'id': 'pay1',
      'kind': 'payment',
      'amountUzs': 1000000,
      'fromBalanceUzs': 400000,
      'cashUzs': 500000,
      'cardUzs': 100000,
      'refundTo': null,
      'cashier': {'id': 'c1', 'username': 'kassir1'},
      'createdAt': '2026-11-06T10:00:00.000Z',
    },
    {
      'id': 'pay2',
      'kind': 'refund',
      'amountUzs': 100000,
      'fromBalanceUzs': 0,
      'cashUzs': 0,
      'cardUzs': 0,
      'refundTo': 'cash',
      'requestId': 'rq_cash',
      'cashier': null,
      'createdAt': '2026-11-07T10:00:00.000Z',
    },
  ],
  'comments': [
    {
      'id': 'cm1',
      'text': 'Tort shokoladli',
      'author': 'kassir1',
      'createdAt': '2026-11-06T11:00:00.000Z',
    },
  ],
};

void main() {
  test('BirthdayParty.fromJson maps every field', () {
    final p = BirthdayParty.fromJson(sampleParty());
    expect(p.id, 'p1');
    expect(p.status, BirthdayPartyStatus.booked);
    expect(p.paymentState, BirthdayPaymentState.partial);
    expect(p.branchId, 'b1');
    expect(p.branchName, 'Megaplanet');
    expect(p.customerId, 42);
    expect(p.customerName, 'Ali Valiyev');
    expect(p.customerPhone, '998901112233');
    expect(p.planId, 'pl1');
    expect(p.planName, 'VIP');
    expect(p.planColor, '#7C3AED');
    expect(p.includedItems, ['Tort', 'Animator']);
    expect(p.childCount, 10);
    expect(p.extraChildren, 2);
    expect(p.packagePriceUzs, 3000000);
    expect(p.extraChildUzs, 150000);
    expect(p.listPriceUzs, 3300000);
    expect(p.agreedPriceUzs, 3000000);
    expect(p.discountUzs, 300000);
    expect(p.paidUzs, 1000000);
    expect(p.refundedUzs, 100000);
    expect(p.debtUzs, 2000000);
    expect(p.keptUzs, 0);
    expect(p.maxCashRefundUzs, 500000);
    expect(p.partyDate, '2026-11-20');
    expect(p.soldByUsername, 'kassir1');
    expect(p.createdAt, DateTime.utc(2026, 11, 6, 10));
    expect(p.completedAt, isNull);
    expect(p.cancelledAt, isNull);
    expect(p.cancelReason, isNull);
    expect(p.payments, hasLength(2));
    expect(p.payments[0].kind, BirthdayPaymentKind.payment);
    expect(p.payments[0].fromBalanceUzs, 400000);
    expect(p.payments[0].cashUzs, 500000);
    expect(p.payments[0].cardUzs, 100000);
    expect(p.payments[0].refundTo, isNull);
    expect(p.payments[0].requestId, isNull);
    expect(p.payments[1].requestId, 'rq_cash');
    expect(p.payments[0].cashierUsername, 'kassir1');
    expect(p.payments[1].kind, BirthdayPaymentKind.refund);
    expect(p.payments[1].refundTo, 'cash');
    expect(p.payments[1].cashierUsername, isNull);
    expect(p.comments.single.text, 'Tort shokoladli');
    expect(p.comments.single.author, 'kassir1');
    expect(BirthdayParty.fromJson(sampleParty()), p);
  });

  test('cancelled party parses nullable fields', () {
    final json = sampleParty()
      ..['status'] = 'cancelled'
      ..['cancelledAt'] = '2026-11-08T00:00:00.000Z'
      ..['cancelReason'] = 'Oila bekor qildi'
      ..['soldBy'] = null;
    final p = BirthdayParty.fromJson(json);
    expect(p.status, BirthdayPartyStatus.cancelled);
    expect(p.cancelReason, 'Oila bekor qildi');
    expect(p.cancelledAt, isNotNull);
    expect(p.soldByUsername, isNull);
  });

  test('BirthdayPlan.fromJson maps sizes', () {
    final plan = BirthdayPlan.fromJson({
      'id': 'pl1',
      'name': 'VIP',
      'color': '#7C3AED',
      'active': true,
      'allBranches': false,
      'branchIds': ['b1'],
      'includedItems': ['Tort'],
      'sortOrder': 2,
      'sizes': [
        {'childCount': 10, 'priceUzs': 3000000, 'extraChildUzs': 150000},
      ],
    });
    expect(plan.sortOrder, 2);
    expect(plan.allBranches, isFalse);
    expect(plan.branchIds, ['b1']);
    expect(plan.sizes.single.priceUzs, 3000000);
    expect(plan.sizes.single.extraChildUzs, 150000);
    expect(plan.sizes.single.childCount, 10);
  });

  test('colorOf parses hex and falls back', () {
    const fb = Color(0xFF123456);
    expect(colorOf('#7C3AED', fb), const Color(0xFF7C3AED));
    expect(colorOf('oops', fb), fb);
    expect(colorOf('#12', fb), fb);
  });
}
