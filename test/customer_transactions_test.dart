import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/customer_transaction.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_detail_panel.dart';
import 'package:cashier_app/generated/l10n.dart';

const _total = 25;

class _FakeRemote implements PosAccountRemoteDataSource {
  final pagesAsked = <int>[];
  bool failNext = false;

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  Future<CustomerTransactionsPage> listTransactions(
    int customerId, {
    int page = 1,
    int limit = 10,
  }) async {
    pagesAsked.add(page);
    if (failNext) {
      failNext = false;
      throw NoInternetException();
    }
    final first = (page - 1) * limit;
    final count = (_total - first).clamp(0, limit);
    return CustomerTransactionsPage(
      total: _total,
      items: [
        for (var i = 0; i < count; i++)
          CustomerTransaction(
            id: first + i + 1,
            createdAt: DateTime(2026, 10, 7, 9, i),
            kind: i.isEven ? 'top_up' : 'debit',
            type: i.isEven ? 'CASHIER_TOPUP' : 'POS_PURCHASE',
            status: 'paid',
            amountUzs: 10000 * (i + 1),
            cashierName: 'Barno',
          ),
      ],
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRemote> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final remote = _FakeRemote();
  final bloc = PosAccountBloc(PosAccountRepository(remote))
    ..add(
      PosAccountCustomerSelected(
        Customer(
          id: 7,
          phoneNumber: '+998901234567',
          firstName: 'Aziza',
          lastName: null,
          balance: 100000,
          children: const [],
        ),
      ),
    );
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider.value(
        value: bloc,
        child: const Scaffold(body: CustomerDetailPanel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return remote;
}

Future<void> _openAccordion(WidgetTester tester) async {
  final header = find.text('Transaction history');
  await tester.ensureVisible(header);
  await tester.tap(header);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final button = find.widgetWithText(TextButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the history stays folded and silent until it is opened', (
    tester,
  ) async {
    final remote = await _pump(tester);

    expect(find.text('Transaction history'), findsOneWidget);
    expect(find.text('Cash-desk top-up'), findsNothing);
    expect(remote.pagesAsked, isEmpty);
  });

  testWidgets('opening loads page 1 with its rows and the total', (
    tester,
  ) async {
    final remote = await _pump(tester);

    await _openAccordion(tester);

    expect(remote.pagesAsked, [1]);
    expect(find.text('Cash-desk top-up'), findsWidgets);
    expect(find.text('Cash-desk purchase'), findsWidgets);
    expect(find.text('1–10 / 25'), findsOneWidget);
    // Top-ups add to the balance, purchases take from it.
    expect(find.text("+10 000 so'm"), findsOneWidget);
    expect(find.text("−20 000 so'm"), findsOneWidget);
  });

  testWidgets('Next / Previous page through the ledger', (tester) async {
    final remote = await _pump(tester);
    await _openAccordion(tester);

    await _tapButton(tester, 'Next');
    expect(find.text('11–20 / 25'), findsOneWidget);

    await _tapButton(tester, 'Next');
    expect(find.text('21–25 / 25'), findsOneWidget);
    // The last page has nothing after it.
    final next = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Next'),
    );
    expect(next.onPressed, isNull);

    await _tapButton(tester, 'Previous');
    expect(find.text('11–20 / 25'), findsOneWidget);
    expect(remote.pagesAsked, [1, 2, 3, 2]);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    final remote = await _pump(tester);
    remote.failNext = true;

    await _openAccordion(tester);
    expect(find.text("Couldn't load the transactions"), findsOneWidget);

    final retry = find.widgetWithText(OutlinedButton, 'Refresh');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(find.text('1–10 / 25'), findsOneWidget);
    expect(remote.pagesAsked, [1, 1]);
  });
}
