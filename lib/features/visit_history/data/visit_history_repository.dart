import 'package:dio/dio.dart';

import '../../../core/error/exceptions.dart';
import '../domain/shift_visit.dart';

class VisitHistoryRepository {
  VisitHistoryRepository(this.dio);
  final Dio dio;

  Future<ShiftVisitPage> list({
    required int page,
    required int limit,
    required String status,
    String? search,
  }) async {
    try {
      final response = await dio.get(
        '/v1/pos/visits/history',
        queryParameters: {
          'page': page,
          'limit': limit,
          'status': status,
          if (search != null && search.trim().isNotEmpty)
            'search': search.trim(),
        },
      );
      final json = Map<String, dynamic>.from(response.data as Map);
      final summary = Map<String, dynamic>.from(json['summary'] as Map);
      return ShiftVisitPage(
        items: (json['items'] as List).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return ShiftVisit(
            id: item['id'] as String,
            childName: item['childName'] as String,
            parentName: item['parentName'] as String,
            parentPhone: item['parentPhone'] as String,
            enteredAt: DateTime.parse(item['enteredAt'] as String).toLocal(),
            exitedAt: item['exitedAt'] == null
                ? null
                : DateTime.parse(item['exitedAt'] as String).toLocal(),
            minutes: item['minutes'] as int?,
            amountUzs: item['amountUzs'] as int,
            forceClosed: item['forceClosed'] as bool,
          );
        }).toList(),
        total: json['total'] as int,
        entries: summary['entries'] as int,
        exits: summary['exits'] as int,
        inside: summary['inside'] as int,
      );
    } on DioException catch (error) {
      throw ServerException.fromJson(error.response?.data);
    }
  }
}
