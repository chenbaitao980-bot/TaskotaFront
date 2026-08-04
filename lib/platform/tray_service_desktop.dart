import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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
        // R1 根因修复（2026-08-04 实测：窗口消失但进程仍存活、托盘图标残留）：
        // 原 `await windowManager.destroy(); exit(0)` 中 exit(0) 是死代码——destroy() 发
        // PostQuitMessage → 主循环退出 → main() 返回 → CRT 引擎 teardown 在便签第二引擎
        // 线程上挂起 → Dart 事件循环已死 → 后续 exit(0) 永不执行。
        // 改为直接 exit(0) 强制 ExitProcess，绕过 teardown 挂起；drift WAL 已落盘，数据安全。
        try {
          // 同步打点（不依赖异步 flog，exit 前即时落盘），用于实机确认 exit(0) 是否执行到。
          final dir = await getApplicationDocumentsDirectory();
          final logDir = Directory('${dir.path}/logs');
          if (!logDir.existsSync()) logDir.createSync(recursive: true);
          File('${logDir.path}/task_exit.log').writeAsStringSync(
            '${DateTime.now().toIso8601String()} [Tray] exit0 called\n',
            mode: FileMode.append,
          );
        } catch (_) {}
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
