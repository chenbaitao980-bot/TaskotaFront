import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:smart_assistant/core/constants/app_constants.dart';
import 'package:smart_assistant/presentation/blocs/auth/auth_bloc.dart';
import 'package:smart_assistant/presentation/pages/auth/login_page.dart';
import 'package:smart_assistant/services/supabase_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (_) {}
  });

  testWidgets('keeps phone otp mode after loading and sent states', (
    tester,
  ) async {
    final bloc = _TestAuthBloc();
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginPage(),
        ),
      ),
    );

    await tester.tap(find.text('手机验证码'));
    await tester.pump();

    bloc.push(AuthLoading());
    await tester.pump();
    bloc.push(const PhoneOtpSent(phone: '+8613812345678'));
    await tester.pumpAndSettle();

    expect(find.text('短信验证码'), findsOneWidget);
    expect(find.text('验证码登录'), findsOneWidget);
  });
}

class _TestAuthBloc extends AuthBloc {
  _TestAuthBloc() : super(supabaseService: SupabaseService());

  void push(AuthState state) => emit(state);
}
