/// Thrown by datasources on a non-2xx response. Mirrors the maestro backend's
/// error envelope: `{ statusCode, code, message: {en, ru, uz}, ... }`.
class ServerException implements Exception {
  ServerException({required this.message, this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  factory ServerException.fromJson(dynamic json) {
    if (json is! Map) {
      return ServerException(message: "Nimadir noto'g'ri ketdi");
    }
    final map = Map<String, dynamic>.from(json);
    final rawMessage = map['message'];
    String message;
    if (rawMessage is Map) {
      message =
          (rawMessage['uz'] ?? rawMessage['en'] ?? "Nimadir noto'g'ri ketdi")
              .toString();
    } else if (rawMessage is String) {
      message = rawMessage;
    } else {
      message = "Nimadir noto'g'ri ketdi";
    }
    return ServerException(
      message: message,
      code: map['code']?.toString(),
      statusCode: map['statusCode'] is int ? map['statusCode'] as int : null,
    );
  }

  @override
  String toString() => 'ServerException($code): $message';
}

class NoInternetException implements Exception {}

class CacheException implements Exception {
  CacheException({required this.message});

  final String message;

  @override
  String toString() => message;
}
