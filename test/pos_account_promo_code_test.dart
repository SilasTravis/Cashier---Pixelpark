import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/core/widgets/promo_code_field.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/kids_plan.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/domain/pos_entry.dart';
import 'package:cashier_app/features/pos_account/domain/promo_code_check.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/generated/l10n.dart';

/// A valid code (15 digits + Luhn check digit) and one with a wrong check
/// digit — the terminal must never send the second.
const _code = '4000000000000002';
const _badCode = '4000000000000003';

/// Canned-response Dio adapter: records the last request and answers every
/// call with [payload].
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.payload);

  final Object payload;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

/// In-memory remote for bloc tests — every unused member throws.
class _FakeRemote implements PosAccountRemoteDataSource {
  PromoCodeCheck? check;
  List<Customer> searchResults = const [];
  final List<String> verified = [];
  final List<String> searched = [];

  PosEntryResult? checkoutResult;
  ServerException? checkoutError;
  ({String code, String childId})? lastPromoCode;
  Map<String, String>? lastEntryDiscounts;

  @override
  Future<PromoCodeCheck> verifyPromoCode(String code) async {
    verified.add(code);
    return check!;
  }

  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async {
    searched.add(query);
    return searchResults;
  }

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> entryDiscounts = const {},
    int companions = 0,
    String? discountId,
    ({String code, String childId})? promoCode,
  }) async {
    lastPromoCode = promoCode;
    lastEntryDiscounts = entryDiscounts;
    if (checkoutError != null) throw checkoutError!;
    return checkoutResult!;
  }

  List<ActivePass> activePasses = const [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async =>
      activePasses;

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
    KidsPlan(
      key: 'vip',
      name: 'VIP',
      kind: KidsPlanKind.flatDay,
      firstMinuteUzs: null,
      secondMinuteUzs: null,
      extraMinuteUzs: null,
      flatUzs: 75000,
    ),
  ];

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => scope == DiscountScope.entry
      ? const [
          Discount(
            id: 'disc-partial',
            name: 'Flayer',
            kind: DiscountKind.percent,
            value: 10,
            scope: DiscountScope.entry,
          ),
        ]
      : const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Customer _customer(int id, String phone) => Customer(
  id: id,
  phoneNumber: phone,
  firstName: 'Dil',
  lastName: null,
  balance: 100000,
  children: const [],
);

PromoCodeCheck _check({int ownerId = 7}) => PromoCodeCheck(
  code: _code,
  partnerName: 'Fonus',
  tierName: 'Premium',
  discount: const Discount(
    id: 'discount-1',
    name: 'Fonus · Premium',
    kind: DiscountKind.percent,
    value: 30,
    scope: DiscountScope.entry,
  ),
  expiresAt: DateTime(2026, 9, 28, 12),
  owner: PromoCodeOwner(id: ownerId, phoneNumber: '+998901112233'),
);

const _checkout = PosAccountCheckoutRequested(
  planKey: 'vip',
  childIds: ['child-1'],
  products: [],
  cashUzs: 0,
  cardUzs: 0,
  promoCode: (code: _code, childId: 'child-1'),
);

/// Opens [customer] and waits until the bloc has settled on it.
Future<PosAccountBloc> _blocWith(_FakeRemote remote, Customer customer) async {
  final bloc = PosAccountBloc(PosAccountRepository(remote));
  addTearDown(bloc.close);
  bloc.add(PosAccountCustomerSelected(customer));
  await bloc.stream.firstWhere((s) => s.selectedCustomer?.id == customer.id);
  return bloc;
}

void main() {
  group('data source', () {
    test('verifyPromoCode posts the code and parses its owner', () async {
      final adapter = _FakeAdapter({
        'source': 'partner',
        'customer': {
          'id': 7,
          'phoneNumber': '+998901112233',
          'firstName': 'Dil',
          'lastName': null,
        },
        'partner': {'id': 'p1', 'name': 'Fonus'},
        'tier': {'code': 'premium', 'name': 'Premium'},
        'discount': {
          'id': 'discount-1',
          'name': 'Fonus · Premium',
          'kind': 'percent',
          'value': 30,
        },
        'maxChildren': 1,
        'expiresAt': '2026-09-28T07:15:00.000Z',
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;

      final check = await PosAccountRemoteDataSourceImpl(
        dio,
      ).verifyPromoCode(_code);

      expect(adapter.lastRequest!.path, '/v1/pos/promo-codes/verify');
      expect(adapter.lastRequest!.data, {'code': _code});
      expect(check.code, _code);
      expect(check.partnerName, 'Fonus');
      expect(check.owner!.id, 7);
      expect(check.discount.scope, DiscountScope.entry);
      expect(check.discount.appliedDiscountUzs(100000), 30000);
    });

    test(
      'planEntryCheckout sends the promo code and parses the outcome',
      () async {
        final adapter = _FakeAdapter({
          'entries': <Object>[],
          'failures': <Object>[],
          'promoCode': {
            'status': 'released',
            'childId': 'child-1',
            'partnerName': 'Fonus',
            'tierName': 'Premium',
            'reasonCode': 'PROMO_CODE_CHILD_HAS_PASS',
          },
        });
        final dio = Dio(BaseOptions(baseUrl: 'http://x'))
          ..httpClientAdapter = adapter;

        final result = await PosAccountRemoteDataSourceImpl(dio)
            .planEntryCheckout(
              customerId: 7,
              planKey: 'vip',
              childIds: const ['child-1'],
              products: const [],
              cashUzs: 0,
              cardUzs: 0,
              promoCode: (code: _code, childId: 'child-1'),
            );

        expect(
          (adapter.lastRequest!.data as Map<String, dynamic>)['promoCode'],
          {'code': _code, 'childId': 'child-1'},
        );
        expect(
          result.promoCode,
          const PromoCodeOutcome(
            applied: false,
            childId: 'child-1',
            reasonCode: 'PROMO_CODE_CHILD_HAS_PASS',
          ),
        );
      },
    );
  });

  group('bloc', () {
    test('a code failing the check digit never reaches the server', () async {
      final remote = _FakeRemote();
      final bloc = await _blocWith(remote, _customer(7, '+998901112233'));

      bloc.add(const PosAccountPromoCodeSubmitted(_badCode));
      await bloc.stream.firstWhere((s) => s.promoErrorCode != null);

      expect(bloc.state.promoErrorCode, 'PROMO_CODE_INVALID_FORMAT');
      expect(remote.verified, isEmpty);
    });

    test('the open customer\'s own code is applied as-is', () async {
      final remote = _FakeRemote()..check = _check();
      final bloc = await _blocWith(remote, _customer(7, '+998901112233'));

      // Scanners/hand typing may add the display form's spaces.
      bloc.add(const PosAccountPromoCodeSubmitted('4000 0000 0000 0002'));
      await bloc.stream.firstWhere((s) => s.promo != null);

      expect(remote.verified, [_code]);
      expect(remote.searched, isEmpty);
      expect(bloc.state.promo!.code, _code);
    });

    test(
      'another customer\'s code opens its owner and keeps the code',
      () async {
        final owner = _customer(9, '+998901112233');
        final remote = _FakeRemote()
          ..check = _check(ownerId: 9)
          ..searchResults = [_customer(8, '+998901112299'), owner];
        final bloc = await _blocWith(remote, _customer(7, '+998900000000'));

        bloc.add(const PosAccountPromoCodeSubmitted(_code));
        await bloc.stream.firstWhere(
          (s) => s.selectedCustomer?.id == 9 && !s.isCheckingPromo,
        );

        expect(remote.searched, ['+998901112233']);
        expect(bloc.state.promo!.owner!.id, 9);
      },
    );

    test('an owner the search cannot find is reported, not guessed', () async {
      final remote = _FakeRemote()
        ..check = _check(ownerId: 9)
        ..searchResults = [_customer(8, '+998901112233')];
      final bloc = await _blocWith(remote, _customer(7, '+998900000000'));

      bloc.add(const PosAccountPromoCodeSubmitted(_code));
      await bloc.stream.firstWhere((s) => s.promoErrorCode != null);

      expect(bloc.state.promoErrorCode, 'PROMO_CODE_OWNER_NOT_FOUND');
      expect(bloc.state.promo, isNull);
      expect(bloc.state.selectedCustomer!.id, 7);
    });

    test('opening another customer drops the code', () async {
      final remote = _FakeRemote()..check = _check();
      final bloc = await _blocWith(remote, _customer(7, '+998901112233'));
      bloc.add(const PosAccountPromoCodeSubmitted(_code));
      await bloc.stream.firstWhere((s) => s.promo != null);

      bloc.add(PosAccountCustomerSelected(_customer(8, '+998900000000')));
      await bloc.stream.firstWhere((s) => s.selectedCustomer?.id == 8);

      expect(bloc.state.promo, isNull);
    });

    Future<PosAccountBloc> withPromo(_FakeRemote remote) async {
      remote.check = _check();
      final bloc = await _blocWith(remote, _customer(7, '+998901112233'));
      bloc.add(const PosAccountPromoCodeSubmitted(_code));
      await bloc.stream.firstWhere((s) => s.promo != null);
      return bloc;
    }

    test('a code refused at checkout is dropped with the reason', () async {
      final remote = _FakeRemote()
        ..checkoutError = ServerException(
          message: 'Promokod allaqachon ishlatilgan',
          code: 'PROMO_CODE_ALREADY_USED',
        );
      final bloc = await withPromo(remote);

      bloc.add(_checkout);
      await bloc.stream.firstWhere((s) => !s.isBusy && s.errorCode != null);

      expect(remote.lastPromoCode, (code: _code, childId: 'child-1'));
      expect(bloc.state.promo, isNull);
      expect(bloc.state.promoErrorCode, 'PROMO_CODE_ALREADY_USED');
      expect(bloc.state.promoErrorMessage, 'Promokod allaqachon ishlatilgan');
    });

    test('a child-level refusal keeps the code for another child', () async {
      final remote = _FakeRemote()
        ..checkoutError = ServerException(
          message: 'Bola noto‘g‘ri',
          code: 'PROMO_CODE_CHILD_INVALID',
        );
      final bloc = await withPromo(remote);

      bloc.add(_checkout);
      await bloc.stream.firstWhere((s) => !s.isBusy && s.errorCode != null);

      expect(bloc.state.promo, isNotNull);
      expect(bloc.state.promoErrorCode, 'PROMO_CODE_CHILD_INVALID');
    });

    test('a released code stays on screen with the child\'s failure', () async {
      final remote = _FakeRemote()
        ..checkoutResult = const PosEntryResult(
          entries: [],
          failures: [
            PosEntryFailure(
              childId: 'child-1',
              code: 'PROMO_CODE_CHILD_HAS_PASS',
              message: 'Bolada bugun propusk bor',
            ),
          ],
          promoCode: PromoCodeOutcome(
            applied: false,
            childId: 'child-1',
            reasonCode: 'PROMO_CODE_CHILD_HAS_PASS',
          ),
        );
      final bloc = await withPromo(remote);

      bloc.add(_checkout);
      await bloc.stream.firstWhere((s) => s.lastEntryResult != null);

      expect(bloc.state.promo, isNotNull);
      expect(bloc.state.promoErrorCode, 'PROMO_CODE_RELEASED');
      expect(bloc.state.promoErrorMessage, 'Bolada bugun propusk bor');
    });

    test('an applied code is done with', () async {
      final remote = _FakeRemote()
        ..checkoutResult = const PosEntryResult(
          entries: [],
          failures: [],
          promoCode: PromoCodeOutcome(applied: true, childId: 'child-1'),
        );
      final bloc = await withPromo(remote);

      bloc.add(_checkout);
      await bloc.stream.firstWhere((s) => s.lastEntryResult != null);

      expect(bloc.state.promo, isNull);
      expect(bloc.state.promoErrorCode, isNull);
    });
  });

  group('panel', () {
    Future<void> pumpPanel(
      WidgetTester tester,
      _FakeRemote remote,
      List<Child> children,
    ) async {
      // The panel is a desktop two-column layout — give it desktop room.
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      remote
        ..check = _check()
        ..checkoutResult = const PosEntryResult(
          entries: [],
          failures: [],
          promoCode: PromoCodeOutcome(applied: true, childId: 'child-1'),
        );
      final bloc = PosAccountBloc(PosAccountRepository(remote))
        ..add(const PosAccountPlansRequested())
        ..add(const PosAccountDiscountsRequested(scope: DiscountScope.entry))
        ..add(
          PosAccountCustomerSelected(
            Customer(
              id: 7,
              phoneNumber: '+998901112233',
              firstName: 'Dil',
              lastName: null,
              balance: 0,
              children: children,
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

    Child child(String id, String name) => Child(
      id: id,
      firstName: name,
      lastName: null,
      birthDate: DateTime(2018, 1, 1),
    );

    Future<void> scan(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextField, 'Promokod'), _code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    const label = 'Fonus · Premium · −30%';

    testWidgets('a scanned code discounts the child and rides the checkout', (
      tester,
    ) async {
      final remote = _FakeRemote();
      await pumpPanel(tester, remote, [child('child-1', 'Aziza')]);

      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('VIP'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '75000'), findsOneWidget);

      await scan(tester);

      // The chip on the child's row and in the checkout's promo section;
      // the row's own 3-dots discount menu gives way to the code.
      expect(find.text(label), findsNWidgets(2));
      expect(find.byTooltip('Chegirma'), findsNothing);
      // 75 000 − 30% = 52 500 still due.
      expect(find.widgetWithText(TextField, '52500'), findsOneWidget);

      await tester.tap(find.text('To‘lov va chop etish'));
      await tester.pumpAndSettle();

      expect(remote.lastPromoCode, (code: _code, childId: 'child-1'));
      expect(remote.lastEntryDiscounts, isEmpty);
      // Applied — the section is back to an empty "Promokod" field.
      expect(find.text(label), findsNothing);
    });

    testWidgets('the code goes to a selected child without a pass today', (
      tester,
    ) async {
      final remote = _FakeRemote()
        ..activePasses = [
          ActivePass(
            childId: 'child-1',
            planKey: 'standard',
            planLabel: 'Standart',
            expiresAt: DateTime(2026, 9, 28, 22),
            dueTodayUzs: 0,
          ),
        ];
      await pumpPanel(tester, remote, [
        child('child-1', 'Aziza'),
        child('child-2', 'Bobur'),
      ]);

      await tester.tap(find.text('QR').at(0));
      await tester.pump();
      await tester.tap(find.text('QR').at(1));
      await tester.pump();
      await tester.tap(find.text('Standart').first);
      await tester.pumpAndSettle();

      await scan(tester);

      await tester.tap(find.text('Kirish (2)'));
      await tester.pumpAndSettle();

      expect(remote.lastPromoCode, (code: _code, childId: 'child-2'));
    });

    testWidgets('a child with a pass today never gets the code', (
      tester,
    ) async {
      final remote = _FakeRemote()
        ..activePasses = [
          ActivePass(
            childId: 'child-1',
            planKey: 'standard',
            planLabel: 'Standart',
            expiresAt: DateTime(2026, 9, 28, 22),
            dueTodayUzs: 0,
          ),
        ];
      await pumpPanel(tester, remote, [child('child-1', 'Aziza')]);
      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.tap(find.text('Standart').first);
      await tester.pumpAndSettle();

      await scan(tester);

      // Its re-print must not fail over the code — which stays unsent.
      expect(find.text('Promokod uchun bolani tanlang'), findsOneWidget);
      await tester.tap(find.text('Kirish (1)'));
      await tester.pumpAndSettle();
      expect(remote.lastPromoCode, isNull);
    });

    testWidgets('✕ drops the code and restores the row\'s own discount', (
      tester,
    ) async {
      final remote = _FakeRemote();
      await pumpPanel(tester, remote, [child('child-1', 'Aziza')]);
      await tester.tap(find.text('QR'));
      await tester.pump();

      await tester.tap(find.byTooltip('Chegirma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flayer (10%)'));
      await tester.pumpAndSettle();
      await scan(tester);
      expect(find.text('Chegirma: Flayer'), findsNothing);

      await tester.tap(find.byTooltip('Promokodni olib tashlash'));
      await tester.pumpAndSettle();

      expect(find.text(label), findsNothing);
      expect(find.text('Chegirma: Flayer'), findsOneWidget);
    });
  });

  group('PromoCodeField', () {
    Future<List<String>> pump(WidgetTester tester) async {
      final submitted = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalization.delegate.supportedLocales,
          home: Scaffold(
            body: PromoCodeField(autofocus: true, onSubmit: submitted.add),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return submitted;
    }

    testWidgets('Enter from the scanner submits and clears the field', (
      tester,
    ) async {
      final submitted = await pump(tester);

      await tester.enterText(find.byType(TextField), _code);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, [_code]);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('a Tab suffix submits instead of moving focus', (tester) async {
      final submitted = await pump(tester);

      await tester.enterText(find.byType(TextField), _code);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(submitted, [_code]);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode!.hasFocus, isTrue);
    });

    testWidgets('letters never land in the field', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), '40ab00');

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '4000');
    });
  });
}
