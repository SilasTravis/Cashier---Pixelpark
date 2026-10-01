import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_app/features/market/data/market_repository.dart';
import 'package:cashier_app/features/market/presentation/bloc/market_status_cubit.dart';

/// Answers GET /v1/pos/market/status with [body], or fails with [status].
class _Adapter implements HttpClientAdapter {
  _Adapter({this.body, this.status = 200});
  final String? body;
  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body ?? '{}',
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

MarketRepository _repo(String? body, {int status = 200}) => MarketRepository(
  Dio()..httpClientAdapter = _Adapter(body: body, status: status),
);

void main() {
  test(
    'shows the tab and the open-parcel count when the server says so',
    () async {
      final cubit = MarketStatusCubit(
        _repo('{"enabled":false,"openOrders":2,"showTab":true}'),
      );
      await cubit.refresh();
      expect(cubit.state.showTab, isTrue);
      expect(cubit.state.openOrders, 2);
      await cubit.close();
    },
  );

  test('stays hidden while the market is off', () async {
    final cubit = MarketStatusCubit(
      _repo('{"enabled":false,"openOrders":0,"showTab":false}'),
    );
    await cubit.refresh();
    expect(cubit.state.showTab, isFalse);
    await cubit.close();
  });

  test('a backend without the market (404) hides the tab', () async {
    final cubit = MarketStatusCubit(_repo('{"statusCode":404}', status: 404));
    await cubit.refresh();
    expect(cubit.state.showTab, isFalse);
    await cubit.close();
  });
}
