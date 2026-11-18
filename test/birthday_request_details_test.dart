import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/bloc/birthday_requests_cubit.dart';
import 'package:cashier_app/features/birthday_parties/presentation/model/party_time_slots.dart';
import 'package:cashier_app/features/birthday_parties/presentation/model/request_details.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/confirm_request_dialog.dart';
import 'package:cashier_app/features/birthday_parties/presentation/widgets/request_details_panel.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  String id = 'r1',
  String status = 'requested',
  String name = 'Dilnoza Karimova',
  String partyDate = '2026-11-22',
  String? partyTime,
  String branchId = 'b1',
  String planName = 'FUN',
  Object? childBirthDate = '2020-11-24',
  Map<String, dynamic>? child = const {'id': 'k1', 'name': 'Amira'},
  int discount = 0,
  int debt = 120000,
  List<Map<String, dynamic>>? payments,
  List<Map<String, dynamic>> comments = const [],
}) => {
  'id': id,
  'status': status,
  'paymentState': 'partial',
  'branchId': branchId,
  'branchName': 'Megaplanet',
  'customer': {'id': 42, 'fullName': name, 'phoneNumber': '998901234567'},
  'child': child,
  'childBirthDate': childBirthDate,
  'plan': {
    'id': 'fun',
    'name': planName,
    'color': '#0E9AA7',
    'includedItems': ['Mehmonlar uchun kirish', 'Tortni olib chiqish'],
  },
  'childCount': 10,
  'extraChildren': 2,
  'packagePriceUzs': 1500000,
  'extraChildUzs': 60000,
  'listPriceUzs': 1620000,
  'agreedPriceUzs': 1620000 - discount,
  'discountUzs': discount,
  'paidUzs': 1500000,
  'refundedUzs': 0,
  'debtUzs': debt,
  'keptUzs': 0,
  'maxCashRefundUzs': 0,
  'partyDate': partyDate,
  'partyTime': partyTime,
  'source': 'app',
  'soldBy': null,
  'createdAt': '2026-11-18T09:35:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments':
      payments ??
      [
        {
          'id': 'pay1',
          'kind': 'payment',
          'amountUzs': 1500000,
          'fromBalanceUzs': 500000,
          'cashUzs': 0,
          'cardUzs': 0,
          'onlineUzs': 1000000,
          'onlineProvider': 'card',
          'onlineReversedAt': null,
          'refundTo': null,
          'cashier': null,
          'createdAt': '2026-11-18T09:35:00.000Z',
        },
      ],
  'comments': comments,
};

BirthdayParty _party({
  String id = 'r1',
  String status = 'requested',
  String name = 'Dilnoza Karimova',
  String partyDate = '2026-11-22',
  String? partyTime,
  String branchId = 'b1',
  String planName = 'FUN',
  Object? childBirthDate = '2020-11-24',
  Map<String, dynamic>? child = const {'id': 'k1', 'name': 'Amira'},
  int discount = 0,
  List<Map<String, dynamic>>? payments,
  List<Map<String, dynamic>> comments = const [],
}) => BirthdayParty.fromJson(
  _json(
    id: id,
    status: status,
    name: name,
    partyDate: partyDate,
    partyTime: partyTime,
    branchId: branchId,
    planName: planName,
    childBirthDate: childBirthDate,
    child: child,
    discount: discount,
    payments: payments,
    comments: comments,
  ),
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme,
  locale: const Locale('uz'),
  localizationsDelegates: const [
    AppLocalization.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalization.delegate.supportedLocales,
  home: Scaffold(body: home),
);

void _bigView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Repo implements BirthdayPartiesRepository {
  _Repo({this.booked = const [], this.listError});
  final List<BirthdayParty> booked;
  final Object? listError;
  final confirmed = <(String, String)>[];
  Object? confirmError;

  @override
  Future<List<BirthdayParty>> list(BirthdayPartyStatus status) async {
    if (listError != null) throw listError!;
    return booked;
  }

  @override
  Future<List<BirthdayParty>> requests() async => const [];

  @override
  Future<BirthdayParty> confirm(String id, {required String time}) async {
    if (confirmError != null) throw confirmError!;
    confirmed.add((id, time));
    return _party(id: id, status: 'booked', partyTime: time);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('turningAge', () {
    test('birthday later in the party year: not yet', () {
      expect(turningAge('2020-11-24', '2026-11-22'), 5);
    });
    test('birthday earlier in the party year: already', () {
      expect(turningAge('2020-03-01', '2026-11-22'), 6);
    });
    test('birthday on the party day counts', () {
      expect(turningAge('2020-11-22', '2026-11-22'), 6);
    });
    test('29 February child in a common year: from 1 March', () {
      expect(turningAge('2020-02-29', '2025-02-28'), 4);
      expect(turningAge('2020-02-29', '2025-03-01'), 5);
      expect(turningAge('2020-02-29', '2028-02-29'), 8);
    });
    test('missing, unreadable or before birth: null', () {
      expect(turningAge(null, '2026-11-22'), isNull);
      expect(turningAge('2020-11-24', null), isNull);
      expect(turningAge('soon', '2026-11-22'), isNull);
      expect(turningAge('2027-01-01', '2026-11-22'), isNull);
    });
  });

  group('childBirthDate parsing', () {
    test('read from childBirthDate, ISO time cut off', () {
      expect(_party().childBirthDate, '2020-11-24');
      expect(
        _party(childBirthDate: '2020-11-24T00:00:00.000Z').childBirthDate,
        '2020-11-24',
      );
    });
    test('absent, null or garbage: null, the party still parses', () {
      final json = _json()..remove('childBirthDate');
      expect(BirthdayParty.fromJson(json).childBirthDate, isNull);
      expect(_party(childBirthDate: null).childBirthDate, isNull);
      expect(_party(childBirthDate: 42).childBirthDate, isNull);
      expect(_party(childBirthDate: '24.11.2020').childBirthDate, isNull);
    });
    test('falls back to child.birthDate', () {
      final p = _party(
        childBirthDate: null,
        child: const {'id': 'k1', 'name': 'Amira', 'birthDate': '2019-05-02'},
      );
      expect(p.childBirthDate, '2019-05-02');
    });
  });

  group('time slots', () {
    test('slots run 10:00 to 20:30 by half hours', () {
      final s = daySlots();
      expect(s.first, 600);
      expect(s.last, 20 * 60 + 30);
      expect(s, hasLength(22));
    });
    test('busy = same half hour, near = within an hour', () {
      final starts = [11 * 60, 16 * 60 + 15];
      expect(slotState(11 * 60, starts), SlotState.busy);
      expect(slotState(16 * 60, starts), SlotState.busy);
      expect(slotState(10 * 60, starts), SlotState.near);
      expect(slotState(12 * 60, starts), SlotState.near);
      expect(slotState(17 * 60, starts), SlotState.near);
      expect(slotState(13 * 60, starts), SlotState.free);
      expect(slotState(14 * 60, const []), SlotState.free);
    });
    test('HH:MM parsing', () {
      expect(parseHhmm('14:15'), 14 * 60 + 15);
      expect(parseHhmm('9:05'), 9 * 60 + 5);
      expect(parseHhmm('00:00'), 0);
      expect(parseHhmm('23:59'), 23 * 60 + 59);
      expect(parseHhmm('24:00'), isNull);
      expect(parseHhmm('12:60'), isNull);
      expect(parseHhmm('1215'), isNull);
      expect(parseHhmm(''), isNull);
    });
    test('day parties: same date and branch, timed, not the request', () {
      final request = _party();
      final day = dayPartiesFor(request, [
        _party(
          id: 'a',
          status: 'booked',
          partyTime: '16:00',
          name: 'Malika Saidova',
        ),
        _party(
          id: 'b',
          status: 'booked',
          partyTime: '11:00',
          name: 'Bobur Aliyev',
          planName: 'MAX',
        ),
        _party(id: 'c', status: 'booked', partyTime: '12:00', branchId: 'b2'),
        _party(
          id: 'd',
          status: 'booked',
          partyTime: '12:00',
          partyDate: '2026-11-23',
        ),
        _party(id: 'e', status: 'booked'),
        _party(id: 'r1', status: 'booked', partyTime: '13:00'),
      ]);
      expect(day.map((d) => d.label), [
        '11:00 MAX · Aliyev',
        '16:00 FUN · Saidova',
      ]);
    });
  });

  group('paid split', () {
    test('balance and online by provider, reversed online left out', () {
      final split = RequestPaidSplit.of(
        _party(
          payments: [
            {
              'id': 'p1',
              'kind': 'payment',
              'amountUzs': 300000,
              'fromBalanceUzs': 100000,
              'cashUzs': 0,
              'cardUzs': 0,
              'onlineUzs': 200000,
              'onlineProvider': 'click',
              'onlineReversedAt': null,
              'refundTo': null,
              'cashier': null,
              'createdAt': '2026-11-18T09:35:00.000Z',
            },
            {
              'id': 'p2',
              'kind': 'payment',
              'amountUzs': 50000,
              'fromBalanceUzs': 0,
              'cashUzs': 0,
              'cardUzs': 0,
              'onlineUzs': 50000,
              'onlineProvider': 'payme',
              'onlineReversedAt': '2026-11-18T10:00:00.000Z',
              'refundTo': null,
              'cashier': null,
              'createdAt': '2026-11-18T09:35:00.000Z',
            },
          ],
        ),
      );
      expect(split.balanceUzs, 100000);
      expect(split.clickUzs, 200000);
      expect(split.paymeUzs, 0);
      expect(split.totalUzs, 300000);
    });
  });

  group('details panel', () {
    final now = DateTime.utc(2026, 11, 18, 10, 0);

    testWidgets('renders every block', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _app(
          RequestDetailsPanel(
            now: now,
            party: _party(
              discount: 20000,
              comments: [
                {
                  'id': 'c1',
                  'text': 'Sharlar pushti bo‘lsin',
                  'author': 'Ota-ona',
                  'createdAt': '2026-11-18T09:36:00.000Z',
                },
              ],
            ),
          ),
        ),
      );
      // Header.
      expect(find.text('Dilnoza Karimova'), findsOneWidget);
      expect(
        find.text('998901234567 · ilovadan, 25 daqiqa oldin'),
        findsOneWidget,
      );
      expect(find.text('Tasdiqlash kutilmoqda'), findsOneWidget);
      // Bayram.
      expect(find.text('NOY'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('Yakshanba, 22-noyabr'), findsOneWidget);
      expect(find.text('4 kundan keyin · Megaplanet'), findsOneWidget);
      expect(find.text('Amira'), findsOneWidget);
      expect(find.text('Tug‘ilgan sana 24.11.2020'), findsOneWidget);
      expect(find.text('🎂 5 yoshga to‘ladi'), findsOneWidget);
      // Paket.
      expect(find.text('FUN'), findsOneWidget);
      expect(find.text('10 bola + 2 qo‘shimcha'), findsOneWidget);
      expect(find.text('Mehmonlar uchun kirish'), findsOneWidget);
      expect(find.text('Tortni olib chiqish'), findsOneWidget);
      expect(find.text('Paket (10 bola)'), findsOneWidget);
      expect(find.text('1 500 000'), findsOneWidget);
      expect(find.text('Qo‘shimcha bola 2 × 60 000'), findsOneWidget);
      expect(find.text('120 000'), findsWidgets);
      expect(find.text('Chegirma'), findsOneWidget);
      expect(find.text('−20 000'), findsOneWidget);
      expect(find.text("1 600 000 so'm"), findsOneWidget);
      // To'lov.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bd-details-pay-balance')),
          matching: find.text('500 000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bd-details-pay-card')),
          matching: find.text('1 000 000'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('bd-details-pay-cash')),
          matching: find.text('120 000'),
        ),
        findsOneWidget,
      );
      // Izoh.
      expect(find.byKey(const ValueKey('bd-details-comments')), findsOneWidget);
      expect(find.text('Sharlar pushti bo‘lsin'), findsOneWidget);
      expect(find.text('Ota-ona'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no birth date: no age; no comments: no Izoh', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _app(
          RequestDetailsPanel(now: now, party: _party(childBirthDate: null)),
        ),
      );
      expect(find.text('Amira'), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-details-age')), findsNothing);
      expect(find.textContaining('Tug‘ilgan sana'), findsNothing);
      expect(find.byKey(const ValueKey('bd-details-comments')), findsNothing);
      expect(find.text('Chegirma'), findsNothing);
    });

    testWidgets('no child at all: no child row', (tester) async {
      _bigView(tester);
      await tester.pumpWidget(
        _app(
          RequestDetailsPanel(
            now: now,
            party: _party(child: null, childBirthDate: null),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('bd-details-child')), findsNothing);
    });

    testWidgets('nothing paid in the app: one empty tile and the cash', (
      tester,
    ) async {
      _bigView(tester);
      await tester.pumpWidget(
        _app(
          RequestDetailsPanel(
            now: now,
            party: _party(payments: const []),
          ),
        ),
      );
      expect(find.text('Ilovada to‘lanmagan'), findsOneWidget);
      expect(find.byKey(const ValueKey('bd-details-pay-cash')), findsOneWidget);
    });

    Future<(List<String>, Finder)> openPanel(WidgetTester tester) async {
      _bigView(tester);
      final calls = <String>[];
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showRequestDetailsPanel(
                context,
                _party(),
                onConfirm: () => calls.add('confirm'),
                onReject: () => calls.add('reject'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('bd-details-panel'));
      expect(panel, findsOneWidget);
      return (calls, panel);
    }

    testWidgets('Tasdiqlash closes the panel and runs the confirm flow', (
      tester,
    ) async {
      final (calls, panel) = await openPanel(tester);
      await tester.tap(find.byKey(const ValueKey('bd-details-confirm')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(calls, ['confirm']);
    });

    testWidgets('Rad etish closes the panel and runs the reject flow', (
      tester,
    ) async {
      final (calls, panel) = await openPanel(tester);
      await tester.tap(find.byKey(const ValueKey('bd-details-reject')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(calls, ['reject']);
    });

    testWidgets('closes on ✕, Esc and the scrim, deciding nothing', (
      tester,
    ) async {
      final (calls, panel) = await openPanel(tester);
      await tester.tap(find.byKey(const ValueKey('bd-details-close')));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(panel, findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(100, 500));
      await tester.pumpAndSettle();
      expect(panel, findsNothing);
      expect(calls, isEmpty);
    });
  });

  group('confirm time picker', () {
    Future<_Repo> openDialog(
      WidgetTester tester, {
      List<BirthdayParty> booked = const [],
      Object? listError,
    }) async {
      _bigView(tester);
      final repo = _Repo(booked: booked, listError: listError);
      await tester.pumpWidget(
        _app(
          // The provider closes the cubit (and its poll timer) with the tree.
          BlocProvider(
            create: (_) => BirthdayRequestsCubit(repo),
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => showConfirmRequestDialog(
                  context,
                  _party(),
                  context.read<BirthdayRequestsCubit>(),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return repo;
    }

    String look(WidgetTester tester, String time) =>
        slotLookName(tester.widget(find.byKey(ValueKey('bd-slot-$time'))));

    FilledButton submit(WidgetTester tester) => tester.widget<FilledButton>(
      find.byKey(const ValueKey('bd-confirm-submit')),
    );

    final booked = [
      _party(
        id: 'a',
        status: 'booked',
        partyTime: '11:00',
        name: 'Bobur Aliyev',
        planName: 'MAX',
      ),
      _party(
        id: 'b',
        status: 'booked',
        partyTime: '16:00',
        name: 'Malika Saidova',
      ),
      // Another branch the same day: not shown, not marked.
      _party(id: 'c', status: 'booked', partyTime: '13:00', branchId: 'b2'),
    ];

    testWidgets('header, day strip and slot states', (tester) async {
      await openDialog(tester, booked: booked);
      expect(find.text('Bayram vaqtini tanlang'), findsOneWidget);
      expect(
        find.textContaining('Dilnoza Karimova · FUN · 12 bola'),
        findsOneWidget,
      );
      expect(find.text('SHU KUNI MEGAPLANET’DA'), findsOneWidget);
      expect(find.text('2 TA BAYRAM'), findsOneWidget);
      expect(find.text('11:00 MAX · Aliyev'), findsOneWidget);
      expect(find.text('16:00 FUN · Saidova'), findsOneWidget);
      expect(find.text('Ertalab'), findsOneWidget);
      expect(find.text('Kunduzi va kechqurun'), findsOneWidget);

      expect(look(tester, '11:00'), 'busy');
      expect(look(tester, '16:00'), 'busy');
      expect(look(tester, '10:00'), 'near');
      expect(look(tester, '10:30'), 'near');
      expect(look(tester, '11:30'), 'near');
      expect(look(tester, '12:00'), 'near');
      expect(look(tester, '15:00'), 'near');
      expect(look(tester, '17:00'), 'near');
      expect(look(tester, '12:30'), 'free');
      expect(look(tester, '13:00'), 'free');
      expect(look(tester, '20:30'), 'free');
      expect(find.byKey(const ValueKey('bd-slot-21:00')), findsNothing);
      // Legend.
      expect(find.text('tanlangan'), findsOneWidget);
      expect(find.text('boshqa bayram bor'), findsOneWidget);
      expect(find.text('yaqin, 1 soat ichida'), findsOneWidget);
    });

    testWidgets('a slot selects; the label names the time; sends it', (
      tester,
    ) async {
      final repo = await openDialog(tester, booked: booked);
      expect(submit(tester).onPressed, isNull);
      expect(find.text('Tasdiqlash'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('bd-slot-14:00')));
      await tester.pump();
      expect(look(tester, '14:00'), 'selected');
      expect(find.text('14:00 ga tasdiqlash'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('bd-confirm-day-selected')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('bd-confirm-busy-warning')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
      await tester.pumpAndSettle();
      expect(repo.confirmed, [('r1', '14:00')]);
    });

    testWidgets('a busy slot is still selectable, with a warning', (
      tester,
    ) async {
      await openDialog(tester, booked: booked);
      await tester.tap(find.byKey(const ValueKey('bd-slot-11:00')));
      await tester.pump();
      expect(
        find.text('Bu vaqtda boshqa bayram bor: 11:00 MAX · Aliyev'),
        findsOneWidget,
      );
      expect(submit(tester).onPressed, isNotNull);
      expect(find.text('11:00 ga tasdiqlash'), findsOneWidget);
    });

    testWidgets('Boshqa vaqt: validated, overrides the slot', (tester) async {
      final repo = await openDialog(tester, booked: booked);
      await tester.tap(find.byKey(const ValueKey('bd-slot-14:00')));
      await tester.pump();

      final field = find.byKey(const ValueKey('bd-confirm-other-time'));
      await tester.enterText(field, '25:00');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bd-confirm-other-invalid')),
        findsOneWidget,
      );
      expect(submit(tester).onPressed, isNull);
      expect(look(tester, '14:00'), isNot('selected'));

      await tester.enterText(field, '12:7');
      await tester.pump();
      expect(submit(tester).onPressed, isNull);

      await tester.enterText(field, '9:15');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bd-confirm-other-invalid')),
        findsNothing,
      );
      expect(find.text('09:15 ga tasdiqlash'), findsOneWidget);

      // Off-grid but inside 11:00's half hour: warned.
      await tester.enterText(field, '11:20');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('bd-confirm-busy-warning')),
        findsOneWidget,
      );

      await tester.enterText(field, '');
      await tester.pump();
      expect(submit(tester).onPressed, isNull);

      await tester.enterText(field, '14:15');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
      await tester.pumpAndSettle();
      expect(repo.confirmed, [('r1', '14:15')]);
    });

    testWidgets('the day failed to load: a note, times still choosable', (
      tester,
    ) async {
      final repo = await openDialog(tester, listError: Exception('offline'));
      expect(find.text('Kun jadvali yuklanmadi'), findsOneWidget);
      expect(look(tester, '11:00'), 'free');
      await tester.tap(find.byKey(const ValueKey('bd-slot-11:00')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
      await tester.pumpAndSettle();
      expect(repo.confirmed, [('r1', '11:00')]);
    });

    testWidgets('a refusal stays in the dialog as before', (tester) async {
      final repo = await openDialog(tester);
      repo.confirmError = ServerException(
        message: 'Sana o‘tgan',
        code: 'BIRTHDAY_PAST_DATE',
        statusCode: 400,
      );
      await tester.tap(find.byKey(const ValueKey('bd-slot-12:00')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bd-confirm-error')), findsOneWidget);
      expect(submit(tester).onPressed, isNotNull);
    });
  });
}
