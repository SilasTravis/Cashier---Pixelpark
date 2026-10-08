import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/today_passes_card.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/generated/l10n.dart';

ActivePass _pass(
  String childId,
  String? planKey,
  String label, {
  Duration left = const Duration(hours: 5),
}) => ActivePass(
  childId: childId,
  planKey: planKey,
  planLabel: label,
  expiresAt: DateTime.now().add(left),
  dueTodayUzs: 0,
);

class _FakeRemote implements PosAccountRemoteDataSource {
  _FakeRemote(this.passes);

  List<ActivePass> passes;
  final calls = <({String planKey, List<String> childIds})>[];
  int activePassReads = 0;

  @override
  Future<List<KidsPlan>> listPlans() async => const [
    KidsPlan(
      key: 'standard',
      name: 'Standart',
      kind: KidsPlanKind.perMinuteTiers,
      firstMinuteUzs: 1000,
      secondMinuteUzs: 1000,
      extraMinuteUzs: 1000,
      flatUzs: null,
    ),
  ];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async {
    activePassReads++;
    return passes;
  }

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => const [];

  @override
  Future<PosEntryResult> issuePlanEntry({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    bool replacePlan = false,
  }) async {
    calls.add((planKey: planKey, childIds: childIds));
    // No entries back → the panel skips the printer (not wired in tests).
    return const PosEntryResult(entries: [], conflicts: [], failures: []);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records hold their List by identity — compare as text.
String _describe(({String planKey, List<String> childIds}) g) =>
    '${g.planKey}:${g.childIds.join(',')}';

Child _child(String id, String name) => Child(
  id: id,
  firstName: name,
  lastName: null,
  birthDate: DateTime(2018, 1, 1),
);

Future<void> _pumpPanel(WidgetTester tester, _FakeRemote remote) async {
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final bloc = PosAccountBloc(PosAccountRepository(remote))
    ..add(const PosAccountPlansRequested())
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: 0,
          children: [
            _child('k1', 'Aziza'),
            _child('k2', 'Bek'),
            _child('k3', 'Lola'),
          ],
        ),
      ),
    );
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalization.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: BlocProvider.value(
        value: bloc,
        child: const Scaffold(
          body: SingleChildScrollView(child: CustomerDetailPanel()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TodayPassesCard.groupsFor', () {
    test('one request per plan; a deleted plan is skipped', () {
      final groups = TodayPassesCard.groupsFor([
        _pass('k1', 'standard', 'Standart'),
        _pass('k2', 'vip', 'VIP'),
        _pass('k3', 'standard', 'Standart'),
        _pass('k4', null, 'Eski tarif'),
      ]);
      expect(groups.map((g) => '${g.planKey}:${g.childIds.join(',')}'), [
        'standard:k1,k3',
        'vip:k2',
      ]);
    });
  });

  group('panel', () {
    testWidgets('no pass today → no card', (tester) async {
      await _pumpPanel(tester, _FakeRemote([]));
      expect(find.byType(TodayPassesCard), findsOneWidget);
      expect(find.text('Bugungi QR’lar'), findsNothing);
    });

    testWidgets('re-print sends the pass\'s own plan for that child only', (
      tester,
    ) async {
      final remote = _FakeRemote([
        _pass('k1', 'standard', 'Standart'),
        _pass('k2', 'vip', 'VIP'),
      ]);
      await _pumpPanel(tester, remote);
      expect(find.text('Bugungi QR’lar'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('reprint-k2')));
      await tester.tap(find.byKey(const ValueKey('reprint-k2')));
      await tester.pumpAndSettle();

      expect(remote.calls.map(_describe), ['vip:k2']);
    });

    testWidgets('"Hammasini" sends every plan group, one after another', (
      tester,
    ) async {
      final remote = _FakeRemote([
        _pass('k1', 'standard', 'Standart'),
        _pass('k2', 'vip', 'VIP'),
        _pass('k3', 'standard', 'Standart'),
      ]);
      await _pumpPanel(tester, remote);

      await tester.ensureVisible(find.byKey(const ValueKey('reprint-all')));
      await tester.tap(find.byKey(const ValueKey('reprint-all')));
      await tester.pumpAndSettle();

      expect(remote.calls.map(_describe), ['standard:k1,k3', 'vip:k2']);
    });

    testWidgets('an expired pass is never sent — the list is re-read', (
      tester,
    ) async {
      final remote = _FakeRemote([
        _pass('k1', 'vip', 'VIP', left: const Duration(milliseconds: 1)),
      ]);
      await _pumpPanel(tester, remote);
      final readsBefore = remote.activePassReads;
      remote.passes = [];

      await tester.ensureVisible(find.byKey(const ValueKey('reprint-k1')));
      await tester.tap(find.byKey(const ValueKey('reprint-k1')));
      await tester.pumpAndSettle();

      expect(remote.calls, isEmpty);
      expect(remote.activePassReads, greaterThan(readsBefore));
      expect(find.text('Bugungi QR’lar'), findsNothing);
    });
  });

  testWidgets('a narrow column shows an icon-only button, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: TodayPassesCard(
              passes: [_pass('k1', 'standard', 'Standart')],
              childNames: const {'k1': 'Abdurahmonova Mohinur Shavkatovna'},
              busy: false,
              onReprint: (_) {},
              onStale: () {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byKey(const ValueKey('reprint-k1')), findsOneWidget);
  });

  testWidgets('a pass ending at midnight reads "23:59 gacha"', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: Scaffold(
          body: TodayPassesCard(
            passes: [
              ActivePass(
                childId: 'k1',
                planKey: 'standard',
                planLabel: 'Standard',
                expiresAt: DateTime(now.year, now.month, now.day + 1),
                dueTodayUzs: 0,
              ),
            ],
            childNames: const {'k1': 'Sunatilla'},
            busy: false,
            onReprint: (_) {},
            onStale: () {},
          ),
        ),
      ),
    );
    expect(find.text('Standard · 23:59 gacha'), findsOneWidget);
  });
}
