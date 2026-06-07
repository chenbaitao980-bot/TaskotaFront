import 'dart:io' show exit;
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';
import '../core/constants/app_constants.dart';
import '../core/desktop/desktop_runtime.dart';

final _systemTray = SystemTray();

Future<void> initTray() async {
  try {
    await windowManager.waitUntilReadyToShow();
    await windowManager.setSkipTaskbar(false);

    final trayOk = await _systemTray.initSystemTray(
      title: AppConstants.appName,
      iconPath: 'assets/icons/tray_icon.ico',
      toolTip: AppConstants.appName,
    );
    print(trayOk ? '[Tray] 初始化成功' : '[Tray] 初始化失败 - 检查图标路径');
  } catch (e) {
    print('[Tray] 异常: $e');
    return;
  }

  final menu = [
    MenuItem(
      label: '显示',
      onClicked: () async {
        await windowManager.show();
        await windowManager.focus();
      },
    ),
    MenuSeparator(),
    MenuItem(
      label: '退出',
      onClicked: () async {
        await windowManager.destroy();
        exit(0);
      },
    ),
  ];
  await _systemTray.setContextMenu(menu);

  _systemTray.registerSystemTrayEventHandler((eventName) {
    final action = trayEventActionFor(eventName);
    if (action == TrayEventAction.showWindow) {
      windowManager.show();
      windowManager.focus();
    } else if (action == TrayEventAction.popUpContextMenu) {
      _systemTray.popUpContextMenu();
    }
  });
}
