part of 'login_bloc.dart';

class LoginState extends Equatable {
  const LoginState({this.isLoading = false, this.errorMessage, this.session});

  final bool isLoading;
  final String? errorMessage;
  final AuthSession? session;

  LoginState copyWith({
    bool? isLoading,
    String? errorMessage,
    AuthSession? session,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      session: session ?? this.session,
    );
  }

  @override
  List<Object?> get props => [isLoading, errorMessage, session];
}
