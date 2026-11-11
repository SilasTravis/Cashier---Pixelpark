import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/lan_bridge/terminal_token_issuer.dart';
import 'package:cashier_app/core/network/connectivity_interceptor.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter({this.statusCode = 201, this.body = '{"terminalToken":"lbt_x"}'});

  final int statusCode;
  final String body;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  _Harness(this.adapter) {
    api.httpClientAdapter = adapter;
  }

  final _Adapter adapter;
  final Dio api = Dio(BaseOptions(baseUrl: 'https://api.example.test/api'));
  final sessions = StreamController<void>.broadcast();
  bool hasSession = true;
  String? saved;

  late final TerminalTokenIssuer issuer = TerminalTokenIssuer(
    api: api,
    hasSession: () => hasSession,
    sessionChanges: sessions.stream,
    terminalId: () => '0b4f7c52-8c7e-4d0e-9a55-3f7b1e2d9c10',
    saveToken: (t) async => saved = t,
  );
}

void main() {
  test('issues on start when a session exists and stores the token', () {
    fakeAsync((async) {
      final h = _Harness(_Adapter());
      h.issuer.start();
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));
      expect(h.adapter.requests.single.path, TerminalTokenIssuer.path);
      expect(jsonDecode(jsonEncode(h.adapter.requests.single.data)), {
        'terminalId': '0b4f7c52-8c7e-4d0e-9a55-3f7b1e2d9c10',
      });
      expect(h.saved, 'lbt_x');
      h.issuer.dispose();
    });
  });

  test('does nothing without a session, then issues when it appears', () {
    fakeAsync((async) {
      final h = _Harness(_Adapter())..hasSession = false;
      h.issuer.start();
      async.elapse(Duration.zero);
      expect(h.adapter.requests, isEmpty);

      h.hasSession = true;
      h.sessions.add(null);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));
      expect(h.saved, 'lbt_x');

      // Still signed in: a token refresh must not re-mint.
      h.sessions.add(null);
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));
      h.issuer.dispose();
    });
  });

  test('swallows a 500 and keeps the old token', () {
    fakeAsync((async) {
      final h = _Harness(_Adapter(statusCode: 500, body: '{}'));
      h.saved = 'lbt_old';
      h.issuer.start();
      async.elapse(Duration.zero);
      expect(h.adapter.requests, hasLength(1));
      expect(h.saved, 'lbt_old');
      h.issuer.dispose();
    });
  });

  test('malformed 2xx body does not save', () {
    fakeAsync((async) {
      final h = _Harness(_Adapter(body: '{"terminalToken":""}'));
      h.saved = 'lbt_old';
      h.issuer.start();
      async.elapse(Duration.zero);
      expect(h.saved, 'lbt_old');
      h.issuer.dispose();
    });
  });

  test('request is marked background', () {
    fakeAsync((async) {
      final h = _Harness(_Adapter());
      h.issuer.start();
      async.elapse(Duration.zero);
      expect(
        h.adapter.requests.single.extra[ConnectivityInterceptor.backgroundKey],
        true,
      );
      h.issuer.dispose();
    });
  });
}
