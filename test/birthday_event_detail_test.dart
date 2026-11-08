import 'dart:async';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:cashier_app/core/utils/currency.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/event_detail_dialog.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/core/error/failure.dart';
import 'package:dartz/dartz.dart' show Either, Right;
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/birthday_fixtures.dart';

Map<String, dynamic> _json(
  String date, {
  int debt = 1200000,
  int paid = 1040000,
  List<Map<String, dynamic>> comments = const [],
  String status = 'booked',
}) => {
  'id': 'p1',
  'status': status,
  'paymentState': debt > 0 ? 'partial' : 'paid',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {
    'id': 42,
    'fullName': 'Jasur Toshmatov',
    'phoneNumber': '998901112233',
  },
  'plan': {
    'id': 'vip',
    'name': 'VIP',
    'color': '#7C3AED',
    'includedItems': ['3 hours whole park', 'Animators and show'],
  },
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 2000000,
  'extraChildUzs': 120000,
  'listPriceUzs': 2240000,
  'agreedPriceUzs': 2240000,
  'discountUzs': 0,
  'paidUzs': paid,
  'refundedUzs': 0,
  'debtUzs': debt,
  'keptUzs': 0,
  'maxCashRefundUzs': 400000,
  'partyDate': date,
  'soldBy': {'id': 's1', 'username': 'dilnoza'},
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments': [
    {
      'id': 'pay1',
      'kind': 'payment',
      'amountUzs': paid,
      'fromBalanceUzs': 0,
      'cashUzs': paid,
      'cardUzs': 0,
      'refundTo': null,
      'cashier': {'id': 'c1', 'username': 'dilnoza'},
      'createdAt': '2026-11-06T10:00:00.000Z',
    },
  ],
  'comments': comments,
};

BirthdayParty _party(String date, {int debt = 1200000}) =>
    BirthdayParty.fromJson(_json(date, debt: debt));

class _FakeRepo implements BirthdayPartiesRepository {
  _FakeRepo(this.after);
  final BirthdayParty after;
  final calls = <String, Map<String, Object?>>{};

  /// What `get` answers; the opened (list) copy until a test changes it.
  BirthdayParty? getAnswer;
  int gets = 0;
  final payRequestIds = <String>[];
  Object? payError;
  Object? cancelError;
  Object? extraError;

  /// When set, `get` throws it (an unreachable server or a refusal).
  Object? getError;
  final commentRequestIds = <String?>[];
  final expectedExtra = <int?>[];
  final extraRequestIds = <String?>[];

  @override
  Future<BirthdayParty> get(String id) async {
    gets++;
    if (getError != null) throw getError!;
    return getAnswer ?? after;
  }

  @override
  Future<BirthdayParty> addExtraChildren(
    String id,
    int count, {
    int? expectedExtraChildren,
    String? requestId,
  }) async {
    expectedExtra.add(expectedExtraChildren);
    extraRequestIds.add(requestId);
    calls['extra'] = {'count': count};
    if (extraError != null) throw extraError!;
    return after;
  }

  @override
  Future<BirthdayParty> pay(
    String id,
    BirthdayMoney money,
    String requestId,
  ) async {
    calls['pay'] = {'money': money, 'requestId': requestId};
    payRequestIds.add(requestId);
    if (payError != null) throw payError!;
    return after;
  }

  @override
  Future<BirthdayParty> cancel(
    String id, {
    required String reason,
    required int refundBalanceUzs,
    required int refundCashUzs,
    required String requestId,
  }) async {
    calls['cancel'] = {
      'reason': reason,
      'balance': refundBalanceUzs,
      'cash': refundCashUzs,
      'requestId': requestId,
    };
    if (cancelError != null) throw cancelError!;
    return after;
  }

  @override
  Future<BirthdayParty> addComment(
    String id,
    String text, {
    String? requestId,
  }) async {
    calls['comment'] = {'text': text};
    commentRequestIds.add(requestId);
    if (commentError != null) throw commentError!;
    return after;
  }

  Object? commentError;

  @override
  Future<BirthdayParty> complete(String id) async {
    calls['complete'] = {};
    if (completeGate != null) await completeGate!.future;
    if (failComplete) {
      throw ServerException(
        message: 'Hali erta',
        code: 'BIRTHDAY_COMPLETE_TOO_EARLY',
        statusCode: 400,
      );
    }
    return after;
  }

  bool failComplete = false;

  /// When set, `complete` waits for it (an action in flight).
  Completer<void>? completeGate;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRepo> _open(
  WidgetTester tester,
  BirthdayParty party, {
  BirthdayParty? after,
  void Function(BirthdayParty)? onChanged,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _FakeRepo(after ?? party);
  repo.getAnswer = party;
  sl.registerSingleton<BirthdayPartiesRepository>(repo);
  await tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('open'),
            onPressed: () =>
                showEventDetailDialog(context, party, onChanged: onChanged),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();
  return repo;
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<ButtonStyleButton>(find.byKey(ValueKey(key))).onPressed !=
    null;

void main() {
  tearDown(() => sl.reset());

  testWidgets('header, items, timeline and amber Qoldi', (tester) async {
    await _open(tester, _party('2999-01-01'));
    expect(find.text('Jasur Toshmatov'), findsOneWidget);
    expect(find.text('VIP · 10 + 2'), findsOneWidget);
    expect(find.text('3 hours whole park'), findsOneWidget);
    expect(find.textContaining('dilnoza'), findsWidgets);
    expect(find.text(formatUzs(1200000)), findsOneWidget);
    expect(find.byKey(const ValueKey('bd-left')), findsOneWidget);
  });

  testWidgets('Yakunlash is disabled before the party day', (tester) async {
    await _open(tester, _party('2999-01-01'));
    expect(_enabled(tester, 'bd-complete'), isFalse);
    expect(_enabled(tester, 'bd-add-payment'), isTrue);
  });

  testWidgets('Yakunlash with debt asks first, then completes', (tester) async {
    BirthdayParty? changed;
    final repo = await _open(
      tester,
      _party('2000-01-01'),
      after: BirthdayParty.fromJson(
        _json('2000-01-01', debt: 1200000, status: 'completed'),
      ),
      onChanged: (p) => changed = p,
    );
    await tester.tap(find.byKey(const ValueKey('bd-complete')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Qarz qoldi: ${groupDigits(1200000)} so‘m. Baribir yakunlansinmi?',
      ),
      findsOneWidget,
    );
    expect(repo.calls.containsKey('complete'), isFalse);
    await tester.tap(find.byKey(const ValueKey('bd-complete-confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls.containsKey('complete'), isTrue);
    expect(changed?.status, BirthdayPartyStatus.completed);
    expect(find.byKey(const ValueKey('bd-complete')), findsNothing);
  });

  testWidgets('a refused Yakunlash shows the message and stays open', (
    tester,
  ) async {
    final repo = await _open(tester, _party('2000-01-01', debt: 0));
    repo.failComplete = true;
    await tester.tap(find.byKey(const ValueKey('bd-complete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bd-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('bd-complete')), findsOneWidget);
  });

  testWidgets('add payment: prefilled with the debt, pays it in cash', (
    tester,
  ) async {
    final paid = BirthdayParty.fromJson(
      _json('2999-01-01', debt: 0, paid: 2240000),
    );
    final repo = await _open(tester, _party('2999-01-01'), after: paid);
    await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('bd-pay-amount')))
          .controller!
          .text,
      '1 200 000',
    );
    await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
    await tester.pumpAndSettle();
    final call = repo.calls['pay']!;
    final money = call['money']! as BirthdayMoney;
    expect(money.cashUzs, 1200000);
    expect(money.fromBalanceUzs, 0);
    expect(money.cardUzs, 0);
    expect((call['requestId']! as String).length, greaterThan(10));
    // The dialog now shows the paid party: no Qoldi, no + To'lov.
    expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    expect(find.byKey(const ValueKey('bd-add-payment')), findsNothing);
  });

  testWidgets('add payment above the debt cannot be submitted', (tester) async {
    await _open(tester, _party('2999-01-01'));
    await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bd-pay-amount')),
      '1300000',
    );
    await tester.pump();
    expect(_enabled(tester, 'bd-pay-submit'), isFalse);
    await tester.enterText(find.byKey(const ValueKey('bd-pay-amount')), '0');
    await tester.pump();
    expect(_enabled(tester, 'bd-pay-submit'), isFalse);
    await tester.enterText(
      find.byKey(const ValueKey('bd-pay-amount')),
      '500000',
    );
    await tester.pump();
    expect(_enabled(tester, 'bd-pay-submit'), isTrue);
  });

  testWidgets('Qaytarmaslik cancels without any refund', (tester) async {
    final repo = await _open(tester, _party('2999-01-01'));
    await tester.tap(find.byKey(const ValueKey('bd-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'bd-cancel-confirm'), isFalse);
    await tester.enterText(
      find.byKey(const ValueKey('bd-cancel-reason')),
      'Oila kelmaydi',
    );
    await tester.tap(find.byKey(const ValueKey('bd-cancel-norefund')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bd-cancel-confirm')));
    await tester.pumpAndSettle();
    final call = repo.calls['cancel']!;
    expect(call['balance'], 0);
    expect(call['cash'], 0);
    expect(call['reason'], 'Oila kelmaydi');
  });

  testWidgets('Qaytarish validates cash against what was collected', (
    tester,
  ) async {
    await _open(tester, _party('2999-01-01'));
    await tester.tap(find.byKey(const ValueKey('bd-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bekor qilish'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('bd-cancel-reason')),
      'Oila kelmaydi',
    );
    await tester.tap(find.byKey(const ValueKey('bd-cancel-refund')));
    await tester.pump();
    // Balance prefilled with the net paid: valid.
    expect(_enabled(tester, 'bd-cancel-confirm'), isTrue);
    await tester.enterText(
      find.byKey(const ValueKey('bd-cancel-cash')),
      '500000',
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('bd-cancel-form-error')), findsOneWidget);
    expect(_enabled(tester, 'bd-cancel-confirm'), isFalse);
  });

  testWidgets('adding a comment calls addComment and shows the text', (
    tester,
  ) async {
    final after = BirthdayParty.fromJson(
      _json(
        '2999-01-01',
        comments: [
          {
            'id': 'c1',
            'text': 'Tort olib keladi',
            'author': 'dilnoza',
            'createdAt': '2026-11-06T11:00:00.000Z',
          },
        ],
      ),
    );
    final repo = await _open(tester, _party('2999-01-01'), after: after);
    await tester.enterText(
      find.byKey(const ValueKey('bd-comment-field')),
      'Tort olib keladi',
    );
    await tester.tap(find.byKey(const ValueKey('bd-comment-send')));
    await tester.pumpAndSettle();
    expect(repo.calls['comment']!['text'], 'Tort olib keladi');
    expect(find.text('Tort olib keladi'), findsOneWidget);
  });

  group('lost responses', () {
    final before = fixtureParty(
      paid: 1040000,
      debt: 1200000,
      payments: [paymentJson(id: 'pay1', cash: 1040000)],
    );
    final landed = fixtureParty(
      paid: 2240000,
      debt: 0,
      payments: [
        paymentJson(id: 'pay1', cash: 1040000),
        paymentJson(id: 'pay2', cash: 1200000),
      ],
    );

    Future<void> openPay(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('pay timeout, refetch shows the payment: success, one call', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      repo.getAnswer = landed;
      await openPay(tester);
      expect(repo.payRequestIds, hasLength(1));
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('BIRTHDAY_REQUEST_CONFLICT takes the refetch path', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(
        message: 'c',
        code: 'BIRTHDAY_REQUEST_CONFLICT',
        statusCode: 409,
      );
      repo.getAnswer = landed;
      await openPay(tester);
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('pay timeout, payment not there: locked, retry same id', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      await openPay(tester);
      expect(find.byKey(const ValueKey('bd-pay-error')), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsOneWidget);
      expect(find.text('Qayta urinish'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bd-pay-amount')))
            .enabled,
        isFalse,
      );
      // Retry reuses the same requestId and now succeeds.
      repo.payError = null;
      await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
      await tester.pumpAndSettle();
      expect(repo.payRequestIds, hasLength(2));
      expect(repo.payRequestIds[0], repo.payRequestIds[1]);
    });

    testWidgets('closing the unclear sheet re-fetches the true debt', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      await openPay(tester);
      final getsBefore = repo.gets;
      // The payment lands server-side while the sheet is open.
      repo.getAnswer = landed;
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(repo.gets, greaterThan(getsBefore));
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('cancelling the pay sheet re-fetches the party', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
      await tester.pumpAndSettle();
      final getsBefore = repo.gets;
      repo.getAnswer = landed;
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(repo.gets, greaterThan(getsBefore));
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('cancel timeout, refetch shows it cancelled: success', (
      tester,
    ) async {
      final cancelled = fixtureParty(
        status: 'cancelled',
        paid: 1040000,
        refunded: 540000,
        debt: 0,
        kept: 500000,
        payments: [
          paymentJson(id: 'pay1', cash: 1040000),
          paymentJson(
            id: 'r1',
            kind: 'refund',
            balance: 540000,
            refundTo: 'balance',
          ),
        ],
      );
      BirthdayParty? changed;
      final repo = await _open(tester, before, onChanged: (p) => changed = p);
      repo.cancelError = ServerException(message: 'timeout');
      repo.getAnswer = cancelled;
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bd-cancel-reason')),
        'Oila kelmaydi',
      );
      await tester.tap(find.byKey(const ValueKey('bd-cancel-norefund')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(changed?.status, BirthdayPartyStatus.cancelled);
      expect(find.byKey(const ValueKey('bd-cancel-confirm')), findsNothing);
    });

    testWidgets('cancel timeout, not cancelled: locked with a retry', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.cancelError = ServerException(message: 'timeout');
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bd-cancel-reason')),
        'Oila kelmaydi',
      );
      await tester.tap(find.byKey(const ValueKey('bd-cancel-norefund')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bd-cancel-unclear-hint')),
        findsOneWidget,
      );
      expect(find.text('Qayta urinish'), findsOneWidget);
      final firstId = repo.calls['cancel']!['requestId'];
      repo.cancelError = null;
      await tester.tap(find.byKey(const ValueKey('bd-cancel-confirm')));
      await tester.pumpAndSettle();
      expect(repo.calls['cancel']!['requestId'], firstId);
    });
  });

  group('follow-ups', () {
    final before = fixtureParty(
      paid: 1040000,
      debt: 1200000,
      payments: [paymentJson(id: 'pay1', cash: 1040000, requestId: 'old-rq')],
    );

    Future<void> openPaySheet(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
      await tester.pumpAndSettle();
    }

    Future<void> submitPay(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('an identical split with another requestId is not this pay', (
      tester,
    ) async {
      // The lost payment never landed; a different row with the same split
      // (here: the list copy was stale and lacked it) must not count.
      final stale = fixtureParty(paid: 0, debt: 2240000);
      final other = fixtureParty(
        paid: 1200000,
        debt: 1040000,
        payments: [paymentJson(id: 'x1', cash: 2240000, requestId: 'other')],
      );
      final repo = await _open(tester, stale);
      repo.payError = ServerException(message: 'timeout');
      repo.getAnswer = other;
      await openPaySheet(tester);
      await submitPay(tester);
      // Not treated as landed: the sheet is still open and locked.
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsOneWidget);
    });

    testWidgets('a row under this requestId counts as landed', (tester) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      await openPaySheet(tester);
      await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
      await tester.pump();
      await tester.pumpAndSettle();
      final sent = repo.payRequestIds.single;
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsOneWidget);
      repo.getAnswer = fixtureParty(
        paid: 2240000,
        debt: 0,
        payments: [
          paymentJson(id: 'pay1', cash: 1040000, requestId: 'old-rq'),
          paymentJson(id: 'pay2', cash: 1200000, requestId: sent),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('pay sheet closing while offline stays locked', (tester) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      await openPaySheet(tester);
      await submitPay(tester);
      repo.getError = ServerException(message: 'timeout');
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-pay-offline-hint')), findsOneWidget);
      expect(find.text('Tarmoq yo‘q — qayta urinib ko‘ring'), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsOneWidget);
      // A confirmed "not found" releases the lock.
      repo.getError = ServerException(
        message: 'x',
        code: 'BIRTHDAY_PARTY_NOT_FOUND',
        statusCode: 404,
      );
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
    });

    testWidgets('cancel dialog closing while offline stays locked', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.cancelError = ServerException(message: 'timeout');
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bd-cancel-reason')),
        'Oila kelmaydi',
      );
      await tester.tap(find.byKey(const ValueKey('bd-cancel-norefund')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-cancel-confirm')));
      await tester.pumpAndSettle();
      repo.getError = ServerException(message: 'timeout');
      await tester.tap(find.text('Yopish'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('bd-cancel-offline-hint')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('bd-cancel-confirm')), findsOneWidget);
    });

    testWidgets('BIRTHDAY_BALANCE_INSUFFICIENT re-reads the balance', (
      tester,
    ) async {
      final account = _FakeAccountRepo(600000);
      sl.registerSingleton<PosAccountRepository>(account);
      final repo = await _open(tester, before);
      repo.payError = ServerException(
        message: 'x',
        code: 'BIRTHDAY_BALANCE_INSUFFICIENT',
        statusCode: 400,
      );
      await openPaySheet(tester);
      expect(account.lookups, 1);
      account.balance = 100000;
      await submitPay(tester);
      expect(account.lookups, 2);
      expect(find.byKey(const ValueKey('bd-pay-error')), findsOneWidget);
    });

    testWidgets('+ bola sends the count the cashier saw', (tester) async {
      final repo = await _open(tester, before);
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ bola'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bd-child-submit')));
      await tester.pumpAndSettle();
      expect(repo.expectedExtra, [2]);
      expect(repo.calls['extra']!['count'], 1);
    });

    testWidgets('+ bola 409 conflict re-fetches and shows the party', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.extraError = ServerException(
        message: 'c',
        code: 'BIRTHDAY_REQUEST_CONFLICT',
        statusCode: 409,
      );
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ bola'));
      await tester.pumpAndSettle();
      final getsBefore = repo.gets;
      repo.getAnswer = fixtureParty(
        paid: 2240000,
        debt: 0,
        payments: [paymentJson(id: 'pay1', cash: 2240000)],
      );
      await tester.tap(find.byKey(const ValueKey('bd-child-submit')));
      await tester.pumpAndSettle();
      expect(repo.gets, greaterThan(getsBefore));
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
      expect(find.byKey(const ValueKey('bd-error')), findsOneWidget);
    });

    Future<void> addOneChild(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('bd-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ bola'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('bd-child-submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('+ bola: one requestId per tap, reused by its retry', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.extraError = ServerException(message: 'timeout');
      await addOneChild(tester);
      // The cashier taps again after the timeout: the same tap, same id.
      await addOneChild(tester);
      expect(repo.extraRequestIds, hasLength(2));
      expect(repo.extraRequestIds[0], isNotNull);
      expect(repo.extraRequestIds[1], repo.extraRequestIds[0]);
      expect(repo.expectedExtra, [2, 2]);
      // It lands; the next "+ bola" is a new tap with a new id.
      repo.extraError = null;
      await addOneChild(tester);
      expect(repo.extraRequestIds[2], repo.extraRequestIds[0]);
      await addOneChild(tester);
      expect(repo.extraRequestIds[3], isNot(repo.extraRequestIds[0]));
    });

    testWidgets('+ bola 409: another till changed it, the new count shows', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.extraError = ServerException(
        message: 'c',
        code: 'BIRTHDAY_REQUEST_CONFLICT',
        statusCode: 409,
      );
      repo.getAnswer = fixtureParty(
        paid: 1040000,
        debt: 1440000,
        extraChildren: 4,
        payments: [paymentJson(id: 'pay1', cash: 1040000)],
      );
      await addOneChild(tester);
      expect(
        find.text(
          'Bolalar sonini boshqa kassa o‘zgartirgan. Ma\'lumot yangilandi — '
          'tekshirib, kerak bo‘lsa qayta qo‘shing.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Bu amal allaqachon bajarilgan — tadbir yangilandi'),
        findsNothing,
      );
      expect(find.text('VIP · 10 + 4'), findsOneWidget);
    });

    testWidgets('pay 500 INTERNAL_ERROR is unclear: refetch finds it', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(
        message: 'x',
        code: 'INTERNAL_ERROR',
        statusCode: 500,
      );
      await openPaySheet(tester);
      final sent = <String>[];
      repo.getAnswer = null;
      await tester.tap(find.byKey(const ValueKey('bd-pay-submit')));
      await tester.pumpAndSettle();
      sent.addAll(repo.payRequestIds);
      // Not landed: locked like a lost response, not a plain refusal.
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bd-pay-amount')))
            .enabled,
        isFalse,
      );
      // It had landed after all: closing finds it and prints its receipt.
      repo.getAnswer = fixtureParty(
        paid: 2240000,
        debt: 0,
        payments: [
          paymentJson(id: 'pay1', cash: 1040000, requestId: 'old-rq'),
          paymentJson(id: 'pay2', cash: 1200000, requestId: sent.single),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      expect(find.byKey(const ValueKey('bd-left')), findsNothing);
    });

    testWidgets('a clean refusal of the unclear retry unlocks the pay sheet', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.payError = ServerException(message: 'timeout');
      await openPaySheet(tester);
      await submitPay(tester);
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsOneWidget);
      repo.payError = ServerException(
        message: 'Ortiqcha',
        code: 'BIRTHDAY_OVERPAYMENT',
        statusCode: 400,
      );
      await submitPay(tester);
      expect(find.byKey(const ValueKey('bd-pay-unclear-hint')), findsNothing);
      expect(find.byKey(const ValueKey('bd-pay-error')), findsOneWidget);
      expect(find.text('Ortiqcha'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('bd-pay-amount')))
            .enabled,
        isTrue,
      );
      // Closing now is a plain close, no re-check.
      final getsBefore = repo.gets;
      await tester.tap(find.byKey(const ValueKey('bd-pay-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-pay-submit')), findsNothing);
      // Only the detail's own refresh after the sheet closed.
      expect(repo.gets, getsBefore + 1);
    });

    testWidgets('the detail cannot be dismissed while an action runs', (
      tester,
    ) async {
      final repo = await _open(tester, _party('2000-01-01', debt: 0));
      repo.completeGate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('bd-complete')));
      await tester.pump();
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('bd-detail-close')))
            .onPressed,
        isNull,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byKey(const ValueKey('bd-complete')), findsOneWidget);
      // The answer comes back and is handled (here: done, the detail closes).
      repo.completeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-complete')), findsNothing);
    });

    testWidgets('when idle the barrier still closes the detail', (
      tester,
    ) async {
      await _open(tester, before);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-add-payment')), findsNothing);
    });

    testWidgets('a parent without a name shows the phone number', (
      tester,
    ) async {
      await _open(
        tester,
        fixtureParty(
          fullName: '',
          paid: 1040000,
          debt: 1200000,
          payments: [paymentJson(id: 'pay1', cash: 1040000)],
        ),
      );
      expect(find.text('998901112233'), findsOneWidget);
      await openPaySheet(tester);
      expect(find.text('998901112233'), findsNWidgets(2));
    });

    testWidgets('the Yakunlash tooltip shows the date as dd.MM.yyyy', (
      tester,
    ) async {
      await _open(tester, _party('2999-01-01'));
      expect(
        tester
            .widget<Tooltip>(
              find.ancestor(
                of: find.byKey(const ValueKey('bd-complete')),
                matching: find.byType(Tooltip),
              ),
            )
            .message,
        'Yakunlash 01.01.2999 kuni mumkin',
      );
    });

    testWidgets('a comment retry reuses its requestId, a new text gets one', (
      tester,
    ) async {
      final repo = await _open(tester, before);
      repo.commentError = ServerException(message: 'timeout');
      Future<void> send(String text) async {
        await tester.enterText(
          find.byKey(const ValueKey('bd-comment-field')),
          text,
        );
        await tester.tap(find.byKey(const ValueKey('bd-comment-send')));
        await tester.pumpAndSettle();
      }

      await send('Tort');
      await send('Tort');
      expect(repo.commentRequestIds, hasLength(2));
      expect(repo.commentRequestIds[0], isNotNull);
      expect(repo.commentRequestIds[0], repo.commentRequestIds[1]);
      await send('Boshqa matn');
      expect(repo.commentRequestIds[2], isNot(repo.commentRequestIds[0]));
      // After a success the next comment starts a new id.
      repo.commentError = null;
      await send('Boshqa matn');
      await send('Yana');
      expect(repo.commentRequestIds.last, isNot(repo.commentRequestIds[3]));
    });
  });

  testWidgets('opening re-fetches the party and shows the fresh state', (
    tester,
  ) async {
    final listCopy = fixtureParty(
      paid: 1040000,
      debt: 1200000,
      payments: [paymentJson(id: 'pay1', cash: 1040000)],
    );
    final fresh = fixtureParty(
      paid: 2240000,
      debt: 0,
      payments: [paymentJson(id: 'pay1', cash: 2240000)],
    );
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _FakeRepo(fresh);
    sl.registerSingleton<BirthdayPartiesRepository>(repo);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const ValueKey('open'),
              onPressed: () => showEventDetailDialog(context, listCopy),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
    expect(repo.gets, 1);
    expect(find.byKey(const ValueKey('bd-left')), findsNothing);
  });

  testWidgets(
    'header date is dd.MM.yyyy; money block shows discount and kept',
    (tester) async {
      await _open(
        tester,
        fixtureParty(
          status: 'cancelled',
          agreed: 2200000,
          discount: 40000,
          paid: 800000,
          refunded: 500000,
          debt: 0,
          kept: 300000,
          partyDate: '2026-11-20',
          payments: [paymentJson(id: 'pay1', cash: 800000)],
        ),
      );
      expect(find.textContaining('20.11.2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-discount')), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-kept')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bd-kept')),
          matching: find.text(formatUzs(300000)),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failed balance lookup says Balans noma‘lum, switch disabled', (
    tester,
  ) async {
    await _open(tester, _party('2999-01-01'));
    await tester.tap(find.byKey(const ValueKey('bd-add-payment')));
    await tester.pumpAndSettle();
    expect(find.text('Balans noma‘lum'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}

class _FakeAccountRepo implements PosAccountRepository {
  _FakeAccountRepo(this.balance);
  int balance;
  int lookups = 0;

  @override
  Future<Either<Failure, List<Customer>>> searchCustomers(
    String query, {
    int page = 1,
  }) async {
    lookups++;
    return Right([
      Customer(
        id: 42,
        phoneNumber: '998901112233',
        firstName: 'Jasur',
        lastName: null,
        balance: balance,
        children: const [],
      ),
    ]);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
