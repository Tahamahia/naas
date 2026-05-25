part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  const LoginEvent({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class RegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  final String? phone;
  const RegisterEvent({
    required this.email, required this.password,
    required this.fullName, this.phone,
  });
  @override
  List<Object?> get props => [email, password, fullName, phone];
}

class CheckAuthEvent extends AuthEvent {}

class LogoutEvent extends AuthEvent {}

class UpdateProfileEvent extends AuthEvent {
  final Map<String, dynamic> data;
  const UpdateProfileEvent(this.data);
  @override
  List<Object?> get props => [data];
}
