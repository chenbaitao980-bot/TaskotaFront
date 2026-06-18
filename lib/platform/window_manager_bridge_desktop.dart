import 'package:window_manager/window_manager.dart';

import '../core/desktop/desktop_floating_tab_controller.dart';
import '../core/desktop/window_state.dart';

Future<void> ensureWindowManagerInitialized() async {
  await windowManager.ensureInitialized();
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
  void onWindowClose() {
    final handler = handleDesktopWindowCloseRequested;
    if (handler != null) {
      handler();
      return;
    }
    desktopWindowVisible = false;
    windowManager.hide();
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
