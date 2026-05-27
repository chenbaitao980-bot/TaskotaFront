import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_runtime.dart';

void main() {
  test('tray right click pops up the context menu', () {
    expect(
      trayEventActionFor('rightMouseUp'),
      TrayEventAction.popUpContextMenu,
    );
  });

  test('windows desktop notifications prefer the native plugin when available', () {
    expect(
      resolveDesktopNotificationChannel(
        isWindows: true,
        hasNativeWindowsPlugin: true,
      ),
      DesktopNotificationChannel.nativePlugin,
    );
  });
}
