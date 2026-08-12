part of 'login_bloc.dart';

sealed class LoginEvent {
  const LoginEvent();
}

class LoginSubmitted extends LoginEvent {
  const LoginSubmitted({required this.username, required this.password});

  final String username;
  final String password;
}
