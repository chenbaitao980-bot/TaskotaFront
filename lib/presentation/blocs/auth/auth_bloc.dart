import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/supabase_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseService _supabaseService;

  AuthBloc({required SupabaseService supabaseService})
    : _supabaseService = supabaseService,
      super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<PhoneOtpRequested>(_onPhoneOtpRequested);
    on<PhoneOtpVerified>(_onPhoneOtpVerified);
    on<Registered>(_onRegistered);
    on<LocalLogin>(_onLocalLogin);
    on<LoggedOut>(_onLoggedOut);
  }

  void _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final user = _supabaseService.currentUser;
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  void _onLoggedIn(LoggedIn event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final response = await _supabaseService.signIn(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        emit(Authenticated(user: response.user!));
      } else {
        emit(const AuthError(message: '登录失败'));
      }
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  void _onPhoneOtpRequested(
    PhoneOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      await _supabaseService.sendPhoneOtp(phone: event.phone);
      emit(PhoneOtpSent(phone: event.phone));
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  void _onPhoneOtpVerified(
    PhoneOtpVerified event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final response = await _supabaseService.verifyPhoneOtp(
        phone: event.phone,
        token: event.token,
      );

      if (response.user != null) {
        emit(Authenticated(user: response.user!));
      } else {
        emit(const AuthError(message: '验证码登录失败'));
      }
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  void _onRegistered(Registered event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      final response = await _supabaseService.signUp(
        email: event.email,
        password: event.password,
      );

      if (response.user != null) {
        emit(Authenticated(user: response.user!));
      } else {
        emit(const AuthError(message: '注册失败'));
      }
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  void _onLocalLogin(LocalLogin event, Emitter<AuthState> emit) async {
    emit(LocalAuthenticated(email: event.email));
  }

  void _onLoggedOut(LoggedOut event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    try {
      await _supabaseService.signOut();
      emit(Unauthenticated());
    } catch (e) {
      emit(AuthError(message: _authErrorMessage(e)));
    }
  }

  String _authErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('email_not_confirmed') ||
        raw.contains('email not confirmed')) {
      return '邮箱尚未验证，请先打开邮箱完成确认后再登录。';
    }
    if (raw.contains('invalid_credentials') ||
        raw.contains('invalid login credentials')) {
      return '邮箱或密码错误，或账号尚未注册。';
    }
    if (raw.contains('invalid phone')) {
      return '手机号格式不正确，请使用 +8613812345678 格式。';
    }
    if ((raw.contains('sms') || raw.contains('phone')) &&
        (raw.contains('disabled') ||
            raw.contains('not enabled') ||
            raw.contains('not configured') ||
            raw.contains('provider'))) {
      return '手机验证码发送失败：请确认 Supabase 已启用 Phone Auth，并配置短信服务商。';
    }
    if (raw.contains('user_already_exists') ||
        raw.contains('already registered') ||
        raw.contains('already been registered') ||
        raw.contains('already exists')) {
      return '该邮箱已注册，请直接登录。';
    }
    if (raw.contains('signup_disabled')) {
      return '当前暂未开放注册，请稍后再试。';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return '网络连接失败，请检查网络后重试。';
    }

    return '认证失败，请稍后重试。';
  }
}
