import 'dart:convert';

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
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _codeId = '3f0c2b9e-5a53-4a3b-9a3e-0d7c1d1c9a11';
const _ref = 'id:$_codeId';

const _discount = Discount(
  id: 'discount-1',
  name: 'Fonus · Premium',
  kind: DiscountKind.percent,
  value: 30,
  scope: DiscountScope.entry,
);

final _listed = CustomerPromoCode(
  codeId: _codeId,
  partnerName: 'Fonus',
  tierName: 'Premium',
  discount: _discount,
  expiresAt: DateTime(2026, 12, 5, 23, 59),
  codeLast4: 'PT',
  code: 'PFTENPT',
);

PromoCodeCheck _pickedCheck() => PromoCodeCheck(
  code: _ref,
  partnerName: 'Fonus',
  tierName: 'Premium',
  discount: _discount,
  expiresAt: DateTime(2026, 12, 5, 23, 59),
  owner: const PromoCodeOwner(id: 7, phoneNumber: '+998901112233'),
);

Customer _customer({List<Child> children = const []}) => Customer(
  id: 7,
  phoneNumber: '+998901112233',
  firstName: 'Dil',
  lastName: null,
  balance: 0,
  children: children,
);

/// Records every request and answers each with [payload].
class _Adapter implements HttpClientAdapter {
  _Adapter(this.payload);

  final Object payload;
  late RequestOptions last;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class _FakeRemote implements PosAccountRemoteDataSource {
  List<CustomerPromoCode> listed = [_listed];
  ServerException? listError;
  ServerException? verifyError;
  final List<String> verified = [];
  final List<int?> verifiedFor = [];
  int listCalls = 0;
  ({String code, String childId})? lastPromoCode;

  @override
  Future<List<CustomerPromoCode>> fetchCustomerPromoCodes(
    int customerId,
  ) async {
    listCalls++;
    if (listError != null) throw listError!;
    return listed;
  }

  @override
  Future<PromoCodeCheck> verifyPromoCode(String code, {int? customerId}) async {
    verified.add(code);
    verifiedFor.add(customerId);
    if (verifyError != null) throw verifyError!;
    return _pickedCheck();
  }

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String? planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> entryDiscounts = const {},
    Map<String, int> birthdayAges = const {},
    int companions = 0,
    String? discountId,
    ({String code, String childId})? promoCode,
    String? checkDiscountId,
    bool replacePlan = false,
    List<String> subscriptionChildIds = const [],
  }) async {
    lastPromoCode = promoCode;
    return const PosEntryResult(
      entries: [],
      failures: [],
      promoCode: PromoCodeOutcome(applied: true, childId: 'child-1'),
    );
  }

  @override
  Future<List<KidsPlan>> listPlans() async => const [
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
  }) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PosAccountBloc> _blocWith(_FakeRemote remote) async {
  final bloc = PosAccountBloc(PosAccountRepository(remote));
  addTearDown(bloc.close);
  bloc.add(PosAccountCustomerSelected(_customer()));
  await bloc.stream.firstWhere((s) => s.selectedCustomer?.id == 7);
  return bloc;
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('uz'),
  localizationsDelegates: const [
    AppLocalization.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalization.delegate.supportedLocales,
  home: home,
);

void main() {
  group('code references', () {
    test('a picked code travels as id:<codeId>; typed codes are not refs', () {
      expect(promoCodeRefOf(_codeId), _ref);
      expect(promoCodeIdOf(_ref), _codeId);
      expect(promoCodeIdOf('4000000000000002'), isNull);
      expect(promoCodeIdOf('ALI20'), isNull);
    });

    test('an empty server code (lookup by id) keeps the reference', () {
      final check = PromoCodeCheck.fromJson(_ref, {
        'codeId': _codeId,
        'source': 'partner',
        'code': '',
        'customer': {
          'id': 7,
          'phoneNumber': '+998901112233',
          'firstName': null,
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
        'expiresAt': '2026-12-05T18:59:59.999Z',
      });
      expect(check.code, _ref);
      expect(check.owner?.id, 7);
    });
  });

  group('data source', () {
    test('lists the customer\'s codes with their tail', () async {
      final adapter = _Adapter([
        {
          'codeId': _codeId,
          'partner': {'id': 'p1', 'name': 'Fonus'},
          'tier': {'code': 'premium', 'name': 'Premium'},
          'discount': {
            'id': 'discount-1',
            'name': 'Fonus · Premium',
            'kind': 'percent',
            'value': 30,
          },
          'expiresAt': '2026-12-05T18:59:59.999Z',
          'codeLast4': 'PT',
          'code': 'PFTENPT',
        },
      ]);
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;

      final codes = await PosAccountRemoteDataSourceImpl(
        dio,
      ).fetchCustomerPromoCodes(7);

      expect(adapter.last.method, 'GET');
      expect(adapter.last.path, '/v1/pos/promo-codes');
      expect(adapter.last.queryParameters, {'customerId': 7});
      expect(codes.single.codeId, _codeId);
      expect(codes.single.codeLast4, 'PT');
      expect(codes.single.code, 'PFTENPT');
      expect(codes.single.discount.value, 30);
    });

    test('verify sends codeId (not code) for a reference', () async {
      final adapter = _Adapter({
        'codeId': _codeId,
        'source': 'partner',
        'code': '',
        'customer': {'id': 7, 'phoneNumber': '+998901112233'},
        'partner': {'id': 'p1', 'name': 'Fonus'},
        'tier': {'code': 'premium', 'name': 'Premium'},
        'discount': {
          'id': 'discount-1',
          'name': 'Fonus · Premium',
          'kind': 'percent',
          'value': 30,
        },
        'maxChildren': 1,
        'expiresAt': '2026-12-05T18:59:59.999Z',
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;

      await PosAccountRemoteDataSourceImpl(
        dio,
      ).verifyPromoCode(_ref, customerId: 7);

      expect(adapter.last.data, {'codeId': _codeId, 'customerId': 7});
    });

    test('verify still sends a typed code as code', () async {
      final adapter = _Adapter({
        'source': 'blogger',
        'code': 'ALI20',
        'customer': null,
        'partner': {'id': 'p1', 'name': 'Ali'},
        'tier': {'code': 'gold', 'name': 'Oltin'},
        'discount': {
          'id': 'discount-2',
          'name': 'Ali · Oltin',
          'kind': 'percent',
          'value': 20,
        },
        'maxChildren': 1,
        'expiresAt': null,
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;

      await PosAccountRemoteDataSourceImpl(dio).verifyPromoCode('ALI20');

      expect(adapter.last.data, {'code': 'ALI20'});
    });

    test('the checkout sends codeId for a reference, code otherwise', () async {
      final adapter = _Adapter({'entries': [], 'failures': []});
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final remote = PosAccountRemoteDataSourceImpl(dio);

      Future<Map<String, dynamic>> sent(String code) async {
        await remote.planEntryCheckout(
          customerId: 7,
          planKey: 'vip',
          childIds: const ['child-1'],
          products: const [],
          cashUzs: 0,
          cardUzs: 0,
          promoCode: (code: code, childId: 'child-1'),
        );
        return (adapter.last.data as Map<String, dynamic>)['promoCode']
            as Map<String, dynamic>;
      }

      expect(await sent(_ref), {'codeId': _codeId, 'childId': 'child-1'});
      expect(await sent('4000000000000002'), {
        'code': '4000000000000002',
        'childId': 'child-1',
      });
    });
  });

  group('bloc', () {
    test('requested loads the open customer\'s codes', () async {
      final remote = _FakeRemote();
      final bloc = await _blocWith(remote);

      bloc.add(const PosAccountPromoCodesRequested());
      final state = await bloc.stream.firstWhere(
        (s) => s.customerPromoCodes != null,
      );

      expect(state.customerPromoCodes, [_listed]);
      expect(state.isLoadingPromoCodes, isFalse);
      expect(state.promoCodesFailed, isFalse);
    });

    test('a failed list is flagged, not shown as "no codes"', () async {
      final remote = _FakeRemote()
        ..listError = ServerException(message: 'down', statusCode: 500);
      final bloc = await _blocWith(remote);

      bloc.add(const PosAccountPromoCodesRequested());
      final state = await bloc.stream.firstWhere((s) => s.promoCodesFailed);

      expect(state.customerPromoCodes, isNull);
      expect(state.isLoadingPromoCodes, isFalse);
    });

    test('opening another customer drops the previous list', () async {
      final remote = _FakeRemote();
      final bloc = await _blocWith(remote);
      bloc.add(const PosAccountPromoCodesRequested());
      await bloc.stream.firstWhere((s) => s.customerPromoCodes != null);

      bloc.add(
        PosAccountCustomerSelected(
          Customer(
            id: 8,
            phoneNumber: '+998901119999',
            firstName: 'Other',
            lastName: null,
            balance: 0,
            children: const [],
          ),
        ),
      );
      final state = await bloc.stream.firstWhere(
        (s) => s.selectedCustomer?.id == 8,
      );

      expect(state.customerPromoCodes, isNull);
    });

    test(
      'picked verifies by id for the open customer and holds the code',
      () async {
        final remote = _FakeRemote();
        final bloc = await _blocWith(remote);

        bloc.add(const PosAccountPromoCodePicked(_codeId));
        final state = await bloc.stream.firstWhere((s) => s.promo != null);

        expect(remote.verified, [_ref]);
        expect(remote.verifiedFor, [7]);
        expect(state.promo?.code, _ref);
        expect(state.isCheckingPromo, isFalse);
      },
    );

    test(
      'a refused pick shows the reason and reloads the list next time',
      () async {
        final remote = _FakeRemote()
          ..verifyError = ServerException(
            message: 'used',
            statusCode: 409,
            code: 'PROMO_CODE_ALREADY_USED',
          );
        final bloc = await _blocWith(remote);
        bloc.add(const PosAccountPromoCodesRequested());
        await bloc.stream.firstWhere((s) => s.customerPromoCodes != null);

        bloc.add(const PosAccountPromoCodePicked(_codeId));
        final state = await bloc.stream.firstWhere(
          (s) => s.promoErrorCode != null,
        );

        expect(state.promoErrorCode, 'PROMO_CODE_ALREADY_USED');
        expect(state.promo, isNull);
        // …and the list is re-fetched so a code used elsewhere disappears.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(remote.listCalls, greaterThanOrEqualTo(2));
      },
    );

    test('opening a customer preloads the codes (for the count)', () async {
      final remote = _FakeRemote();
      final bloc = await _blocWith(remote);

      final state = await bloc.stream.firstWhere(
        (s) => s.customerPromoCodes != null,
      );

      expect(state.customerPromoCodes, [_listed]);
    });

    test(
      'a reload keeps the list on screen and survives a failed refresh',
      () async {
        final remote = _FakeRemote();
        final bloc = await _blocWith(remote);
        await bloc.stream.firstWhere((s) => s.customerPromoCodes != null);

        remote.listError = ServerException(message: 'down', statusCode: 500);
        final seen = <PosAccountState>[];
        final sub = bloc.stream.listen(seen.add);
        bloc.add(const PosAccountPromoCodesRequested());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();

        expect(seen.every((s) => s.customerPromoCodes != null), isTrue);
        expect(bloc.state.customerPromoCodes, [_listed]);
        expect(bloc.state.promoCodesFailed, isFalse);
      },
    );

    test('nothing is requested or picked with no customer open', () async {
      final remote = _FakeRemote();
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(const PosAccountPromoCodesRequested())
        ..add(const PosAccountPromoCodePicked(_codeId));
      await Future<void>.delayed(Duration.zero);

      expect(remote.listCalls, 0);
      expect(remote.verified, isEmpty);
    });
  });

  group('PromoCodeField', () {
    testWidgets('empty → "Faol promokodlar"; typed → "Tekshirish"', (
      tester,
    ) async {
      var picked = 0;
      final submitted = <String>[];
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: PromoCodeField(
              onSubmit: submitted.add,
              onPick: () => picked++,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('promo-code-pick')), findsOneWidget);
      expect(find.byKey(const ValueKey('promo-code-check')), findsNothing);
      expect(find.text('Faol promokodlar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('promo-code-pick')));
      expect(picked, 1);

      await tester.enterText(
        find.byKey(const ValueKey('promo-code-input')),
        'ali20',
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('promo-code-pick')), findsNothing);
      expect(find.text('Tekshirish'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('promo-code-check')));
      await tester.pump();
      expect(submitted, ['ali20']);
      // Submitted → cleared → back to the list button.
      expect(find.byKey(const ValueKey('promo-code-pick')), findsOneWidget);
    });

    testWidgets('no list button without a customer to list for', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(Scaffold(body: PromoCodeField(onSubmit: (_) {}))),
      );
      expect(find.byKey(const ValueKey('promo-code-pick')), findsNothing);
      expect(find.byKey(const ValueKey('promo-code-check')), findsNothing);
    });
  });

  group('panel', () {
    Future<void> pumpPanel(WidgetTester tester, _FakeRemote remote) async {
      tester.view.physicalSize = const Size(1600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bloc = PosAccountBloc(PosAccountRepository(remote))
        ..add(const PosAccountPlansRequested())
        ..add(
          PosAccountCustomerSelected(
            _customer(
              children: [
                Child(
                  id: 'child-1',
                  firstName: 'Aziza',
                  lastName: null,
                  birthDate: DateTime(2018, 1, 1),
                ),
              ],
            ),
          ),
        );
      addTearDown(bloc.close);
      await tester.pumpWidget(
        _app(
          BlocProvider.value(
            value: bloc,
            child: const Scaffold(
              body: SingleChildScrollView(child: CustomerDetailPanel()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'pick a listed code → discount applied → checkout sends its id',
      (tester) async {
        final remote = _FakeRemote();
        await pumpPanel(tester, remote);

        await tester.tap(find.byKey(const ValueKey('child-select')));
        await tester.pump();
        await tester.tap(find.text('VIP'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('promo-code-pick')));
        await tester.pumpAndSettle();

        // The row: issuer · tier, value, expiry, and the WHOLE code to read
        // against the customer's SMS.
        expect(find.text('Fonus · Premium'), findsOneWidget);
        expect(find.text('PFTENPT'), findsOneWidget);
        expect(find.text('···PT'), findsNothing);
        expect(find.textContaining('05.12.2026'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('promo-code-tile-$_codeId')),
        );
        await tester.pumpAndSettle();

        expect(remote.verified, [_ref]);
        expect(find.text('Fonus · Premium · −30%'), findsWidgets);

        await tester.tap(find.text('To‘lov va chop etish'));
        await tester.pumpAndSettle();

        expect(remote.lastPromoCode, (code: _ref, childId: 'child-1'));
      },
    );

    testWidgets('a code issued before the full code was kept shows its tail', (
      tester,
    ) async {
      final remote = _FakeRemote()
        ..listed = [
          CustomerPromoCode(
            codeId: _codeId,
            partnerName: 'Fonus',
            tierName: 'Premium',
            discount: _discount,
            expiresAt: DateTime(2026, 12, 5, 23, 59),
            codeLast4: 'PT',
          ),
        ];
      await pumpPanel(tester, remote);

      await tester.tap(find.byKey(const ValueKey('promo-code-pick')));
      await tester.pumpAndSettle();

      expect(find.text('···PT'), findsOneWidget);
    });

    testWidgets('a customer with no active codes sees an explanation', (
      tester,
    ) async {
      final remote = _FakeRemote()..listed = const [];
      await pumpPanel(tester, remote);

      await tester.tap(find.byKey(const ValueKey('promo-code-pick')));
      await tester.pumpAndSettle();

      expect(find.text('Faol promokod yo‘q'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('promo-code-tile-$_codeId')),
        findsNothing,
      );
    });

    testWidgets('a failed load offers a retry', (tester) async {
      final remote = _FakeRemote()
        ..listError = ServerException(message: 'down', statusCode: 500);
      await pumpPanel(tester, remote);

      await tester.tap(find.byKey(const ValueKey('promo-code-pick')));
      await tester.pumpAndSettle();
      expect(find.text('Promokodlar yuklanmadi'), findsOneWidget);

      remote.listError = null;
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('promo-code-tile-$_codeId')),
        findsOneWidget,
      );
    });
  });
}
