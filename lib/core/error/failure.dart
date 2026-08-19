import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  @override
  bool get stringify => true;
}

/// A rejection from the backend — `message` is already the Uzbek string
/// extracted from the API's `{en,ru,uz}` envelope.
class ServerFailure extends Failure {
  ServerFailure({required this.message, this.code, this.statusCode});

  final String message;

  /// Machine-readable error code (e.g. `SHIFT_NOT_OPEN`), when present.
  final String? code;
  final int? statusCode;

  @override
  List<Object?> get props => [message, code, statusCode];
}

class NoInternetFailure extends Failure {
  @override
  List<Object?> get props => [];
}

class CacheFailure extends Failure {
  CacheFailure({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
