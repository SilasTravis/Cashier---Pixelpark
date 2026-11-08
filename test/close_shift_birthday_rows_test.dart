import 'package:cashier_app/core/error/failure.dart';
import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/shell/presentation/widgets/close_shift_dialog.dart';
import 'package:cashier_app/features/shift/data/shift_repository_impl.dart';
import 'package:cashier_app/features/shift/domain/shift.dart';
import 'package:cashier_app/features/shift/presentation/bloc/shift_bloc.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repo implements ShiftRepository {
  _Repo(this.shift);
  final Shift shift;

  @override
  Future<Either<Failure, Shift>> getCurrentShift() async => Right(shift);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Mode implements AppModeCubit {
  @override
  AppModeState get state => const AppModeState();

  @override
  Stream<AppModeState> get stream => const Stream.empty();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Shift _shift({int birthday = 0, int refunded = 0}) => Shift(
  id: '11111111-2222-3333-4444-555555555555',
  openedAt: DateTime.utc(2026, 11, 6, 5),
  closedAt: null,
  status: 'open',
  totals: ShiftTotals(
    salesCount: 3,
    subtotalUzs: 900000,
    cashUzs: 600000,
    cardUzs: 300000,
    topupUzs: 0,
    balanceSalesUzs: 0,
    birthdayUzs: birthday,
    birthdayRefundedUzs: refunded,
  ),
);

Future<void> _open(WidgetTester tester, Shift shift) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final bloc = ShiftBloc(_Repo(shift));
  addTearDown(bloc.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ShiftBloc>.value(value: bloc),
        BlocProvider<AppModeCubit>.value(value: _Mode()),
      ],
      child: MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalization.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showCloseShiftDialog(context, shift),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('close-out shows birthday money and the birthday refund', (
    tester,
  ) async {
    await _open(tester, _shift(birthday: 400000, refunded: 250000));
    expect(find.text('Shundan tug‘ilgan kun'), findsOneWidget);
    expect(find.text("400 000 so'm"), findsOneWidget);
    expect(find.text('Tug‘ilgan kun qaytarildi'), findsOneWidget);
    expect(find.text("−250 000 so'm"), findsOneWidget);
  });

  testWidgets('without birthday refunds the refund row is absent', (
    tester,
  ) async {
    await _open(tester, _shift(birthday: 400000));
    expect(find.text('Shundan tug‘ilgan kun'), findsOneWidget);
    expect(find.text('Tug‘ilgan kun qaytarildi'), findsNothing);
  });

  testWidgets('no birthday rows at all without birthday money', (tester) async {
    await _open(tester, _shift());
    expect(find.text('Shundan tug‘ilgan kun'), findsNothing);
    expect(find.text('Tug‘ilgan kun qaytarildi'), findsNothing);
  });
}
