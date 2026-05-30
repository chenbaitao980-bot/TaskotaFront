import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/desktop/desktop_runtime.dart';

class PendingNotification {
  final int id;
  final String title;
  final String body;

  PendingNotification({
    required this.id,
    required this.title,
    required this.body,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _plugin;
  FlutterLocalNotificationsWindows? _windowsPlugin;
  // 桌面端仍用 Timer（进程常驻）
  final Map<int, Timer> _timers = {};
  final List<PendingNotification> _pendingNotifications = [];
  bool _initialized = false;
  bool _useOsNotifications = false;
  bool _useNativeWindowsNotifications = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();

    try {
      if (Platform.isWindows) {
        _windowsPlugin = FlutterLocalNotificationsWindows();
        _useNativeWindowsNotifications = await _windowsPlugin!.initialize(
          const WindowsInitializationSettings(
            appName: 'Smart Assistant',
            appUserModelId: 'smartassistant.desktop.app',
            guid: '7d84f3c8-c11c-4cf4-bc6b-5886b4f08941',
          ),
        );
        return;
      }

      _plugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _plugin!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {},
      );

      await _createNotificationChannels();
      _useOsNotifications = true;
    } catch (e) {
      _useOsNotifications = false;
    }
  }

  Future<void> _createNotificationChannels() async {
    if (_plugin == null) return;

    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    try {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'schedule_reminders',
          '日程提醒',
          description: '日程开始前的提醒通知',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'repeating_reminders',
          '重复提醒',
          description: '重复提醒通知',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (_) {}
  }

  static const _androidDetails = AndroidNotificationDetails(
    'schedule_reminders',
    '日程提醒',
    channelDescription: '日程开始前的提醒通知',
    importance: Importance.high,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
  );
  static const _iosDetails = DarwinNotificationDetails();
  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
    macOS: _iosDetails,
  );

  /// 调度一条一次性提醒通知
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    // 桌面端保留 Timer（进程常驻，不需要系统级持久化）
    if (!Platform.isAndroid && !Platform.isIOS) {
      _timers[id]?.cancel();
      final duration = scheduledDate.difference(now);
      _timers[id] = Timer(duration, () {
        _showDesktopNativeNotification(id, title, body);
      });
      return;
    }

    // Android / iOS：用 zonedSchedule — 进程被杀后系统 AlarmManager 仍会触发
    if (_useOsNotifications && _plugin != null) {
      try {
        final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
        await _plugin!.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          _notifDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload,
        );
        return;
      } catch (e) {
        // 降级到 show（立即显示）
        await _showOsNotification(id: id, title: title, body: body, payload: payload);
      }
    }
  }

  /// 调度一条重复提醒通知（移动端每次用 zonedSchedule 重新调度下一条）
  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstFireAt,
    required int intervalMs,
  }) async {
    final now = DateTime.now();
    _timers[id]?.cancel();
    _timers.remove(id);

    if (Platform.isAndroid || Platform.isIOS) {
      // 移动端：调度第一条，触发后在回调里重新调度（通过 Timer 补位）
      final target = firstFireAt.isAfter(now) ? firstFireAt : now;
      await scheduleNotification(id: id, title: title, body: body, scheduledDate: target);
      // 用 Timer 追踪下一次（如果 App 在前台）
      final delay = target.difference(now);
      _timers[id] = Timer(delay, () async {
        await scheduleRepeatingNotification(
          id: id,
          title: title,
          body: body,
          firstFireAt: DateTime.now().add(Duration(milliseconds: intervalMs)),
          intervalMs: intervalMs,
        );
      });
      return;
    }

    // 桌面端：递归 Timer
    void fireAndReschedule([Timer? _]) {
      _showDesktopNativeNotification(id, title, body);
      _timers[id] = Timer(Duration(milliseconds: intervalMs), fireAndReschedule);
    }

    if (firstFireAt.isAfter(now)) {
      _timers[id] = Timer(firstFireAt.difference(now), fireAndReschedule);
    } else {
      fireAndReschedule();
    }
  }

  Future<void> _showOsNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_plugin == null) return;
    try {
      await _plugin!.show(id, title, body, _notifDetails, payload: payload);
    } catch (_) {
      _showDesktopNativeNotification(id, title, body);
    }
  }

  void _showDesktopNativeNotification(int id, String title, String body) {
    try {
      final channel = resolveDesktopNotificationChannel(
        isWindows: Platform.isWindows,
        hasNativeWindowsPlugin: _useNativeWindowsNotifications,
      );
      if (channel == DesktopNotificationChannel.nativePlugin) {
        unawaited(_showWindowsPluginNotification(id, title, body));
      } else if (channel == DesktopNotificationChannel.windowsScript) {
        _showWindowsNotification(title, body);
      } else if (Platform.isMacOS) {
        _showMacOSNotification(title, body);
      } else if (Platform.isLinux) {
        _showLinuxNotification(title, body);
      }
    } catch (_) {
      _pendingNotifications.add(PendingNotification(id: id, title: title, body: body));
    }
  }

  Future<void> _showWindowsPluginNotification(int id, String title, String body) async {
    final plugin = _windowsPlugin;
    if (plugin == null) {
      _showWindowsNotification(title, body);
      return;
    }
    try {
      await plugin.show(
        id,
        title,
        body,
        details: const WindowsNotificationDetails(
          duration: WindowsNotificationDuration.short,
        ),
      );
    } catch (_) {
      _showWindowsNotification(title, body);
    }
  }

  void _showWindowsNotification(String title, String body) {
    try {
      final psPath = '${Directory.systemTemp.path}\\sa_notify_${DateTime.now().microsecondsSinceEpoch}.ps1';
      final safeTitle = title.replaceAll("'", "''");
      final safeBody = body.replaceAll("'", "''");
      File(psPath).writeAsStringSync(
        "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null\n"
        "\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)\n"
        "\$textNodes = \$template.GetElementsByTagName('text')\n"
        "\$textNodes.Item(0).AppendChild(\$template.CreateTextNode('$safeTitle')) > \$null\n"
        "\$textNodes.Item(1).AppendChild(\$template.CreateTextNode('$safeBody')) > \$null\n"
        "\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$template)\n"
        "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Smart Assistant').Show(\$toast)\n"
      );
      Process.run('powershell', ['-NoProfile', '-File', psPath]);
    } catch (_) {}
  }

  void _showMacOSNotification(String title, String body) {
    Process.run('osascript', ['-e', 'display notification "$body" with title "$title"']);
  }

  void _showLinuxNotification(String title, String body) {
    Process.run('notify-send', [title, body]);
  }

  /// 根据日程信息调度提醒
  Future<void> scheduleReminderForSchedule({
    required String scheduleId,
    required String title,
    required DateTime startTime,
    String? description,
    String priority = 'P2',
    int remindBeforeMinutes = 15,
    bool isRepeating = false,
    int? repeatInterval,
  }) async {
    final now = DateTime.now();
    final remindAt = startTime.subtract(Duration(minutes: remindBeforeMinutes));

    if (!remindAt.isBefore(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode,
        title: '即将开始: $title',
        body: description ?? '您的日程将在$remindBeforeMinutes分钟后开始',
        scheduledDate: remindAt,
      );
    }

    if (!startTime.isBefore(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode + 1,
        title: '日程开始: $title',
        body: description ?? '您的日程现在开始',
        scheduledDate: startTime,
      );
    }

    if (isRepeating && repeatInterval != null && repeatInterval > 0) {
      final repeatStartAt = remindAt.isAfter(now) ? remindAt : now;
      await scheduleRepeatingNotification(
        id: scheduleId.hashCode + 1000,
        title: '⚠️ 重复提醒: $title',
        body: description ?? '您的日程需要关注',
        firstFireAt: repeatStartAt,
        intervalMs: repeatInterval * 60 * 1000,
      );
    }
  }

  List<PendingNotification> consumePending() {
    final result = List<PendingNotification>.from(_pendingNotifications);
    _pendingNotifications.clear();
    return result;
  }

  Future<void> cancelNotification(int id) async {
    _timers[id]?.cancel();
    _timers.remove(id);
    _pendingNotifications.removeWhere((n) => n.id == id);
    if (_plugin != null) await _plugin!.cancel(id);
    if (_windowsPlugin != null) await _windowsPlugin!.cancel(id);
  }

  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingNotifications.clear();
    if (_plugin != null) await _plugin!.cancelAll();
    if (_windowsPlugin != null) await _windowsPlugin!.cancelAll();
  }
}
