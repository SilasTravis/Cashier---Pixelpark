import 'dart:io';

import 'package:cashier_app/core/connectivity/connectivity_monitor.dart';
import 'package:cashier_app/core/network/connectivity_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConnectivityMonitor', () {
    test('needs two failed polls in a row before reporting an outage', () {
      fakeAsync((async) {
        final monitor = ConnectivityMonitor(probe: () async => false);
        final events = <ConnectivityEvent>[];
        monitor.events.listen(events.add);
        monitor.start();

        async.elapse(const Duration(seconds: 15));
        expect(events, isEmpty);

        async.elapse(const Duration(seconds: 15));
        expect(events, [const ConnectivityEvent(reachable: false)]);
        monitor.stop();
      });
    });

    test(
      'a successful poll resets the failure count and reports reachable',
      () {
        fakeAsync((async) {
          final answers = [false, true, false];
          final monitor = ConnectivityMonitor(
            probe: () async => answers.removeAt(0),
          );
          final events = <ConnectivityEvent>[];
          monitor.events.listen(events.add);
          monitor.start();

          async.elapse(const Duration(seconds: 45));
          expect(events, [const ConnectivityEvent(reachable: true)]);
          monitor.stop();
        });
      },
    );

    test('a throwing probe counts as a failure', () {
      fakeAsync((async) {
        final monitor = ConnectivityMonitor(
          probe: () async => throw const SocketException('down'),
          failuresBeforeUnreachable: 1,
        );
        final events = <ConnectivityEvent>[];
        monitor.events.listen(events.add);
        monitor.start();

        async.elapse(const Duration(seconds: 15));
        expect(events.single.reachable, isFalse);
        monitor.stop();
      });
    });

    test(
      'a failed real request is reported at once, flagged as user-initiated',
      () async {
        final monitor = ConnectivityMonitor(probe: () async => true);
        final next = monitor.events.first;
        monitor.reportRequestFailure();
        expect(
          await next,
          const ConnectivityEvent(reachable: false, fromUserRequest: true),
        );
      },
    );

    test('checkNow returns the probe answer without emitting', () async {
      final monitor = ConnectivityMonitor(probe: () async => true);
      final events = <ConnectivityEvent>[];
      monitor.events.listen(events.add);

      expect(await monitor.checkNow(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
    });
  });

  group('ConnectivityInterceptor', () {
    DioException error(DioExceptionType type, {Object? cause}) => DioException(
      requestOptions: RequestOptions(path: '/v1/pos/sales'),
      type: type,
      error: cause,
    );

    test('classifies only network failures as connection errors', () {
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.connectionError),
        ),
        isTrue,
      );
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.connectionTimeout),
        ),
        isTrue,
      );
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.receiveTimeout),
        ),
        isTrue,
      );
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.unknown, cause: const SocketException('x')),
        ),
        isTrue,
      );
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.badResponse),
        ),
        isFalse,
      );
      expect(
        ConnectivityInterceptor.isConnectionError(
          error(DioExceptionType.cancel),
        ),
        isFalse,
      );
    });

    test('reports a connection error and passes every error on', () {
      var reports = 0;
      var passedOn = 0;
      final interceptor = ConnectivityInterceptor(() => reports++);
      final handler = _Handler(() => passedOn++);

      interceptor.onError(error(DioExceptionType.connectionError), handler);
      interceptor.onError(error(DioExceptionType.badResponse), handler);

      expect(reports, 1);
      expect(passedOn, 2);
    });
  });
}

/// A real handler completes a completer nobody listens to, which the test
/// runner reports as an unhandled error — so only count the hand-offs.
class _Handler extends ErrorInterceptorHandler {
  _Handler(this._onNext);

  final void Function() _onNext;

  @override
  void next(DioException err) => _onNext();
}
