import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_assistant/presentation/pages/profile/profile_page.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('logout menu item invokes logout callback', (tester) async {
    var loggedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          onLogout: () {
            loggedOut = true;
          },
        ),
      ),
    );

    final logoutIcon = find.byIcon(Icons.logout_rounded);
    await tester.ensureVisible(logoutIcon);
    await tester.tap(logoutIcon);
    await tester.pump();

    expect(loggedOut, isTrue);
  });

  testWidgets('edit profile saves explicit profile and refreshes header', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('profile_edit_name')), '阿江');
    await tester.enterText(
      find.byKey(const Key('profile_edit_occupation')),
      '独立开发者',
    );
    await tester.enterText(find.byKey(const Key('profile_edit_city')), '广州');
    await tester.enterText(
      find.byKey(const Key('profile_edit_goals')),
      '发布第一版\n稳定日程管理',
    );
    await tester.tap(find.byKey(const Key('profile_edit_save_icon')));
    await tester.pumpAndSettle();

    expect(find.text('阿江'), findsOneWidget);
    expect(find.text('独立开发者 · 广州'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('user_profile'), contains('发布第一版'));
  });

  testWidgets('export menu opens export page', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MaterialApp(home: ProfilePage()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('导出'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导出'));
    await tester.pumpAndSettle();

    expect(find.text('导出需要任务和项目数据源'), findsOneWidget);
  });
}
