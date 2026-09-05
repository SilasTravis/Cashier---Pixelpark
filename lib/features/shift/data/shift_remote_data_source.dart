import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/shift.dart';

abstract class ShiftRemoteDataSource {
  Future<Shift> openShift({int? openingCashUzs});
  Future<Shift> closeShift({String? closingNote});
  Future<Shift> getCurrentShift();
}

class ShiftRemoteDataSourceImpl implements ShiftRemoteDataSource {
  ShiftRemoteDataSourceImpl(this.dio);

  final Dio dio;

  @override
  Future<Shift> openShift({int? openingCashUzs}) => _request(
    () => dio.post(
      '/v1/pos/shifts/open',
      data: {'openingCashUzs': ?openingCashUzs},
    ),
  );

  @override
  Future<Shift> closeShift({String? closingNote}) => _request(
    () => dio.post('/v1/pos/shifts/close', data: {'closingNote': ?closingNote}),
  );

  @override
  Future<Shift> getCurrentShift() =>
      _request(() => dio.get('/v1/pos/shifts/current'));

  Future<Shift> _request(Future<Response> Function() call) async {
    try {
      final response = await call();
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _shiftFromJson(response.data as Map<String, dynamic>);
      }
      throw ServerException.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException.fromJson(e.response?.data);
    } on FormatException {
      throw ServerException(message: "Server javobini o'qib bo'lmadi");
    }
  }

  Shift _shiftFromJson(Map<String, dynamic> json) {
    final totals = json['totals'] as Map<String, dynamic>;
    return Shift(
      id: json['id'] as String,
      openedAt: DateTime.parse(json['openedAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      status: json['status'] as String,
      totals: ShiftTotals(
        salesCount: totals['salesCount'] as int,
        subtotalUzs: totals['subtotalUzs'] as int,
        cashUzs: totals['cashUzs'] as int,
        cardUzs: totals['cardUzs'] as int,
        topupUzs: totals['topupUzs'] as int,
        balanceSalesUzs: (totals['balanceSalesUzs'] as int?) ?? 0,
        refundedUzs: (totals['refundedUzs'] as int?) ?? 0,
      ),
    );
  }
}
