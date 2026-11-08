import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/customer_results_list.dart';
import 'package:cashier_app/generated/l10n.dart';

Customer _customer(int id, String phone, String name) => Customer(
  id: id,
  phoneNumber: phone,
  firstName: name,
  lastName: null,
  balance: 0,
  children: const [],
);

/// Search returns whatever is stored — the real backend matches by
/// substring, so a full number can bring back a different, similar one.
class _FakeRemote implements PosAccountRemoteDataSource {
  _FakeRemote(this.found);

  final List<Customer> found;

  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async =>
      found;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<PosAccountBloc> _pump(
  WidgetTester tester,
  List<Customer> found,
  String digits,
) async {
  final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote(found)));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalization.delegate],
      supportedLocales: AppLocalization.delegate.supportedLocales,
      home: BlocProvider.value(
        value: bloc,
        child: const Scaffold(body: CustomerResultsList()),
      ),
    ),
  );
  for (final d in digits.split('')) {
    bloc.add(PosAccountDigitPressed(d));
  }
  await tester.pump(const Duration(milliseconds: 400)); // debounce
  await tester.pumpAndSettle();
  return bloc;
}

void main() {
  testWidgets(
    'a full number with only look-alike matches still offers "add customer"',
    (tester) async {
      // Real case: typed +998 99 890 99 00, got Nargiza +998 90 990 07 78.
      await _pump(tester, [
        _customer(1, '+998909900778', 'Nargiza'),
      ], '998909900');

      expect(find.byIcon(PhosphorIconsRegular.userPlus), findsOneWidget);
      expect(find.text('Nargiza'), findsOneWidget, reason: 'kept below');
    },
  );

  testWidgets('an exact match shows only the result list', (tester) async {
    await _pump(tester, [
      _customer(2, '+998998909900', 'Ali'),
      _customer(1, '+998909900778', 'Nargiza'),
    ], '998909900');

    expect(find.byIcon(PhosphorIconsRegular.userPlus), findsNothing);
    expect(find.text('Ali'), findsOneWidget);
  });

  testWidgets('a partial number never offers "add customer"', (tester) async {
    await _pump(tester, [_customer(1, '+998909900778', 'Nargiza')], '9099007');

    expect(find.byIcon(PhosphorIconsRegular.userPlus), findsNothing);
  });
}
