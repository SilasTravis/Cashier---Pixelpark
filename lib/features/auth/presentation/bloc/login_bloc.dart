import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/cashier.dart';
import '../../domain/usecases/login_usecase.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._loginUseCase) : super(const LoginState()) {
    on<LoginSubmitted>(_onSubmitted);
  }

  final LoginUseCase _loginUseCase;

  Future<void> _onSubmitted(
    LoginSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    final result = await _loginUseCase(
      LoginParams(username: event.username, password: event.password),
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isLoading: false, errorMessage: _messageOf(failure)),
      ),
      (session) => emit(state.copyWith(isLoading: false, session: session)),
    );
  }

  String _messageOf(Failure failure) {
    return switch (failure) {
      ServerFailure(:final message) => message,
      NoInternetFailure() => "Internet aloqasi yo'q",
      _ => "Kirishda xatolik yuz berdi",
    };
  }
}
