import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/birthday_party.dart';
import '../domain/birthday_plan.dart';

class BirthdayPartiesRepository {
  BirthdayPartiesRepository(this.dio);
  final Dio dio;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  BirthdayParty _party(Response<dynamic> response) =>
      BirthdayParty.fromJson(Map<String, dynamic>.from(response.data as Map));

  Future<List<BirthdayPlan>> plans() => _guard(() async {
    final response = await dio.get('/v1/pos/birthday-plans');
    return (response.data as List)
        .map((e) => BirthdayPlan.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  });

  Future<BirthdayParty> sell({
    required int customerId,
    required String planId,
    required int childCount,
    required int extraChildren,
    required String partyDate,
    required int agreedPriceUzs,
    required BirthdayMoney money,
    required String requestId,
  }) => _guard(
    () async => _party(
      await dio.post(
        '/v1/pos/customers/$customerId/birthday-parties',
        data: {
          'planId': planId,
          'childCount': childCount,
          'extraChildren': extraChildren,
          'partyDate': partyDate,
          'agreedPriceUzs': agreedPriceUzs,
          'fromBalanceUzs': money.fromBalanceUzs,
          'cashUzs': money.cashUzs,
          'cardUzs': money.cardUzs,
          'requestId': requestId,
        },
      ),
    ),
  );

  Future<List<BirthdayParty>> list(BirthdayPartyStatus status) =>
      _guard(() async {
        final response = await dio.get(
          '/v1/pos/birthday-parties',
          queryParameters: {'status': status.name},
        );
        return (response.data as List)
            .map(
              (e) =>
                  BirthdayParty.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      });

  Future<BirthdayParty> get(String id) =>
      _guard(() async => _party(await dio.get('/v1/pos/birthday-parties/$id')));

  Future<BirthdayParty> pay(String id, BirthdayMoney money, String requestId) =>
      _guard(
        () async => _party(
          await dio.post(
            '/v1/pos/birthday-parties/$id/payments',
            data: {
              'fromBalanceUzs': money.fromBalanceUzs,
              'cashUzs': money.cashUzs,
              'cardUzs': money.cardUzs,
              'requestId': requestId,
            },
          ),
        ),
      );

  /// [expectedExtraChildren] is the count the cashier saw: the server answers
  /// a repeat of the same tap with the party unchanged and a stale view with
  /// 409 BIRTHDAY_REQUEST_CONFLICT. Absent, it always adds.
  Future<BirthdayParty> addExtraChildren(
    String id,
    int count, {
    int? expectedExtraChildren,
  }) => _guard(
    () async => _party(
      await dio.post(
        '/v1/pos/birthday-parties/$id/extra-children',
        data: {'count': count, 'expectedExtraChildren': ?expectedExtraChildren},
      ),
    ),
  );

  Future<BirthdayParty> changeDate(String id, String partyDate) => _guard(
    () async => _party(
      await dio.patch(
        '/v1/pos/birthday-parties/$id/date',
        data: {'partyDate': partyDate},
      ),
    ),
  );

  /// A repeat with the same [requestId] and text adds no second comment.
  Future<BirthdayParty> addComment(
    String id,
    String text, {
    String? requestId,
  }) => _guard(
    () async => _party(
      await dio.post(
        '/v1/pos/birthday-parties/$id/comments',
        data: {'text': text, 'requestId': ?requestId},
      ),
    ),
  );

  Future<BirthdayParty> complete(String id) => _guard(
    () async => _party(await dio.post('/v1/pos/birthday-parties/$id/complete')),
  );

  Future<BirthdayParty> cancel(
    String id, {
    required String reason,
    required int refundBalanceUzs,
    required int refundCashUzs,
    required String requestId,
  }) => _guard(
    () async => _party(
      await dio.post(
        '/v1/pos/birthday-parties/$id/cancel',
        data: {
          'reason': reason,
          'refundBalanceUzs': refundBalanceUzs,
          'refundCashUzs': refundCashUzs,
          'requestId': requestId,
        },
      ),
    ),
  );
}
