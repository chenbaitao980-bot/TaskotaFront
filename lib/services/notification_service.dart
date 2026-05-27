import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
  final Map<int, Timer> _timers = {};
  final List<PendingNotification> _pendingNotifications = [];
  bool _initialized = false;
  bool _useOsNotifications = false;
  bool _useNativeWindowsNotifications = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

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
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _plugin!.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          // 点击通知时的回调（暂不处理导航）
        },
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
    } catch (_) {
      // 通知渠道创建失败不影响后续使用
    }
  }

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

    // Windows/macOS/Linux 桌面端直接使用系统级通知桥接
    if (!Platform.isAndroid && !Platform.isIOS) {
      _timers[id]?.cancel();
      final duration = scheduledDate.difference(now);
      print('[Notify] Timer #$id 设定: ${duration.inMinutes}分${duration.inSeconds % 60}秒后触发 ($title)');
      _timers[id] = Timer(duration, () {
        print('[Notify] Timer #$id 触发: $title');
        _showDesktopNativeNotification(id, title, body);
      });
      return;
    }

    // Android/iOS：使用 flutter_local_notifications
    if (_useOsNotifications && _plugin != null) {
      try {
        final delay = scheduledDate.difference(now);
        _timers[id]?.cancel();
        _timers[id] = Timer(delay, () async {
          await _showOsNotification(
            id: id,
            title: title,
            body: body,
            payload: payload,
          );
        });
        return;
      } catch (e) {
        // 回退到桌面原生通知
      }
    }

    // 兜底
    _timers[id]?.cancel();
    final duration = scheduledDate.difference(now);
    _timers[id] = Timer(duration, () {
      _showDesktopNativeNotification(id, title, body);
    });
  }

  /// 调度一条重复提醒通知（每隔 intervalMs 毫秒重复，直到被取消）
  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstFireAt,
    required int intervalMs,
  }) async {
    final now = DateTime.now();

    // 先取消旧的
    _timers[id]?.cancel();
    _timers.remove(id);

    // 用一个递归 Timer 实现重复
    void fireAndReschedule([Timer? _]) {
      if (_useOsNotifications && _plugin != null) {
        _showOsNotification(
          id: id,
          title: title,
          body: body,
        );
      } else {
        _showDesktopNativeNotification(id, title, body);
      }
      // 调度下一次
      _timers[id] = Timer(Duration(milliseconds: intervalMs), fireAndReschedule);
    }

    if (firstFireAt.isAfter(now)) {
      final firstDelay = firstFireAt.difference(now);
      _timers[id] = Timer(firstDelay, fireAndReschedule);
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
      const androidDetails = AndroidNotificationDetails(
        'schedule_reminders',
        '日程提醒',
        channelDescription: '日程开始前的提醒通知',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      );

      await _plugin!.show(id, title, body, details, payload: payload);
    } catch (e) {
      // flutter_local_notifications 插件在桌面端可能不支持原生通知，
      // 回退到系统托盘通知或内存管理
      _showDesktopNativeNotification(id, title, body);
    }
  }

  /// 桌面端原生通知回退（Windows 通过系统命令调用 toast，macOS 通过 osascript）
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
      // 全部回退失败时，仅存内存
      _pendingNotifications.add(PendingNotification(
        id: id,
        title: title,
        body: body,
      ));
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
    // Windows Toast 通知：右下角弹出，非阻塞，进入通知中心
    try {
      // 用随机后缀避免多通知写冲突
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
    Process.run('osascript', ['-e',
        'display notification "$body" with title "$title"']);
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

    // 提醒时间：只要不晚于 now 就立即触发或按 Timer 调度
    if (!remindAt.isBefore(now)) {
      print('[Notify] 提前提醒调度: ${remindAt.toIso8601String()} (${remindBeforeMinutes}分钟前)');
      await scheduleNotification(
        id: scheduleId.hashCode,
        title: '即将开始: $title',
        body: description ?? '您的日程将在$remindBeforeMinutes分钟后开始',
        scheduledDate: remindAt,
      );
    } else {
      print('[Notify] 跳过提前提醒: remindAt(${remindAt.toIso8601String()}) 已过 now(${now.toIso8601String()})');
    }

    // 开始提醒
    if (!startTime.isBefore(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode + 1,
        title: '日程开始: $title',
        body: description ?? '您的日程现在开始',
        scheduledDate: startTime,
      );
    }

    // 重复提醒：每隔 repeatInterval 分钟重复
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
    if (_plugin != null) {
      await _plugin!.cancel(id);
    }
    if (_windowsPlugin != null) {
      await _windowsPlugin!.cancel(id);
    }
  }

  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingNotifications.clear();
    if (_plugin != null) {
      await _plugin!.cancelAll();
    }
    if (_windowsPlugin != null) {
      await _windowsPlugin!.cancelAll();
    }
  }
}
