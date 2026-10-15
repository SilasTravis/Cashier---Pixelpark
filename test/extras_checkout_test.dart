import 'dart:convert';

import 'package:dio/dio.dart';
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
import 'package:cashier_app/features/pos_sale/domain/discount.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/generated/l10n.dart';

const _nanny = Product(
  id: 'nanny',
  name: 'Enaga',
  priceUzs: 50000,
  category: 'Xizmat',
  icon: 'ph-baby',
  showInExtras: true,
);
const _popcorn = Product(
  id: 'popcorn',
  name: 'Popkorn',
  priceUzs: 25000,
  category: 'Snack',
  icon: 'ph-popcorn',
);

/// Canned-response Dio adapter that records the last request.
class _FakeAdapter implements HttpClientAdapter {
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
      jsonEncode({'entries': [], 'failures': [], 'conflicts': []}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

typedef _Checkout = ({
  String? planKey,
  List<String> childIds,
  List<CheckoutLine> products,
  int cash,
  int card,
});

class _FakeRemote implements PosAccountRemoteDataSource {
  final checkouts = <_Checkout>[];

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
  Future<List<Product>> listProducts() async => const [_nanny, _popcorn];

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<List<Discount>> fetchDiscounts({
    DiscountScope scope = DiscountScope.goods,
  }) async => const [];

  @override
  Future<PosEntryResult> planEntryCheckout({
    required int customerId,
    required String? planKey,
    required List<String> childIds,
    required List<CheckoutLine> products,
    required int cashUzs,
    required int cardUzs,
    Map<String, String> entryDiscounts = const {},
    int companions = 0,
    String? discountId,
    ({String code, String childId})? promoCode,
    String? checkDiscountId,
    bool replacePlan = false,
  }) async {
    checkouts.add((
      planKey: planKey,
      childIds: childIds,
      products: products,
      cash: cashUzs,
      card: cardUzs,
    ));
    return const PosEntryResult(entries: [], failures: []);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpPanel(WidgetTester tester, _FakeRemote remote) async {
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final bloc = PosAccountBloc(PosAccountRepository(remote))
    ..add(const PosAccountPlansRequested())
    ..add(const PosAccountProductsRequested())
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Dil',
          lastName: null,
          balance: 200000,
          children: [
            Child(
              id: 'k1',
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
  test('Product.showInExtras defaults to false for older backends/caches', () {
    final legacy = _popcorn.toJson()..remove('showInExtras');
    expect(Product.fromJson(legacy).showInExtras, isFalse);
    expect(Product.fromJson(_nanny.toJson()), _nanny);
  });

  test('a no-child checkout sends no planKey and no children', () async {
    final adapter = _FakeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter;
    await PosAccountRemoteDataSourceImpl(dio).planEntryCheckout(
      customerId: 7,
      planKey: null,
      childIds: const [],
      products: const [(productId: 'nanny', qty: 2)],
      cashUzs: 0,
      cardUzs: 0,
    );
    final body = adapter.lastRequest!.data as Map<String, dynamic>;
    expect(body.containsKey('planKey'), isFalse);
    expect(body['childIds'], isEmpty);
    expect(body['products'], [
      {'productId': 'nanny', 'qty': 2},
    ]);
  });

  group('panel', () {
    testWidgets('only flagged products show in "Qo\'shimcha"', (tester) async {
      await _pumpPanel(tester, _FakeRemote());
      expect(find.byKey(const ValueKey('extra-nanny')), findsOneWidget);
      expect(find.byKey(const ValueKey('extra-popcorn')), findsNothing);
    });

    testWidgets('nothing picked → the pay button stays off', (tester) async {
      await _pumpPanel(tester, _FakeRemote());
      final buttons = tester.widgetList<FilledButton>(
        find.byType(FilledButton),
      );
      expect(buttons.every((b) => b.onPressed == null), isTrue);
    });

    testWidgets('a product alone checks out with no child, from the balance', (
      tester,
    ) async {
      final remote = _FakeRemote();
      await _pumpPanel(tester, remote);

      final tile = find.byKey(const ValueKey('extra-nanny'));
      // The stepper's last button is "+".
      final plus = find
          .descendant(of: tile, matching: find.byType(InkWell))
          .last;
      await tester.ensureVisible(tile);
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pumpAndSettle();

      // The check names the line instead of one "Mahsulotlar" sum.
      expect(find.text('Enaga ×2'), findsOneWidget);

      final pay = find.widgetWithText(FilledButton, 'To‘lov va chop etish');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();

      expect(remote.checkouts, hasLength(1));
      final sent = remote.checkouts.single;
      expect(sent.planKey, isNull);
      expect(sent.childIds, isEmpty);
      expect(sent.products.map((l) => '${l.productId}×${l.qty}'), ['nanny×2']);
      // 100 000 is covered by the 200 000 balance → nothing collected.
      expect(sent.cash + sent.card, 0);
    });
  });
}
