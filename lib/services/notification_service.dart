import 'dart:async';

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

  final Map<int, Timer> _timers = {};
  final List<PendingNotification> _pendingNotifications = [];

  Future<void> init() async {}

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final now = DateTime.now();
    if (scheduledDate.isBefore(now)) return;

    _timers[id]?.cancel();

    final duration = scheduledDate.difference(now);
    _timers[id] = Timer(duration, () {
      _pendingNotifications.add(PendingNotification(
        id: id,
        title: title,
        body: body,
      ));
    });
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
  }

  Future<void> cancelAll() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingNotifications.clear();
  }

  Future<void> scheduleReminderForSchedule({
    required String scheduleId,
    required String title,
    required DateTime startTime,
    String? description,
    String priority = 'P2',
  }) async {
    final now = DateTime.now();
    final urgency = _urgencyScore(startTime, priority);
    final minutesBefore = _reminderMinutes(urgency);

    final remindAt = startTime.subtract(Duration(minutes: minutesBefore));
    if (remindAt.isAfter(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode,
        title: '即将开始: $title',
        body: description ?? '您的日程将在${minutesBefore}分钟后开始',
        scheduledDate: remindAt,
      );
    }
    if (startTime.isAfter(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode + 1,
        title: '日程开始: $title',
        body: description ?? '您的日程现在开始',
        scheduledDate: startTime,
      );
    }
  }

  double _urgencyScore(DateTime startTime, String priority) {
    final now = DateTime.now();
    final minutesUntilStart = startTime.difference(now).inMinutes;
    if (minutesUntilStart <= 0) return 1.0;

    final priorityWeight = switch (priority) {
      'P0' => 1.0,
      'P1' => 0.7,
      'P2' => 0.4,
      _ => 0.2,
    };
    final timeFactor = minutesUntilStart <= 60
        ? 1.0
        : (120.0 / minutesUntilStart).clamp(0.1, 1.0);
    return (priorityWeight * 0.6 + timeFactor * 0.4).clamp(0.0, 1.0);
  }

  int _reminderMinutes(double urgency) {
    if (urgency > 0.8) return 120; // 2倍任务时长 -> 2小时前
    if (urgency > 0.5) return 60;  // 1倍任务时长 -> 1小时前
    if (urgency > 0.3) return 30;  // 30分钟前
    return 15; // 15分钟前
  }
}
