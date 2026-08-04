import 'dart:async';
import 'dart:io' show Platform;

import 'package:window_manager/window_manager.dart';
import 'package:win32_registry/win32_registry.dart';

import '../core/desktop/desktop_floating_tab_controller.dart';
import '../core/desktop/window_state.dart';

Future<void> ensureWindowManagerInitialized() async {
  await windowManager.ensureInitialized();
}

Future<void> setStartupItem(bool enabled) async {
  final key = Registry.openPath(
    RegistryHive.currentUser,
    path: r'Software\Microsoft\Windows\CurrentVersion\Run',
    desiredAccessRights: AccessRights.writeOnly,
  );
  if (enabled) {
    key.createValue(
      RegistryValue.string('Taskora', Platform.resolvedExecutable),
    );
  } else {
    key.deleteValue('Taskora');
  }
  key.close();
}

Future<void> setupCloseToTray() async {
  await windowManager.setPreventClose(true);
  windowManager.addListener(_TrayCloseListener());

  showDesktopWindow = () async {
    await DesktopFloatingTabController.instance.restoreFullWindow();
  };
  hideDesktopWindow = () async {
    await DesktopFloatingTabController.instance.hideToTray();
  };
  handleDesktopWindowCloseRequested = () async {
    await DesktopFloatingTabController.instance.handleCloseRequested();
  };
}

class _TrayCloseListener extends WindowListener {
  @override
  // R2-2：改 await —— 原 handler() fire-and-forget 与下方 windowManager.hide() 竞态，
  // handleCloseRequested 未完成即隐藏，主窗时序错乱（便签窗创建期间被跳过）。
  Future<void> onWindowClose() async {
    final handler = handleDesktopWindowCloseRequested;
    if (handler != null) {
      await handler();
      return;
    }
    desktopWindowVisible = false;
    await windowManager.hide();
  }

  @override
  void onWindowMinimize() {
    final handler = handleDesktopWindowCloseRequested;
    if (handler != null) {
      unawaited(handler());
      return;
    }
    desktopWindowVisible = false;
  }

  @override
  void onWindowFocus() {
    desktopWindowVisible = true;
  }

  @override
  void onWindowRestore() {
    desktopWindowVisible = true;
  }
}
