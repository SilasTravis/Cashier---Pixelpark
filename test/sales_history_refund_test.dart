import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/features/offline/data/offline_store.dart';
import 'package:cashier_app/features/products/data/products_remote_data_source.dart';
import 'package:cashier_app/features/products/data/products_repository_impl.dart';
import 'package:cashier_app/features/products/domain/product.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_remote_data_source.dart';
import 'package:cashier_app/features/sales_history/data/sales_history_repository.dart';
import 'package:cashier_app/features/sales_history/domain/sale_edit_plan.dart';
import 'package:cashier_app/features/sales_history/domain/sale_history.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/sales_history/presentation/bloc/sales_history_bloc.dart';
import 'package:cashier_app/features/sales_history/presentation/widgets/edit_sale_dialog.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

SaleHistoryEntry _sale({
  int refundedUzs = 0,
  int netUzs = 100000,
  int refundableUzs = 100000,
}) => SaleHistoryEntry(
  id: 'sale-1',
  type: 'GOODS_CHECKOUT',
  totalUzs: 100000,
  cashUzs: 100000,
  cardUzs: 0,
  balanceUzs: 0,
  refundedUzs: refundedUzs,
  refundedCashUzs: refundedUzs,
  refundedCardUzs: 0,
  refundedBalanceUzs: 0,
  netUzs: netUzs,
  refundableUzs: refundableUzs,
  refundableCashUzs: refundableUzs,
  refundableCardUzs: 0,
  refundableBalanceUzs: 0,
  canRefund: refundableUzs > 0,
  canCorrectPayment: true,
  createdAt: DateTime(2026, 8, 31, 10),
  items: const [],
  refunds: const [],
  passes: const [],
  paymentCorrections: const [],
);

class _FakeSalesRemote extends SalesHistoryRemoteDataSource {
  _FakeSalesRemote() : super(Dio());

  SaleRefundMethod? lastMethod;
  List<String> lastGatePassIds = const [];
  SalePaymentMoveMethod? lastFrom;
  SalePaymentMoveMethod? lastTo;
  final calls = <String>[];

  @override
  Future<SalesHistoryPageData> list({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
    required int page,
    int limit = 100,
  }) async => SalesHistoryPageData(items: [_sale()], total: 1);

  @override
  Future<SalesHistorySummary> summary({
    SaleHistoryPeriod? period,
    DateTime? from,
    DateTime? to,
    String? productId,
  }) async => const SalesHistorySummary(
    count: 1,
    totalUzs: 100000,
    cashUzs: 100000,
    cardUzs: 0,
    balanceUzs: 0,
    refundedUzs: 0,
  );

  @override
  Future<SaleHistoryEntry> correctPayment({
    required String saleId,
    required SalePaymentMoveMethod fromMethod,
    required SalePaymentMoveMethod toMethod,
    required int amountUzs,
    required String reason,
    required String requestId,
  }) async {
    lastFrom = fromMethod;
    lastTo = toMethod;
    calls.add('correct:$amountUzs');
    return _sale();
  }

  @override
  Future<SaleHistoryEntry> refund({
    required String saleId,
    required int amountUzs,
    required SaleRefundMethod method,
    required String reason,
    required String requestId,
    List<String> gatePassIds = const [],
  }) async {
    lastMethod = method;
    lastGatePassIds = gatePassIds;
    calls.add('refund:$amountUzs');
    return _sale(
      refundedUzs: amountUzs,
      netUzs: 100000 - amountUzs,
      refundableUzs: 100000 - amountUzs,
    );
  }
}

class _FakeProductsRemote implements ProductsRemoteDataSource {
  @override
  Future<List<Product>> listProducts() async => const [];
}

late Directory _temp;
late OfflineStore _store;
late LocalSource _local;

ProductsRepository _productsRepository() =>
    ProductsRepository(_FakeProductsRemote(), _store, _local);

void main() {
  setUp(() async {
    _temp = await Directory.systemTemp.createTemp('cashier_refund_test');
    Hive.init(_temp.path);
    final offlineBox = await Hive.openBox<dynamic>(
      '${OfflineStore.boxName}-${DateTime.now().microsecondsSinceEpoch}',
    );
    final appBox = await Hive.openBox<dynamic>(
      'app-${DateTime.now().microsecondsSinceEpoch}',
    );
    _store = OfflineStore(offlineBox);
    _local = LocalSource(appBox)
      ..setCashier(
        id: 'cashier-1',
        fullName: 'Zaira',
        username: 'zaira',
        branchId: 'branch-1',
        branchName: 'Algoritm',
      );
  });

  tearDown(() async {
    await Hive.close();
    await _temp.delete(recursive: true);
  });

  test(
    '30 000 refund updates the sale and net shift summary to 70 000',
    () async {
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(_FakeSalesRemote()),
        _productsRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );

      bloc.add(
        const SalesHistoryRefundRequested(
          saleId: 'sale-1',
          amountUzs: 30000,
          method: SaleRefundMethod.cash,
          reason: 'Mijoz mahsulotni qaytardi',
          requestId: 'request-1',
        ),
      );
      final success = await bloc.stream.firstWhere(
        (state) => state.actionStatus == SaleActionStatus.success,
      );

      expect(success.items.single.refundedUzs, 30000);
      expect(success.items.single.netUzs, 70000);
      expect(success.summary.totalUzs, 70000);
      expect(success.summary.cashUzs, 70000);
    },
  );

  test('sale exposes per-method remaining refund limits', () {
    final sale = _sale(refundedUzs: 30000, netUzs: 70000, refundableUzs: 70000);

    expect(sale.refundableFor(SaleRefundMethod.cash), 70000);
    expect(sale.refundableFor(SaleRefundMethod.card), 0);
    expect(sale.hasRefunds, isTrue);
    expect(sale.isFullyRefunded, isFalse);
  });

  test(
    'the selected entrance passes reach the server with the refund',
    () async {
      final remote = _FakeSalesRemote();
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(remote),
        _productsRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );

      bloc.add(
        const SalesHistoryRefundRequested(
          saleId: 'sale-1',
          amountUzs: 40000,
          method: SaleRefundMethod.cash,
          reason: 'Chipta ishlatilmadi',
          requestId: 'request-2',
          gatePassIds: ['pass-1', 'pass-2'],
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.actionStatus == SaleActionStatus.success,
      );

      expect(remote.lastGatePassIds, ['pass-1', 'pass-2']);
    },
  );

  test(
    'money returned to a balance never shrinks the drawer takings',
    () async {
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(_FakeSalesRemote()),
        _productsRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );

      bloc.add(
        const SalesHistoryRefundRequested(
          saleId: 'sale-1',
          amountUzs: 20000,
          method: SaleRefundMethod.balance,
          reason: 'Xato mahsulot yechilgan',
          requestId: 'request-3',
        ),
      );
      final success = await bloc.stream.firstWhere(
        (state) => state.actionStatus == SaleActionStatus.success,
      );

      expect(success.summary.cashUzs, 100000);
      expect(success.summary.cardUzs, 0);
      expect(success.summary.refundedUzs, 0);
    },
  );

  _correctionTests();
  _editTests();

  test('a top-up refund is capped by what the balance still holds', () {
    final spent = _topupSale(balance: 40000);
    final untouched = _topupSale(balance: 100000);

    expect(spent.refundCeilingFor(SaleRefundMethod.cash), 40000);
    expect(untouched.refundCeilingFor(SaleRefundMethod.cash), 100000);
  });
}

void _editTests() {
  test(
    'an edit runs the column move first, then hands back the difference',
    () async {
      final remote = _FakeSalesRemote();
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(remote),
        _productsRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );

      // The fixture is 100 000 in cash; say it should have been 70 000 on card.
      final plan = planSaleEdit(
        sale: _sale(),
        targetTotalUzs: 70000,
        targetMethod: SalePaymentMoveMethod.card,
      );
      expect(plan.correctionUzs, 100000);
      expect(plan.refundUzs, 30000);

      bloc.add(
        SalesHistoryEditRequested(
          saleId: 'sale-1',
          plan: plan,
          reason: 'Summa va usul xato kiritilgan',
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.actionStatus == SaleActionStatus.success,
      );

      expect(remote.calls, ['correct:100000', 'refund:30000']);
      expect(remote.lastFrom, SalePaymentMoveMethod.cash);
      expect(remote.lastTo, SalePaymentMoveMethod.card);
      expect(remote.lastMethod, SaleRefundMethod.card);
    },
  );

  test('a mixed edit refunds out of both columns after the move', () async {
    final remote = _FakeSalesRemote();
    final bloc = SalesHistoryBloc(
      SalesHistoryRepository(remote),
      _productsRepository(),
    );
    addTearDown(bloc.close);

    bloc.add(const SalesHistoryStarted());
    final loaded = await bloc.stream.firstWhere(
      (state) => !state.isLoading && state.items.isNotEmpty,
    );

    // The fixture is 100 000 in cash; say it was 30 000 cash + 50 000 card.
    final plan = planSaleEditSplit(
      sale: _sale(),
      targetCashUzs: 30000,
      targetCardUzs: 50000,
    );

    bloc.add(
      SalesHistoryEditRequested(
        saleId: 'sale-1',
        plan: plan,
        reason: 'Aralash to‘lov xato kiritilgan',
      ),
    );
    final done = await bloc.stream.firstWhere(
      (state) => state.actionStatus == SaleActionStatus.success,
    );

    expect(remote.calls, ['correct:50000', 'refund:20000']);
    expect(remote.lastFrom, SalePaymentMoveMethod.cash);
    expect(remote.lastTo, SalePaymentMoveMethod.card);
    expect(remote.lastMethod, SaleRefundMethod.cash);
    expect(done.summary.totalUzs, loaded.summary.totalUzs - 20000);
    expect(done.summary.cashUzs, loaded.summary.cashUzs - 70000);
    expect(done.summary.cardUzs, loaded.summary.cardUzs + 50000);
  });

  testWidgets('the edit dialog takes a cash + card split and runs it', (
    tester,
  ) async {
    final remote = _FakeSalesRemote();
    final bloc = SalesHistoryBloc(
      SalesHistoryRepository(remote),
      _productsRepository(),
    );
    addTearDown(bloc.close);
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(
          value: bloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showEditSaleDialog(context, _sale()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A cash-only receipt opens on the single-total field.
    expect(find.widgetWithText(TextFormField, 'Correct total'), findsOneWidget);

    await tester.tap(find.text('Split'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Correct total'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Cash'), '30000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Card'), '50000');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Reason for the edit'),
      'Aralash to‘lov xato kiritilgan',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('moves from cash to card'), findsOneWidget);
    expect(
      find.textContaining('handed back to the customer in cash'),
      findsOneWidget,
    );
    expect(find.textContaining('in card'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(remote.calls, ['correct:50000', 'refund:20000']);
    expect(remote.lastMethod, SaleRefundMethod.cash);
  });

  test('an amount-only edit skips the column move', () async {
    final remote = _FakeSalesRemote();
    final bloc = SalesHistoryBloc(
      SalesHistoryRepository(remote),
      _productsRepository(),
    );
    addTearDown(bloc.close);

    bloc.add(const SalesHistoryStarted());
    await bloc.stream.firstWhere(
      (state) => !state.isLoading && state.items.isNotEmpty,
    );

    final plan = planSaleEdit(
      sale: _sale(),
      targetTotalUzs: 60000,
      targetMethod: SalePaymentMoveMethod.cash,
    );

    bloc.add(
      SalesHistoryEditRequested(
        saleId: 'sale-1',
        plan: plan,
        reason: 'Summa xato kiritilgan',
      ),
    );
    final done = await bloc.stream.firstWhere(
      (state) => state.actionStatus == SaleActionStatus.success,
    );

    expect(remote.calls, ['refund:40000']);
    expect(done.summary.totalUzs, 60000);
    expect(done.summary.refundedUzs, 40000);
  });
}

void _correctionTests() {
  test(
    'a mis-rung method moves the takings between columns, total unchanged',
    () async {
      final bloc = SalesHistoryBloc(
        SalesHistoryRepository(_FakeSalesRemote()),
        _productsRepository(),
      );
      addTearDown(bloc.close);

      bloc.add(const SalesHistoryStarted());
      final loaded = await bloc.stream.firstWhere(
        (state) => !state.isLoading && state.items.isNotEmpty,
      );
      final totalBefore = loaded.summary.totalUzs;

      bloc.add(
        const SalesHistoryPaymentCorrectionRequested(
          saleId: 'sale-1',
          fromMethod: SalePaymentMoveMethod.card,
          toMethod: SalePaymentMoveMethod.cash,
          amountUzs: 30000,
          reason: 'Naqd olingan, karta deb belgilangan',
          requestId: 'request-4',
        ),
      );
      final done = await bloc.stream.firstWhere(
        (state) => state.actionStatus == SaleActionStatus.success,
      );

      // 100 000 cash / 0 card to start, so 30 000 moved onto cash and off card.
      expect(done.summary.cashUzs, 130000);
      expect(done.summary.cardUzs, -30000);
      expect(done.summary.totalUzs, totalBefore);
      expect(done.summary.refundedUzs, 0);
    },
  );

  test('the chosen direction reaches the server', () async {
    final remote = _FakeSalesRemote();
    final bloc = SalesHistoryBloc(
      SalesHistoryRepository(remote),
      _productsRepository(),
    );
    addTearDown(bloc.close);

    bloc.add(const SalesHistoryStarted());
    await bloc.stream.firstWhere(
      (state) => !state.isLoading && state.items.isNotEmpty,
    );

    bloc.add(
      const SalesHistoryPaymentCorrectionRequested(
        saleId: 'sale-1',
        fromMethod: SalePaymentMoveMethod.cash,
        toMethod: SalePaymentMoveMethod.card,
        amountUzs: 10000,
        reason: 'Karta bilan tolangan',
        requestId: 'request-5',
      ),
    );
    await bloc.stream.firstWhere(
      (state) => state.actionStatus == SaleActionStatus.success,
    );

    expect(remote.lastFrom, SalePaymentMoveMethod.cash);
    expect(remote.lastTo, SalePaymentMoveMethod.card);
  });

  test('sale reports what each column still holds', () {
    final sale = _sale();

    expect(sale.movableFor(SalePaymentMoveMethod.cash), 100000);
    expect(sale.movableFor(SalePaymentMoveMethod.card), 0);
    expect(sale.hasPaymentCorrections, isFalse);
  });
}

SaleHistoryEntry _topupSale({required int balance}) => SaleHistoryEntry(
  id: 'topup-1',
  type: 'ACCOUNT_TOPUP',
  totalUzs: 100000,
  cashUzs: 100000,
  cardUzs: 0,
  balanceUzs: 0,
  refundedUzs: 0,
  refundedCashUzs: 0,
  refundedCardUzs: 0,
  refundedBalanceUzs: 0,
  netUzs: 100000,
  refundableUzs: 100000,
  refundableCashUzs: 100000,
  refundableCardUzs: 0,
  refundableBalanceUzs: 0,
  canRefund: true,
  canCorrectPayment: true,
  createdAt: DateTime(2026, 8, 31, 10),
  items: const [],
  refunds: const [],
  passes: const [],
  paymentCorrections: const [],
  customer: Customer(
    id: 42,
    phoneNumber: '+998900000000',
    firstName: 'Ota',
    lastName: 'Ona',
    balance: balance,
    children: const [],
  ),
);
