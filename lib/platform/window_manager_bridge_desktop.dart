import 'package:window_manager/window_manager.dart';
import '../core/desktop/window_state.dart';

Future<void> ensureWindowManagerInitialized() async {
  await windowManager.ensureInitialized();
}

/// 点击窗口 X 时隐藏到托盘而不是退出进程，保持 Timer 继续运行。
Future<void> setupCloseToTray() async {
  await windowManager.setPreventClose(true);
  windowManager.addListener(_TrayCloseListener());
  // 注册唤窗/藏窗回调，供 NotificationService 使用
  showDesktopWindow = () async {
    await windowManager.show();
    await windowManager.focus();
    desktopWindowVisible = true;
  };
  hideDesktopWindow = () async {
    desktopWindowVisible = false;
    await windowManager.hide();
  };
}

class _TrayCloseListener extends WindowListener {
  @override
  void onWindowClose() {
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
