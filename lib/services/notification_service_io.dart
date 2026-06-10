import 'dart:async';
import 'dart:collection';
import 'dart:io' show Directory, File, Platform, Process;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, OverlayEntry, Positioned;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/desktop/desktop_runtime.dart';
import '../core/desktop/window_state.dart';
import '../core/router/app_router.dart';
import '../data/database/app_database.dart' show Task;
import '../models/entities/schedule.dart';
import '../models/entities/task_breakdown.dart';
import '../presentation/widgets/reminder_dialog.dart';
import 'alarm_service.dart';
import 'local_storage_service.dart';
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

class _PendingDialog {
  final int id;
  final String title;
  final String body;
  final String? payload;

  _PendingDialog({
    required this.id,
    required this.title,
    required this.body,
    this.payload,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// 通知点击后待跳转的任务 ID，由 _HomeContentState 在数据加载后消费并清除。
  static String? pendingTaskId;

  /// "标记完成"按钮触发的任务 ID，由 _HomeContentState 在数据加载后消费并清除。
  static String? pendingMarkDoneTaskId;

  FlutterLocalNotificationsPlugin? _plugin;
  FlutterLocalNotificationsWindows? _windowsPlugin;
  final Map<int, Timer> _timers = {};
  final List<PendingNotification> _pendingNotifications = [];
  final List<String> _diagnosticLog = [];
  Future<void>? _initFuture;
  bool _useOsNotifications = false;
  bool _useNativeWindowsNotifications = false;

  // 应用内提醒弹窗队列（macOS/Linux 前台时使用）
  final Queue<_PendingDialog> _dialogQueue = Queue();
  bool _dialogShowing = false;
  OverlayEntry? _currentOverlayEntry;

  // Windows Toast 状态追踪
  // key: 通知 id；value: 发出通知时窗口是否处于隐藏状态（用于按钮回调后决定是否重新隐藏）
  final Map<int, bool> _windowWasHiddenWhenNotifSent = {};
  // key: 通知 id；value: 标题/正文/payload（用于稍后提醒重新调度）
  final Map<int, ({String title, String body, String? payload})>
      _notifStore = {};

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

  /// 幂等初始化：并发/提前调用共享同一 Future，
  /// 保证 init 完成前的调度调用会先等待初始化完成而不是跳过。
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
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
            final action = response.actionId ?? '';
            final id = response.id ?? -1;
            // 通知发送时的窗口状态（foreground 激活会自动唤起窗口，需按此决定是否重新隐藏）
            final wasHidden = _windowWasHiddenWhenNotifSent.remove(id) ?? true;

            if (action == 'dismiss') {
              if (wasHidden) hideDesktopWindow?.call();
              return;
            }
            if (action == 'snooze') {
              final snoozeMin = int.tryParse(
                    (response.data['snoozeTime'] as String?) ?? '15',
                  ) ??
                  15;
              _rescheduleSnooze(id, snoozeMin);
              if (wasHidden) hideDesktopWindow?.call();
              return;
            }
            if (action == 'markdone') {
              final p = response.payload;
              if (p != null && p.isNotEmpty && p != 'overdue_navigate') {
                pendingMarkDoneTaskId = p;
              }
              if (wasHidden) hideDesktopWindow?.call();
              return;
            }
            if (action.startsWith('view:')) {
              pendingTaskId = action.substring(5);
              // foreground 激活是异步的，需等 showDesktopWindow 完成后再导航，
              // 否则 Flutter lifecycle 尚未 resume，pushNamedAndRemoveUntil 会静默失败
              (showDesktopWindow?.call() ?? Future.value()).then((_) {
                AppRouter.navigatorKey.currentState
                    ?.pushNamedAndRemoveUntil('/', (route) => false);
              });
              return;
            }
            // 点击通知主体（非按钮）
            if (response.payload != null) pendingTaskId = response.payload;
            (showDesktopWindow?.call() ?? Future.value()).then((_) {
              AppRouter.navigatorKey.currentState
                  ?.pushNamedAndRemoveUntil('/', (route) => false);
            });
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
    await init();
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    // Desktop: in-process Timer
    if (!Platform.isAndroid && !Platform.isIOS) {
      _timers[id]?.cancel();
      final duration = scheduledDate.difference(now);
      _timers[id] = Timer(duration, () {
        _showDesktopNativeNotification(id, title, body, payload: payload);
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
    await init();
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

  /// 应用是否处于前台（桌面端：窗口真实可见 + lifecycle 非后台）
  bool _isAppInForeground() {
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return false;
    if (!Platform.isAndroid && !Platform.isIOS) {
      // 窗口隐藏（hide 到托盘）时走 OS 通知，不在不可见窗口里弹 dialog
      if (!desktopWindowVisible) return false;
      final lifecycle = SchedulerBinding.instance.lifecycleState;
      return lifecycle == AppLifecycleState.resumed ||
          lifecycle == AppLifecycleState.inactive ||
          lifecycle == null;
    }
    final lifecycle = SchedulerBinding.instance.lifecycleState;
    return lifecycle == AppLifecycleState.resumed || lifecycle == null;
  }

  void _showDesktopNativeNotification(
    int id,
    String title,
    String body, {
    String? payload,
  }) {
    // Windows: 统一走系统 Toast，不论窗口是否可见
    if (Platform.isWindows && _useNativeWindowsNotifications) {
      unawaited(_showWindowsPluginNotification(id, title, body, payload: payload));
      return;
    }
    // macOS/Linux: 前台时弹应用内 Overlay，后台时走 OS 通知
    if (_isAppInForeground()) {
      _showInAppReminderDialog(id, title, body, payload);
      return;
    }
    _showOsNotificationFallback(id, title, body, payload: payload);
  }

  /// 将提醒加入队列，若当前没有弹窗则立即弹出
  void _showInAppReminderDialog(
    int id,
    String title,
    String body,
    String? payload,
  ) {
    _dialogQueue.add(
      _PendingDialog(id: id, title: title, body: body, payload: payload),
    );
    if (!_dialogShowing) {
      _processDialogQueue();
    }
  }

  void _processDialogQueue() {
    if (_dialogQueue.isEmpty) {
      _dialogShowing = false;
      return;
    }
    final overlay = AppRouter.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      _dialogShowing = false;
      while (_dialogQueue.isNotEmpty) {
        final item = _dialogQueue.removeFirst();
        _showOsNotificationFallback(item.id, item.title, item.body);
      }
      return;
    }
    _dialogShowing = true;
    final item = _dialogQueue.removeFirst();

    void closeOverlay() {
      _currentOverlayEntry?.remove();
      _currentOverlayEntry = null;
      _processDialogQueue();
    }

    _currentOverlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        right: 16,
        bottom: 16,
        child: ReminderDialog(
          title: item.title,
          body: item.body,
          onClose: closeOverlay,
          onMarkDone: () => _handleMarkDone(item.payload),
          onSnooze: (delay) =>
              _rescheduleNotification(item.id, item.title, item.body, item.payload, delay),
          onViewDetail: () => _handleViewDetail(item.payload),
        ),
      ),
    );
    overlay.insert(_currentOverlayEntry!);
  }

  void _showOsNotificationFallback(int id, String title, String body, {String? payload}) {
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
    } catch (_) {}
  }

  /// 解析 payload 中的 taskId 并标记任务完成
  void _handleMarkDone(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (payload == 'overdue_navigate') return;
    _log('[Notif] markDone payload=$payload (via pendingMarkDoneTaskId)');
    NotificationService.pendingMarkDoneTaskId = payload;
  }

  /// "查看详情"按钮：导航到对应任务
  void _handleViewDetail(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (payload == 'overdue_navigate') return;
    _log('[Notif] viewDetail navigate payload=$payload');
    NotificationService.pendingTaskId = payload;
    AppRouter.navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/', (route) => false);
  }

  /// 在指定延迟后重新触发提醒
  void _rescheduleNotification(
    int id,
    String title,
    String body,
    String? payload,
    Duration delay,
  ) {
    _timers[id]?.cancel();
    _timers[id] = Timer(
      delay,
      () => _showDesktopNativeNotification(id, title, body, payload: payload),
    );
    _log('[Notif] snooze id=$id delay=${delay.inMinutes}min');
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
      final hasTask = payload != null &&
          payload.isNotEmpty &&
          payload != 'overdue_navigate';

      _windowWasHiddenWhenNotifSent[id] = !desktopWindowVisible;
      _notifStore[id] = (title: title, body: body, payload: payload);

      await plugin.show(
        id,
        title,
        body,
        details: WindowsNotificationDetails(
          scenario: WindowsNotificationScenario.alarm,
          audio: WindowsNotificationAudio.silent(),
          images: [
            WindowsImage(
              WindowsImage.getAssetUri('assets/icons/app_icon_1024.png'),
              altText: 'Taskora',
              placement: WindowsImagePlacement.appLogoOverride,
              crop: WindowsImageCrop.circle,
            ),
          ],
          inputs: [
            WindowsSelectionInput(
              id: 'snoozeTime',
              title: '稍后提醒',
              items: const [
                WindowsSelection(id: '5', content: '5 分钟后'),
                WindowsSelection(id: '15', content: '15 分钟后'),
                WindowsSelection(id: '30', content: '30 分钟后'),
                WindowsSelection(id: '60', content: '60 分钟后'),
              ],
              defaultItem: '15',
            ),
          ],
          actions: [
            const WindowsAction(
              content: '稍后提醒',
              arguments: 'snooze',
              inputId: 'snoozeTime',
            ),
            if (hasTask) ...[
              const WindowsAction(content: '标记完成', arguments: 'markdone'),
              WindowsAction(content: '查看详情', arguments: 'view:$payload'),
            ],
            const WindowsAction(content: '知道了', arguments: 'dismiss'),
          ],
        ),
        payload: payload,
      );
    } catch (e) {
      _log('[Notif] windows plugin show failed: $e');
      _showWindowsNotification(title, body);
    }
  }

  /// 稍后提醒：按选定时长重新调度 Windows Toast
  void _rescheduleSnooze(int id, int snoozeMinutes) {
    final stored = _notifStore[id];
    if (stored == null) {
      _log('[Notif] snooze: no stored details for id=$id, skipping');
      return;
    }
    _timers[id]?.cancel();
    _timers[id] = Timer(
      Duration(minutes: snoozeMinutes),
      () => _showDesktopNativeNotification(
        id,
        stored.title,
        stored.body,
        payload: stored.payload,
      ),
    );
    _log('[Notif] snooze id=$id delay=${snoozeMinutes}min');
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
    await init();
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
    await init();
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
    await init();
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
    await init();

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
    _notifStore.remove(id);
    _windowWasHiddenWhenNotifSent.remove(id);
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
    _notifStore.clear();
    _windowWasHiddenWhenNotifSent.clear();
    if (_plugin != null) await _plugin!.cancelAll();
    if (_windowsPlugin != null) await _windowsPlugin!.cancelAll();
  }
}
