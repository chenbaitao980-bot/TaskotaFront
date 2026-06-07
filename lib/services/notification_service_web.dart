import '../models/entities/schedule.dart';
import '../data/database/app_database.dart' show Task;
import '../models/entities/task_breakdown.dart';

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

  static String? pendingTaskId;

  List<String> get diagnosticLog => const [];
  String get diagnosticSummary => '';

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
    if (isRepeating && repeatInterval != null && repeatInterval > 0) return true;
    return !startTime.isBefore(now ?? DateTime.now());
  }

  Future<void> init() async {}

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {}

  Future<void> scheduleRepeatingNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstFireAt,
    required int intervalMs,
  }) async {}

  Future<bool> checkMobilePermissions() async => false;

  Future<bool> requestMobilePermissions() async => false;

  Future<bool> showImmediateTestNotification() async => false;

  Future<bool> checkExactAlarmPermission() async => false;

  Future<void> scheduleReminderForSchedule({
    required String scheduleId,
    required String title,
    required DateTime startTime,
    String? description,
    String priority = 'P2',
    int remindBeforeMinutes = 15,
    bool isRepeating = false,
    int? repeatInterval,
  }) async {}

  Future<void> cancelReminderForSchedule(String scheduleId) async {}

  Future<void> rescheduleTaskReminders(Iterable<Task> tasks) async {}

  Future<void> rescheduleBreakdownTaskReminders(
    Iterable<TaskBreakdown> tasks,
  ) async {}

  Future<void> rescheduleScheduleReminders(Iterable<Schedule> schedules) async {}

  List<PendingNotification> consumePending() => [];

  Future<void> cancelNotification(int id) async {}

  Future<void> cancelAll() async {}
}
