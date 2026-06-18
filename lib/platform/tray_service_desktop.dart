import 'dart:io' show exit;

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../core/constants/app_constants.dart';
import '../core/desktop/window_state.dart';
import '../core/desktop/desktop_runtime.dart';

final _systemTray = SystemTray();

Future<void> initTray() async {
  try {
    await windowManager.waitUntilReadyToShow();
    await windowManager.setSkipTaskbar(false);

    await _systemTray.initSystemTray(
      title: AppConstants.appName,
      iconPath: 'assets/icons/tray_icon.ico',
      toolTip: AppConstants.appName,
    );
  } catch (e) {
    debugPrint('[Tray] init failed: $e');
    return;
  }

  final menu = [
    MenuItem(
      label: '显示',
      onClicked: () async {
        await (showDesktopWindow?.call() ?? windowManager.show());
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
      (showDesktopWindow?.call() ?? windowManager.show()).then((_) {
        windowManager.focus();
      });
    } else if (action == TrayEventAction.popUpContextMenu) {
      _systemTray.popUpContextMenu();
    }
  });
}
