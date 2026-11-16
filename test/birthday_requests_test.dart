import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/theme/app_theme.dart';
import 'package:cashier_app/features/birthday_parties/data/birthday_parties_repository.dart';
import 'package:cashier_app/features/birthday_parties/domain/birthday_party.dart';
import 'package:cashier_app/features/birthday_parties/presentation/bloc/birthday_requests_cubit.dart';
import 'package:cashier_app/features/birthday_parties/presentation/pages/birthday_events_page.dart';
import 'package:cashier_app/features/shell/presentation/model/shell_tab.dart';
import 'package:cashier_app/features/shell/presentation/widgets/top_nav.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/injector_container.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _requestJson({
  String id = 'r1',
  String name = 'Ali Valiyev',
  List<Map<String, dynamic>>? payments,
}) => {
  'id': id,
  'status': 'requested',
  'paymentState': 'partial',
  'branchId': 'b1',
  'branchName': 'Megaplanet',
  'customer': {'id': 42, 'fullName': name, 'phoneNumber': '998901112233'},
  'child': {'id': 'k1', 'name': 'Madina'},
  'plan': {'id': 'vip', 'name': 'VIP', 'color': '#7C3AED', 'includedItems': []},
  'childCount': 10,
  'extraChildren': 0,
  'packagePriceUzs': 2240000,
  'extraChildUzs': 0,
  'listPriceUzs': 2240000,
  'agreedPriceUzs': 2240000,
  'discountUzs': 0,
  'paidUzs': 1000000,
  'refundedUzs': 0,
  'debtUzs': 1240000,
  'keptUzs': 0,
  'maxCashRefundUzs': 0,
  'partyDate': '2999-01-01',
  'source': 'app',
  'soldBy': null,
  'createdAt': '2026-11-06T10:00:00.000Z',
  'completedAt': null,
  'cancelledAt': null,
  'cancelReason': null,
  'payments':
      payments ??
      [
        {
          'id': 'pay1',
          'kind': 'payment',
          'amountUzs': 1000000,
          'fromBalanceUzs': 200000,
          'cashUzs': 0,
          'cardUzs': 0,
          'onlineUzs': 800000,
          'onlineProvider': 'click',
          'onlineReversedAt': null,
          'refundTo': null,
          'cashier': null,
          'createdAt': '2026-11-06T10:00:00.000Z',
        },
      ],
  'comments': <Map<String, dynamic>>[],
};

BirthdayParty _request({String id = 'r1', String name = 'Ali Valiyev'}) =>
    BirthdayParty.fromJson(_requestJson(id: id, name: name));

class _Repo implements BirthdayPartiesRepository {
  _Repo(this.requestList);
  List<BirthdayParty> requestList;
  final listCalls = <BirthdayPartyStatus>[];
  int requestsCalls = 0;
  bool failNext = false;
  final confirmed = <(String, String)>[];
  final rejected = <(String, String, String)>[];
  Object? confirmError;
  Object? rejectError;
  BirthdayParty? getResult;

  @override
  Future<List<BirthdayParty>> requests() async {
    requestsCalls++;
    if (failNext) throw Exception('offline');
    return List.of(requestList);
  }

  @override
  Future<List<BirthdayParty>> list(BirthdayPartyStatus status) async {
    listCalls.add(status);
    return const [];
  }

  @override
  Future<BirthdayParty> confirm(String id, {required String time}) async {
    if (confirmError != null) throw confirmError!;
    confirmed.add((id, time));
    return requestList.firstWhere((p) => p.id == id);
  }

  @override
  Future<BirthdayParty> reject(
    String id, {
    required String reason,
    required String requestId,
  }) async {
    if (rejectError != null) throw rejectError!;
    rejected.add((id, reason, requestId));
    return requestList.firstWhere((p) => p.id == id);
  }

  @override
  Future<BirthdayParty> get(String id) async =>
      getResult ?? (throw Exception('offline'));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_Repo> _pump(WidgetTester tester, List<BirthdayParty> requests) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = _Repo(requests);
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
      home: Scaffold(
        body: BlocProvider(
          create: (_) => BirthdayRequestsCubit(repo)..load(),
          child: BirthdayEventsPage(onOpen: (_) {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

FilledButton _button(WidgetTester tester, String key) =>
    tester.widget<FilledButton>(find.byKey(ValueKey(key)));

void main() {
  tearDown(() => sl.reset());

  testWidgets('a request renders an amber card with its money split', (
    tester,
  ) async {
    await _pump(tester, [_request()]);
    expect(find.textContaining('SO‘ROVLAR'), findsOneWidget);
    expect(find.byKey(const ValueKey('bd-request-r1')), findsOneWidget);
    expect(find.text('Ali Valiyev'), findsWidgets);
    expect(find.textContaining('998901112233'), findsOneWidget);
    expect(find.textContaining('Madina'), findsOneWidget);
    expect(find.text('VIP'), findsOneWidget);
    expect(find.textContaining('01.01.2999'), findsOneWidget);
    // 200 000 from balance + 800 000 online.
    expect(find.textContaining('Ilovada to‘langan'), findsOneWidget);
    expect(find.textContaining('1 000 000'), findsWidgets);
    expect(find.textContaining('Naqd qoladi'), findsOneWidget);
    expect(find.textContaining('1 240 000'), findsOneWidget);
  });

  testWidgets('no requests: no section', (tester) async {
    await _pump(tester, const []);
    expect(find.textContaining('SO‘ROVLAR'), findsNothing);
  });

  testWidgets('the Tadbirlar tab badge shows the count', (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = _Repo([_request(), _request(id: 'r2')]);
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
        home: Scaffold(
          body: BlocProvider(
            create: (_) => BirthdayRequestsCubit(repo)..load(),
            child: const EventsTabBadgeTestHost(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Tasdiqlash is disabled until a time is picked, sends HH:MM', (
    tester,
  ) async {
    final repo = await _pump(tester, [_request()]);
    await tester.tap(find.byKey(const ValueKey('bd-request-confirm-r1')));
    await tester.pumpAndSettle();
    expect(_button(tester, 'bd-confirm-submit').onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('bd-confirm-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(_button(tester, 'bd-confirm-submit').onPressed, isNotNull);

    repo.listCalls.clear();
    await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
    await tester.pumpAndSettle();
    expect(repo.confirmed, [('r1', '12:00')]);
    // The card left the section and the booked list was refreshed.
    expect(find.byKey(const ValueKey('bd-request-r1')), findsNothing);
    expect(repo.listCalls, contains(BirthdayPartyStatus.booked));
  });

  testWidgets('Rad etish needs 3 chars and names the refund', (tester) async {
    final repo = await _pump(tester, [_request()]);
    await tester.tap(find.byKey(const ValueKey('bd-request-reject-r1')));
    await tester.pumpAndSettle();
    expect(
      find.text('1 000 000 so\'m mijoz balansiga qaytariladi'),
      findsOneWidget,
    );
    expect(_button(tester, 'bd-reject-submit').onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('bd-reject-reason')),
      'ab',
    );
    await tester.pump();
    expect(_button(tester, 'bd-reject-submit').onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('bd-reject-reason')),
      'Joy yo‘q',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bd-reject-submit')));
    await tester.pumpAndSettle();
    expect(repo.rejected.single.$1, 'r1');
    expect(repo.rejected.single.$2, 'Joy yo‘q');
    expect(repo.rejected.single.$3, isNotEmpty);
    expect(find.byKey(const ValueKey('bd-request-r1')), findsNothing);
  });

  testWidgets('already decided removes the card and says so', (tester) async {
    final repo = await _pump(tester, [_request()]);
    repo.confirmError = ServerException(
      message: 'x',
      code: 'BIRTHDAY_REQUEST_ALREADY_DECIDED',
      statusCode: 409,
    );
    await tester.tap(find.byKey(const ValueKey('bd-request-confirm-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bd-confirm-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bd-confirm-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bd-request-r1')), findsNothing);
    expect(find.text('Bu so‘rov allaqachon ko‘rib chiqilgan'), findsOneWidget);
  });

  test('the cubit polls every interval and stops on close', () {
    fakeAsync((async) {
      final repo = _Repo([_request()]);
      final cubit = BirthdayRequestsCubit(
        repo,
        pollInterval: const Duration(seconds: 60),
      );
      cubit.load();
      async.flushMicrotasks();
      expect(repo.requestsCalls, 1);
      expect(cubit.state.requests, hasLength(1));
      async.elapse(const Duration(seconds: 60));
      expect(repo.requestsCalls, 2);
      async.elapse(const Duration(seconds: 120));
      expect(repo.requestsCalls, 4);
      cubit.close();
      async.elapse(const Duration(minutes: 5));
      expect(repo.requestsCalls, 4);
    });
  });

  test('a failed poll keeps the cards already shown', () {
    fakeAsync((async) {
      final repo = _Repo([_request()]);
      final cubit = BirthdayRequestsCubit(repo);
      cubit.load();
      async.flushMicrotasks();
      expect(cubit.state.requests, hasLength(1));
      repo.failNext = true;
      cubit.load();
      async.flushMicrotasks();
      expect(cubit.state.requests, hasLength(1));
      expect(cubit.state.error, isNotNull);
      cubit.close();
    });
  });
}

/// The shell's top bar as the shell builds it: the Tadbirlar badge is the
/// number of open requests.
class EventsTabBadgeTestHost extends StatelessWidget {
  const EventsTabBadgeTestHost({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<BirthdayRequestsCubit, BirthdayRequestsState>(
        builder: (context, state) => TopNav(
          selected: ShellTab.events,
          counts: {ShellTab.events: state.requests.length},
          onSelect: (_) {},
          cashierName: 'x',
          shiftOpenedAt: null,
          onCloseShift: null,
          updateAvailable: ValueNotifier(false),
        ),
      );
}
