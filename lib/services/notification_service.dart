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
  }) async {
    final now = DateTime.now();
    final fifteenMinBefore = startTime.subtract(const Duration(minutes: 15));
    if (fifteenMinBefore.isAfter(now)) {
      await scheduleNotification(
        id: scheduleId.hashCode,
        title: '即将开始: $title',
        body: description ?? '您的日程将在15分钟后开始',
        scheduledDate: fifteenMinBefore,
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
}
