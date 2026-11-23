import 'package:cashier_app/core/widgets/payment_method_selector.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/confirm_topup_dialog.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top-up bonus is paid only for an all-cash top-up; the confirm dialog
/// must promise exactly what the backend will credit.
void main() {
  Future<void> open(
    WidgetTester tester, {
    required int cashUzs,
    required int cardUzs,
    required PaymentMethod method,
  }) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showConfirmTopupDialog(
              context,
              customer: _customer,
              amountUzs: cashUzs + cardUzs,
              cashUzs: cashUzs,
              cardUzs: cardUzs,
              method: method,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('all-cash 500 000 shows the 200 000 bonus', (tester) async {
    await open(tester, cashUzs: 500000, cardUzs: 0, method: PaymentMethod.cash);
    expect(find.text('Bonus'), findsOneWidget);
    expect(find.textContaining('200 000'), findsOneWidget);
  });

  testWidgets('card 500 000 shows no bonus', (tester) async {
    await open(tester, cashUzs: 0, cardUzs: 500000, method: PaymentMethod.card);
    expect(find.text('Bonus'), findsNothing);
  });

  testWidgets('mixed cash+card shows no bonus', (tester) async {
    await open(
      tester,
      cashUzs: 400000,
      cardUzs: 100000,
      method: PaymentMethod.split,
    );
    expect(find.text('Bonus'), findsNothing);
  });
}

const _customer = Customer(
  id: 1,
  phoneNumber: '+998900000000',
  firstName: 'Test',
  lastName: 'Mijoz',
  balance: 100000,
  children: [],
);
