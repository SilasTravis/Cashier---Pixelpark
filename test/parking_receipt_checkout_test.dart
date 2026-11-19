import 'dart:async';
import 'dart:io';

import 'package:cashier_app/core/local_source/local_source.dart';
import 'package:cashier_app/core/printing/parking_receipt_dispatcher.dart';
import 'package:cashier_app/features/auth/data/models/cashier_model.dart';
import 'package:cashier_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:cashier_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/router/app_navigator.dart';
import 'package:cashier_app/core/printing/parking_receipt_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  late LocalSource local;
  late ParkingReceiptDispatcher parking;
  late List<String> jobs;
  late Completer<void> spooler;

  void login(String name, Map<String, dynamic> flags) {
    final branch = BranchModel.fromJson({
      'id': name,
      'name': name,
      'slug': name,
      ...flags,
    });
    local.setCashier(
      id: 'cashier',
      fullName: 'Operator',
      username: 'user',
      branchId: branch.id,
      branchName: branch.name,
      printParkingReceipt: branch.printParkingReceipt,
    );
  }

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('parking');
    Hive.init(directory.path);
    final box = await Hive.openBox<dynamic>('settings');
    addTearDown(() async {
      await box.close();
      await directory.delete(recursive: true);
    });
    local = LocalSource(box);
    spooler = Completer<void>();
    jobs = [];
    parking = ParkingReceiptDispatcher(
      local,
      printReceipt:
          ({required branchName, required issuedAt, preferredPrinterName}) {
            jobs.add('$branchName/$preferredPrinterName');
            return spooler.future;
          },
    );
    await local.setReceiptPrinterName('Counter printer');
  });

  testWidgets(
    'printer failures show a short localized notice only while the navigator is mounted',
    (tester) async {
      await tester.runAsync(() async {
        login('A', {'printParkingReceipt': true});
        await local.box.flush();
      });
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          locale: const Locale('ru'),
          supportedLocales: AppLocalization.delegate.supportedLocales,
          localizationsDelegates: const [
            AppLocalization.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: Text('Counter')),
        ),
      );
      await tester.pumpAndSettle();
      final jobs = <Completer<void>>[];
      final dispatcher = ParkingReceiptDispatcher(
        local,
        onUnconfirmed: showParkingReceiptNotice,
        printReceipt:
            ({required branchName, required issuedAt, preferredPrinterName}) {
              final job = Completer<void>();
              jobs.add(job);
              return job.future;
            },
      );
      final print = dispatcher.captureForCheckout()!;
      print(DateTime.now());
      expect(find.byType(SnackBar), findsNothing);
      jobs.single.completeError(StateError('printer failed'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Продажа завершена. Печать парковочного талона не подтверждена.',
        ),
        findsOneWidget,
      );
      print(DateTime.now());
      await tester.pumpWidget(const SizedBox());
      jobs.last.completeError(StateError('printer timed out'));
      await tester.pumpAndSettle();
      expect(jobs, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'subscription sale prints only when its new paid subscription issues today’s admission',
    () async {
      login('A', {'printParkingReceipt': true});
      String? passSubscription;
      var price = 300000;
      var passIssued = true;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              Object data = [];
              if (options.method == 'POST' &&
                  options.path.endsWith('/subscriptions')) {
                data = {
                  'subscription': {'id': 'new', 'childId': 'one'},
                  if (passIssued)
                    'pass': {
                      'childId': 'one',
                      'token': 'PASS',
                      'subscription': passSubscription == null
                          ? null
                          : {'id': passSubscription},
                    },
                  'receipt': {
                    'priceUzs': price,
                    'balanceUzs': price,
                    'createdAt': '2026-11-19T10:00:00Z',
                  },
                };
              }
              handler.resolve(
                Response(requestOptions: options, statusCode: 200, data: data),
              );
            },
          ),
        );
      final bloc = PosAccountBloc(
        PosAccountRepository(PosAccountRemoteDataSourceImpl(dio)),
        null,
        parking,
      );
      addTearDown(bloc.close);
      final selected = bloc.stream.firstWhere(
        (s) => s.selectedCustomer != null,
      );
      bloc.add(
        const PosAccountCustomerSelected(
          Customer(
            id: 1,
            phoneNumber: '+998901234567',
            firstName: 'Aziza',
            lastName: null,
            balance: 300000,
            children: [],
          ),
        ),
      );
      await selected;
      Future<void> buy() async {
        final done = bloc.stream.firstWhere(
          (s) => !s.isBusy && s.lastSubscriptionSale != null,
        );
        bloc.add(
          PosAccountSubscriptionSellRequested(
            childId: 'one',
            subscriptionPlanId: 'vip',
            topupCashUzs: 0,
            topupCardUzs: 0,
            useToday: passIssued,
          ),
        );
        await done;
        final clear = bloc.stream.firstWhere(
          (s) => s.lastSubscriptionSale == null,
        );
        bloc.add(const PosAccountSubscriptionSaleAcknowledged());
        await clear;
      }

      await buy();
      passSubscription = 'new';
      await buy();
      expect(jobs, ['A/Counter printer']);
      passIssued = false;
      await buy();
      passIssued = true;
      price = 0;
      await buy();
      expect(jobs, hasLength(1));
      spooler.complete();
    },
  );

  test(
    'login applies its branch switch and me refreshes it; legacy login falls back to me',
    () async {
      var includeLoginBranch = true;
      var meRequests = 0;
      final branch = {'id': 'b', 'name': 'Branch', 'slug': 'branch'};
      final cashier = {
        'id': 'c',
        'fullName': 'Z',
        'username': 'z',
        'branchId': 'b',
        'active': true,
      };
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final login = options.path.endsWith('/login');
              if (!login) meRequests++;
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'cashier': cashier,
                    if (login)
                      'tokens': {
                        'accessToken': 'access',
                        'refreshToken': 'refresh',
                        'expiresIn': 60,
                      },
                    if (!login || includeLoginBranch)
                      'branch': {...branch, 'printParkingReceipt': login},
                  },
                ),
              );
            },
          ),
        );
      final auth = AuthRepositoryImpl(AuthRemoteDataSourceImpl(dio), local);
      await auth.login(username: 'z', password: 'test');
      expect(local.getPrintParkingReceipt(), isTrue);
      expect(meRequests, 0);
      await auth.getCurrentSession();
      expect(local.getPrintParkingReceipt(), isFalse);
      includeLoginBranch = false;
      await auth.login(username: 'z', password: 'test');
      expect(meRequests, 2);
      expect(local.getPrintParkingReceipt(), isFalse);
    },
  );

  test(
    'setting follows current branch and defaults off on legacy sessions',
    () async {
      login('A', {'printEntryQr': false, 'printParkingReceipt': true});
      final paidAtA = parking.captureForCheckout()!;
      login('B', {});
      expect(parking.captureForCheckout(), isNull);
      paidAtA(DateTime.now());
      expect(jobs, ['A/Counter printer']);
      await local.setPrintParkingReceipt(true);
      expect(parking.captureForCheckout(), isNotNull);
      await local.clearSession();
      expect(parking.captureForCheckout(), isNull);
      spooler.complete();
    },
  );

  test(
    'only confirmed paid admissions print, once even with multiple children and a stuck printer',
    () async {
      login('A', {'printEntryQr': false, 'printParkingReceipt': true});
      var paidAdmission = true;
      var failRequest = false;
      var checkouts = 0;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              Object data = [];
              if (options.path.endsWith('/plan-entry-checkout') ||
                  options.path.endsWith('/plan-entry')) {
                if (options.path.endsWith('/plan-entry-checkout')) checkouts++;
                if (failRequest) {
                  handler.reject(DioException(requestOptions: options));
                  return;
                }
                data = {
                  'paidAdmission': paidAdmission,
                  'entries': [
                    for (final child in ['one', 'two'])
                      {
                        'childId': child,
                        'token': child,
                        'priceUzs': 20000,
                        'expiresAt': '2026-11-19T18:00:00Z',
                      },
                  ],
                  'failures': [],
                };
              }
              handler.resolve(
                Response(requestOptions: options, data: data, statusCode: 200),
              );
            },
          ),
        );
      final bloc = PosAccountBloc(
        PosAccountRepository(PosAccountRemoteDataSourceImpl(dio)),
        null,
        parking,
      );
      addTearDown(bloc.close);
      const customer = Customer(
        id: 1,
        phoneNumber: '+998901234567',
        firstName: 'X',
        lastName: null,
        balance: 100000,
        children: [],
      );
      final selected = bloc.stream.firstWhere(
        (s) => s.selectedCustomer != null,
      );
      bloc.add(const PosAccountCustomerSelected(customer));
      await selected;
      Future<void> submit(PosAccountEvent event) async {
        final result = bloc.stream.firstWhere(
          (s) =>
              !s.isBusy &&
              (s.lastEntryResult != null || s.errorMessage != null),
        );
        bloc.add(event);
        await result;
        final cleared = bloc.stream.firstWhere(
          (s) => s.lastEntryResult == null && s.errorMessage == null,
        );
        bloc.add(const PosAccountEntryAcknowledged());
        await cleared;
      }

      const checkout = PosAccountCheckoutRequested(
        planKey: 'vip',
        childIds: ['one', 'two'],
        products: [],
        cashUzs: 0,
        cardUzs: 0,
      );
      await submit(checkout);
      expect(jobs, ['A/Counter printer']);
      paidAdmission = false;
      await submit(checkout);
      paidAdmission = true;
      await submit(
        const PosAccountPlanEntryRequested(planKey: 'vip', childIds: ['one']),
      );
      expect(jobs, hasLength(1));
      spooler.completeError(StateError('spooler unavailable'));
      await submit(checkout);
      expect(jobs, hasLength(2));
      failRequest = true;
      await submit(checkout);
      expect(checkouts, 4);
      expect(jobs, hasLength(2));
    },
  );
}
