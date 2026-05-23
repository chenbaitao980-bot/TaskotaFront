import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:smart_assistant/core/constants/app_constants.dart';
import 'package:smart_assistant/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  });

  testWidgets('shows login page when unauthenticated', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('智能小管家'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
    expect(find.text('立即注册'), findsOneWidget);
  });
}
