import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
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
}
