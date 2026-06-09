/// 桌面端窗口当前是否对用户可见（hide 后为 false）。
/// 由 window_manager_bridge_desktop.dart 维护，NotificationService 读取。
bool desktopWindowVisible = true;

/// 将窗口唤起到前台的回调，由 setupCloseToTray 注册。
Future<void> Function()? showDesktopWindow;

/// 将窗口隐藏到托盘的回调，由 setupCloseToTray 注册。
/// NotificationService 在通知按钮处理后（非"查看详情"）调用此函数恢复隐藏状态。
Future<void> Function()? hideDesktopWindow;
