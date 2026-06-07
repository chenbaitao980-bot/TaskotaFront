import 'dart:async';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/desktop/desktop_runtime.dart';
import '../core/router/app_router.dart';
import '../data/database/app_database.dart' show Task;
import '../models/entities/schedule.dart';
import '../models/entities/task_breakdown.dart';
import 'alarm_service.dart';
import 'local_storage_service.dart';
import 'wechat_reminder_service.dart';
import '../core/utils/file_logger.dart';

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

class _MobilePermResult {
  final bool notificationsGranted;
  final bool exactAlarmGranted;
  const _MobilePermResult(this.notificationsGranted, this.exactAlarmGranted);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// 通知点击后待跳转的任务 ID，由 _HomeContentState 在数据加载后消费并清除。
  static String? pendingTaskId;

  FlutterLocalNotificationsPlugin? _plugin;
  FlutterLocalNotificationsWindows? _windowsPlugin;
  final Map<int, Timer> _timers = {};
  final List<PendingNotification> _pendingNotifications = [];
  final List<String> _diagnosticLog = [];
  bool _initialized = false;
  bool _useOsNotifications = false;
  bool _useNativeWindowsNotifications = false;

  List<String> get diagnosticLog => List.unmodifiable(_diagnosticLog);
  String get diagnosticSummary => _diagnosticLog.join('\n');

  void _log(String msg) {
    print(msg);
    _diagnosticLog.add(msg);
    flog(msg);
    if (_diagnosticLog.length > 200) _diagnosticLog.removeAt(0);
  }

  static int notificationIdForSchedule(String scheduleId, {int offset = 0}) {
    var hash = 0x811c9dc5;
    for (final unit in scheduleId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return (hash + offset) & 0x7fffffff;
  }

  static bool shouldRescheduleReminder({
    required bool reminderEnabled,
    required DateTime? startTime,
    bool isRepeating = false,
    int? repeatInterval,
    DateTime? now,
  }) {
    if (!reminderEnabled || startTime == null) return false;
    if (isRepeating && repeatInterval != null && repeatInterval > 0) {
      return true;
    }
    return !startTime.isBefore(now ?? DateTime.now());
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    tz.initializeTimeZones();
    await _configureLocalTimezone();
    _log('[Notif] init tz.local=${tz.local}');

    try {
      if (Platform.isWindows) {
        _windowsPlugin = FlutterLocalNotificationsWindows();
        _useNativeWindowsNotifications = await _windowsPlugin!.initialize(
          const WindowsInitializationSettings(
            appName: 'Taskora',
            appUserModelId: 'taskora.desktop.app',
            guid: '7d84f3c8-c11c-4cf4-bc6b-5886b4f08941',
          ),
          onNotificationReceived: (response) {
            if (response.payload != null) {
              pendingTaskId = response.payload;
            }
            AppRouter.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/', (route) => false);
          },
        );
        return;
      }

      _plugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
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
        onDidReceiveNotificationResponse: (response) {
          // 点击任何通知：先停掉对应的 alarm，再跳首页
          if (response.id != null) AlarmService().cancelAlarm(response.id!);
          if (response.payload == null) {
            AppRouter.navigatorKey.currentState
                ?.pushNamedAndRemoveUntil('/', (route) => false);
            return;
          }
          // 所有非空 payload（含 overdue_navigate）：记录待定位 ID，首页加载后消费
          pendingTaskId = response.payload;
          AppRouter.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
        },
      );

      await _createNotificationChannels();
      _useOsNotifications = true;
    } catch (e) {
      _useOsNotifications = false;
    }
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {}
  }

  Future<void> _createNotificationChannels() async {
    if (_plugin == null) return;

    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();

    // 清理旧通道（在系统设置中会保留但不再使用，用户仍能看到）
    try {
      await androidPlugin.deleteNotificationChannel('schedule_reminders');
      await androidPlugin.deleteNotificationChannel('repeating_reminders');
    } catch (_) {}

    try {
      // 只创建 1 个通道：taskora_reminders
      // 原生 AlarmManager + flutter_local_notifications 都使用此通道
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'taskora_reminders',
          '任务提醒',
          description: '任务与日程的提醒通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (_) {}
  }

  static const _androidDetails = AndroidNotificationDetails(
    'taskora_reminders',
    '任务提醒',
    channelDescription: '任务与日程的提醒通知',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );
  static const _iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  static const _notifDetails = NotificationDetails(
    android: _androidDetails,
    iOS: _iosDetails,
    macOS: _iosDetails,
  );

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!_initialized) await init();
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    // Desktop: in-process Timer
    if (!Platform.isAndroid && !Platform.isIOS) {
      _timers[id]?.cancel();
      final duration = scheduledDate.difference(now);
      _timers[id] = Timer(duration, () {
        _showDesktopNativeNotification(id, title, body);
      });
      return;
    }

    // Android / iOS: zonedSchedule
    _log('[Notif] sched id=$id useOs=$_useOsNotifications plugin=${_plugin != null}');
    if (_useOsNotifications && _plugin != null) {
      final perm = await _ensureMobileNotificationPermissions();
      _log('[Notif] sched perm notif=${perm.notificationsGranted} exact=${perm.exactAlarmGranted}');
      if (!perm.notificationsGranted) {
        _log('[Notif] sched BLOCKED: notifications not granted');
        _pendingNotifications.add(
          PendingNotification(id: id, title: title, body: body),
        );
        return;
      }
      final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
      // Try exact first if permission granted, else skip straight to inexact
      final mode = perm.exactAlarmGranted
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
      try {
        await _plugin!.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          _notifDetails,
          androidScheduleMode: mode,
          payload: payload,
        );
      } catch (e1) {
        _log('[Notif] primary mode $mode failed: $e1');
        // Last resort: inexactAllowWhileIdle (widest compatibility, no extra permission)
        try {
          await _plugin!.zonedSchedule(
            id,
            title,
            body,
            tzScheduled,
            _notifDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload,
          );
        } catch (e2) {
          _log('[Notif] all zonedSchedule modes failed: $e2');
          _pendingNotifications.add(
            PendingNotification(id: id, title: title, body: body),
          );
          return;
        }
      }
      // AlarmService 作为后台兜底（setAlarmClock，App 被杀后仍能触发）
      await AlarmService().scheduleAlarm(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
      );
      return;
    } else {
      // Plugin not ready (init failed or incomplete), track as pending for retry
      _pendingNotifications.add(
        PendingNotification(id: id, title: title, body: body),
      );
    }
  }

  static const int _maxRepeatOccurrences = 20;

  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstFireAt,
    required int intervalMs,
  }) async {
    if (!_initialized) await init();
    final now = DateTime.now();
    _timers[id]?.cancel();
    _timers.remove(id);

    if (Platform.isAndroid || Platform.isIOS) {
      // 预调度未来N次通知，每次独立注册到系统 AlarmManager，APP被杀后仍能触发
      final interval = Duration(milliseconds: intervalMs);
      final cutoff = now.add(const Duration(hours: 24));
      var nextFire = firstFireAt.isAfter(now) ? firstFireAt : now.add(interval);
      var count = 0;
      while (count < _maxRepeatOccurrences && nextFire.isBefore(cutoff)) {
        await scheduleNotification(
          id: (id + count + 1) & 0x7fffffff,
          title: title,
          body: body,
          scheduledDate: nextFire,
        );
        nextFire = nextFire.add(interval);
        count++;
      }
      _log('[Notif] repeating: pre-scheduled $count occurrences for id=$id');
      return;
    }

    // Desktop: recursive Timer
    void fireAndReschedule([Timer? _]) {
      _showDesktopNativeNotification(id, title, body);
      _timers[id] = Timer(
        Duration(milliseconds: intervalMs),
        fireAndReschedule,
      );
    }

    if (firstFireAt.isAfter(now)) {
      _timers[id] = Timer(firstFireAt.difference(now), fireAndReschedule);
    } else {
      fireAndReschedule();
    }
  }

  void _showDesktopNativeNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) {
    try {
      final channel = resolveDesktopNotificationChannel(
        isWindows: Platform.isWindows,
        hasNativeWindowsPlugin: _useNativeWindowsNotifications,
      );
      if (channel == DesktopNotificationChannel.nativePlugin) {
        unawaited(_showWindowsPluginNotification(id, title, body, payload: payload));
      } else if (channel == DesktopNotificationChannel.windowsScript) {
        _showWindowsNotification(title, body);
      } else if (Platform.isMacOS) {
        _showMacOSNotification(title, body);
      } else if (Platform.isLinux) {
        _showLinuxNotification(title, body);
      }
    } catch (_) {
      _pendingNotifications.add(
        PendingNotification(id: id, title: title, body: body),
      );
    }
  }

  Future<void> _showWindowsPluginNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) async {
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
        details: WindowsNotificationDetails(
          duration: WindowsNotificationDuration.short,
          images: [
            WindowsImage(
              WindowsImage.getAssetUri('assets/icons/app_icon_1024.png'),
              altText: 'Taskora',
              placement: WindowsImagePlacement.appLogoOverride,
              crop: WindowsImageCrop.circle,
            ),
          ],
        ),
        payload: payload,
      );
    } catch (_) {
      _showWindowsNotification(title, body);
    }
  }

  void _showWindowsNotification(String title, String body) {
    try {
      final psPath =
          '${Directory.systemTemp.path}\\sa_notify_${DateTime.now().microsecondsSinceEpoch}.ps1';
      final safeTitle = title.replaceAll("'", "''").replaceAll('"', '&quot;');
      final safeBody = body.replaceAll("'", "''").replaceAll('"', '&quot;');
      final iconFile = File('data/flutter_assets/assets/icons/app_icon_1024.png');
      final iconPath = iconFile.absolute.path;
      final iconUri = 'file:///${iconPath.replaceAll('\\', '/')}';
      File(psPath).writeAsStringSync(
        "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null\n"
        "[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > \$null\n"
        "\$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()\n"
        "\$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\">"
        "<text>$safeTitle</text>"
        "<text>$safeBody</text>"
        "<image placement=\"appLogoOverride\" hint-crop=\"circle\" src=\"$iconUri\" alt=\"Taskora\"/>"
        "</binding></visual></toast>')\n"
        "\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)\n"
        "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Taskora').Show(\$toast)\n",
      );
      Process.run('powershell', ['-NoProfile', '-File', psPath]);
    } catch (_) {}
  }

  void _showMacOSNotification(String title, String body) {
    Process.run('osascript', [
      '-e',
      'display notification "$body" with title "$title"',
    ]);
  }

  void _showLinuxNotification(String title, String body) {
    Process.run('notify-send', [title, body]);
  }

  Future<bool> checkMobilePermissions() async {
    if (_plugin == null) return false;
    try {
      if (Platform.isAndroid) {
        final android = _plugin!
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.areNotificationsEnabled() ?? false;
      }
      if (Platform.isIOS) {
        final ios = _plugin!
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final result = await ios?.checkPermissions();
        return result?.isEnabled ?? false;
      }
    } catch (_) {}
    return false;
  }

  /// Request mobile notification permissions. Returns true if granted now.
  /// On permission transition from denied to granted, consumes pending
  /// notifications (caller should re-schedule reminders).
  Future<bool> requestMobilePermissions() async {
    if (!_initialized) await init();
    final wasGranted = await checkMobilePermissions();
    await _ensureMobileNotificationPermissions();
    final isGranted = await checkMobilePermissions();
    if (!wasGranted && isGranted) {
      consumePending();
    }
    return isGranted;
  }

  /// Immediately show a test notification (fires ~1 second from now).
  /// Returns true if scheduling succeeded, false otherwise.
  Future<bool> showImmediateTestNotification() async {
    if (!_initialized) await init();
    if (!Platform.isAndroid && !Platform.isIOS) {
      _log('[Notif] test: not a mobile platform');
      return false;
    }
    final perm = await _ensureMobileNotificationPermissions();
    _log('[Notif] test: notif=${perm.notificationsGranted} exact=${perm.exactAlarmGranted} useOs=$_useOsNotifications');
    if (!perm.notificationsGranted) {
      _log('[Notif] test FAILED: notifications not granted');
      return false;
    }
    try {
      await _plugin?.zonedSchedule(
        9999,
        'Test Notification',
        'Notification pipeline is working!',
        tz.TZDateTime.from(DateTime.now().add(const Duration(seconds: 1)), tz.local),
        _notifDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      _log('[Notif] test OK: scheduled');
      return true;
    } catch (e) {
      _log('[Notif] test FAILED: $e');
      return false;
    }
  }

  /// Check if exact alarm / schedule-exact-alarm permission is granted (Android 12+).
  Future<bool> checkExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;
    if (_plugin == null) return false;
    try {
      final android = _plugin!
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<_MobilePermResult> _ensureMobileNotificationPermissions() async {
    final plugin = _plugin;
    if (plugin == null) return const _MobilePermResult(false, false);

    if (Platform.isAndroid) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      final notificationsEnabled = await android?.areNotificationsEnabled();
      final exactEnabled = await android?.canScheduleExactNotifications();
      return _MobilePermResult(
        notificationsEnabled ?? false,
        exactEnabled ?? false,
      );
    }

    if (Platform.isIOS) {
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
      final result = await ios?.checkPermissions();
      final granted = result?.isEnabled ?? false;
      return _MobilePermResult(granted, granted); // iOS: no separate exact alarm
    }
    return const _MobilePermResult(true, true);
  }

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
    if (!_initialized) await init();
    final now = DateTime.now();
    final remindAt = startTime.subtract(Duration(minutes: remindBeforeMinutes));

    if (!remindAt.isBefore(now)) {
      await scheduleNotification(
        id: notificationIdForSchedule(scheduleId),
        title: 'Upcoming: $title',
        body: description ?? 'Your schedule starts in $remindBeforeMinutes minutes',
        scheduledDate: remindAt,
        payload: scheduleId,
      );
    }

    if (!startTime.isBefore(now)) {
      await scheduleNotification(
        id: notificationIdForSchedule(scheduleId, offset: 1),
        title: 'Starting: $title',
        body: description ?? 'Your schedule is starting now',
        scheduledDate: startTime,
        payload: scheduleId,
      );
    }

    if (isRepeating && repeatInterval != null && repeatInterval > 0) {
      final repeatStartAt = remindAt.isAfter(now) ? remindAt : now;
      await scheduleRepeatingNotification(
        id: notificationIdForSchedule(scheduleId, offset: 1000),
        title: 'Repeat: $title',
        body: description ?? 'Your schedule needs attention',
        firstFireAt: repeatStartAt,
        intervalMs: repeatInterval * 60 * 1000,
      );
    }

    // 服务端推送兜底（微信 + FCM）
    final pushBody = description ?? 'Your schedule starts in $remindBeforeMinutes minutes';
    final pushAt = remindAt.isAfter(now) ? remindAt : startTime;
    if (pushAt.isAfter(now)) {
      WechatReminderService().scheduleServerPush(
        taskId: scheduleId,
        title: title,
        body: pushBody,
        scheduledAt: pushAt,
      );
    }
  }

  Future<void> cancelReminderForSchedule(String scheduleId) async {
    await cancelNotification(notificationIdForSchedule(scheduleId));
    await cancelNotification(notificationIdForSchedule(scheduleId, offset: 1));
    // 取消所有预调度的重复通知（offset 1000 + 0..N）
    final baseId = notificationIdForSchedule(scheduleId, offset: 1000);
    for (var i = 0; i <= _maxRepeatOccurrences; i++) {
      await cancelNotification((baseId + i + 1) & 0x7fffffff);
    }
    await cancelNotification(baseId);
    // 取消服务端推送
    WechatReminderService().cancelServerPush(taskId: scheduleId);
  }

  static const int _overdueDigestNotificationId = 0x7ffffffe;

  Future<void> _showOverdueDigest(int count) async {
    if (count <= 0) return;

    // 时间窗口节流：读取上次弹通知时间和用户配置的间隔
    try {
      final storage = LocalStorageService();
      await storage.init();
      final lastMs = storage.overdueLastNotifMs;
      final intervalHours = storage.overdueNotifIntervalHours;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastMs < intervalHours * 3600 * 1000) return;
      // 满足条件，先持久化时间戳再弹通知
      await storage.setOverdueLastNotifMs(nowMs);
    } catch (_) {
      // init 失败时降级：直接弹通知
    }

    final title = '你有 $count 个过期任务未完成';
    const body = '点击查看详情';
    if (!_initialized) await init();

    if (Platform.isAndroid || Platform.isIOS) {
      if (_useOsNotifications && _plugin != null) {
        try {
          await _plugin!.show(
            _overdueDigestNotificationId,
            title,
            body,
            _notifDetails,
            payload: 'overdue_navigate',
          );
        } catch (e) {
          _log('[Notif] overdue digest show failed: $e');
        }
      }
    } else {
      _showDesktopNativeNotification(
        _overdueDigestNotificationId,
        title,
        body,
        payload: 'overdue_navigate',
      );
    }
    _log('[Notif] overdue digest: $count tasks');
  }

  Future<void> rescheduleTaskReminders(Iterable<Task> tasks) async {
    final now = DateTime.now();
    int scheduled = 0;
    final List<String> overdueTaskIds = [];
    for (final task in tasks) {
      await cancelReminderForSchedule(task.id);
      if (task.deleted != 0 || task.status == 2) continue;
      if (task.reminderEnabled <= 0) continue;
      final startTime = task.startDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(task.startDate!);
      if (startTime == null) continue;
      // 逾期判断：以 dueDate（结束日期）为准；无 dueDate 则永不逾期
      final dueTime = task.dueDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(task.dueDate!);
      if (dueTime != null && dueTime.isBefore(now)) {
        overdueTaskIds.add(task.id);
        continue;
      }
      if (startTime.isBefore(now)) continue;
      await scheduleReminderForSchedule(
        scheduleId: task.id,
        title: task.title,
        startTime: startTime,
        description: task.description,
        remindBeforeMinutes: task.remindBeforeMinutes,
      );
      scheduled++;
    }
    await _showOverdueDigest(overdueTaskIds.length);
    _log('[Notif] rescheduleTaskReminders: ${tasks.length} tasks, $scheduled scheduled, ${overdueTaskIds.length} overdue');
  }

  Future<void> _clearOverdueAlarms(Iterable<String> overdueIds) async {
    for (final id in overdueIds) {
      await cancelReminderForSchedule(id);
    }
  }

  Future<void> rescheduleBreakdownTaskReminders(
    Iterable<TaskBreakdown> tasks,
  ) async {
    final now = DateTime.now();
    final List<String> overdueTaskIds = [];
    for (final task in tasks) {
      await cancelReminderForSchedule(task.id);
      if (task.status == 'completed') continue;
      if (!task.reminderEnabled) continue;
      if (task.startDate == null) continue;
      if (task.startDate!.isBefore(now)) {
        overdueTaskIds.add(task.id);
        continue;
      }
      await scheduleReminderForSchedule(
        scheduleId: task.id,
        title: task.title,
        startTime: task.startDate!,
        description: task.description,
        remindBeforeMinutes: task.remindBeforeMinutes,
      );
    }
    await _clearOverdueAlarms(overdueTaskIds);
    // Breakdown 过期数合并到主 Task digest，此处不重复弹
  }

  Future<void> rescheduleScheduleReminders(Iterable<Schedule> schedules) async {
    final now = DateTime.now();
    final List<String> overdueScheduleIds = [];
    for (final schedule in schedules) {
      await cancelReminderForSchedule(schedule.id);
      if (!schedule.reminderEnabled) continue;
      if (schedule.startTime.isBefore(now) && !schedule.isRepeating) {
        overdueScheduleIds.add(schedule.id);
        continue;
      }
      if (!shouldRescheduleReminder(
        reminderEnabled: schedule.reminderEnabled,
        startTime: schedule.startTime,
        isRepeating: schedule.isRepeating,
        repeatInterval: schedule.repeatInterval,
        now: now,
      )) {
        continue;
      }
      await scheduleReminderForSchedule(
        scheduleId: schedule.id,
        title: schedule.title,
        startTime: schedule.startTime,
        description: schedule.description,
        remindBeforeMinutes: schedule.remindBeforeMinutes,
        isRepeating: schedule.isRepeating,
        repeatInterval: schedule.repeatInterval,
      );
    }
    await _clearOverdueAlarms(overdueScheduleIds);
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
    await AlarmService().cancelAlarm(id);
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
