part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AuthEvent {}

class LoggedIn extends AuthEvent {
  final String email;
  final String password;

  const LoggedIn({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class PhoneOtpRequested extends AuthEvent {
  final String phone;

  const PhoneOtpRequested({required this.phone});

  @override
  List<Object?> get props => [phone];
}

class PhoneOtpVerified extends AuthEvent {
  final String phone;
  final String token;

  const PhoneOtpVerified({required this.phone, required this.token});

  @override
  List<Object?> get props => [phone, token];
}

class Registered extends AuthEvent {
  final String email;
  final String password;

  const Registered({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class LocalLogin extends AuthEvent {
  final String email;

  const LocalLogin({required this.email});

  @override
  List<Object?> get props => [email];
}

class LoggedOut extends AuthEvent {}
