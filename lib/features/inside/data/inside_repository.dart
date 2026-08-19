import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/inside_child.dart';

class InsideRepository {
  InsideRepository(this.dio);
  final Dio dio;

  Future<List<InsideChild>> list() async {
    try {
      final response = await dio.get('/v1/pos/inside');
      return (response.data as List).map((raw) {
        final json = Map<String, dynamic>.from(raw as Map);
        return InsideChild(
          visitId: json['visitId'] as String,
          childName: json['childName'] as String,
          parentName: json['parentName'] as String,
          parentPhone: json['parentPhone'] as String,
          enteredAt: DateTime.parse(json['enteredAt'] as String).toLocal(),
          elapsedMinutes: json['elapsedMinutes'] as int,
          accruedUzs: json['accruedUzs'] as int,
          planName: json['planName'] as String?,
        );
      }).toList();
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }

  Future<void> forceExit(String visitId) async {
    try {
      await dio.post('/v1/pos/inside/$visitId/force-exit');
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }
}
