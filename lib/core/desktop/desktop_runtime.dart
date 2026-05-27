enum TrayEventAction {
  none,
  showWindow,
  popUpContextMenu,
}

enum DesktopNotificationChannel {
  windowsScript,
  nativePlugin,
  shellCommand,
}

TrayEventAction trayEventActionFor(String eventName) {
  if (eventName == 'leftMouseDown') {
    return TrayEventAction.showWindow;
  }
  if (eventName == 'rightMouseUp') {
    return TrayEventAction.popUpContextMenu;
  }
  return TrayEventAction.none;
}

DesktopNotificationChannel resolveDesktopNotificationChannel({
  required bool isWindows,
  required bool hasNativeWindowsPlugin,
}) {
  if (isWindows) {
    if (hasNativeWindowsPlugin) {
      return DesktopNotificationChannel.nativePlugin;
    }
    return DesktopNotificationChannel.windowsScript;
  }
  return DesktopNotificationChannel.shellCommand;
}
