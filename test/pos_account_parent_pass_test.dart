import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/error/exceptions.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/active_pass.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/domain/parent_pass.dart';
import 'package:cashier_app/features/pos_account/domain/playing_child.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';

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
  ParentPass? parentPass;
  Object? parentPassError;
  int? lastParentPassCustomerId;

  @override
  Future<ParentPass> issueParentPass(int customerId) async {
    lastParentPassCustomerId = customerId;
    if (parentPassError != null) throw parentPassError!;
    return parentPass!;
  }

  @override
  Future<List<ActivePass>> listActivePasses(int customerId) async => const [];

  @override
  Future<List<PlayingChild>> listPlaying(int customerId) async => const [];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _pass = ParentPass(
  code: 'PARENTCODE12',
  expiresAt: DateTime.utc(2026, 8, 17, 17),
  customerName: 'Dil Karimova',
);

Customer _customer() => const Customer(
  id: 7,
  phoneNumber: '+998901234567',
  firstName: 'Dil',
  lastName: null,
  balance: 100000,
  children: [],
);

void main() {
  group('data source', () {
    test('issueParentPass POSTs and parses the sticker payload', () async {
      final adapter = _FakeAdapter({
        'code': 'PARENTCODE12',
        'expiresAt': '2026-08-17T17:00:00.000Z',
        'customerName': 'Dil Karimova',
      });
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = adapter;
      final source = PosAccountRemoteDataSourceImpl(dio);

      final pass = await source.issueParentPass(7);

      expect(pass.code, 'PARENTCODE12');
      expect(pass.customerName, 'Dil Karimova');
      expect(
        pass.expiresAt,
        DateTime.parse('2026-08-17T17:00:00.000Z').toLocal(),
      );
      expect(adapter.lastRequest!.path, '/v1/pos/customers/7/parent-pass');
      expect(adapter.lastRequest!.method, 'POST');
    });
  });

  group('bloc', () {
    test('a parent QR request lands the pass in lastParentPass', () async {
      final remote = _FakeRemote()..parentPass = _pass;
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(PosAccountCustomerSelected(_customer()))
        ..add(const PosAccountParentQrRequested());
      await bloc.stream.firstWhere((s) => s.lastParentPass != null);

      expect(bloc.state.lastParentPass, _pass);
      expect(bloc.state.isBusy, false);
      expect(remote.lastParentPassCustomerId, 7);
    });

    test('acknowledging clears lastParentPass', () async {
      final remote = _FakeRemote()..parentPass = _pass;
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(PosAccountCustomerSelected(_customer()))
        ..add(const PosAccountParentQrRequested());
      await bloc.stream.firstWhere((s) => s.lastParentPass != null);
      bloc.add(const PosAccountParentQrAcknowledged());
      await bloc.stream.firstWhere((s) => s.lastParentPass == null);

      expect(bloc.state.lastParentPass, isNull);
    });

    test('a server failure surfaces as errorMessage, no pass', () async {
      final remote = _FakeRemote()
        ..parentPassError = ServerException(message: 'Smena ochilmagan');
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      addTearDown(bloc.close);

      bloc
        ..add(PosAccountCustomerSelected(_customer()))
        ..add(const PosAccountParentQrRequested());
      await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(bloc.state.lastParentPass, isNull);
      expect(bloc.state.isBusy, false);
    });
  });
}
