import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/services/notification_service.dart';

void main() {
  test('notification id is stable and offset-specific', () {
    final first = NotificationService.notificationIdForSchedule('task-1');
    final second = NotificationService.notificationIdForSchedule('task-1');
    final start = NotificationService.notificationIdForSchedule(
      'task-1',
      offset: 1,
    );

    expect(first, second);
    expect(first, isNonNegative);
    expect(start, isNot(first));
  });

  test('reminder reschedule guard handles desktop timer recovery cases', () {
    final now = DateTime(2026, 6, 2, 10);

    expect(
      NotificationService.shouldRescheduleReminder(
        reminderEnabled: true,
        startTime: now.add(const Duration(minutes: 5)),
        now: now,
      ),
      isTrue,
    );
    expect(
      NotificationService.shouldRescheduleReminder(
        reminderEnabled: false,
        startTime: now.add(const Duration(minutes: 5)),
        now: now,
      ),
      isFalse,
    );
    expect(
      NotificationService.shouldRescheduleReminder(
        reminderEnabled: true,
        startTime: now.subtract(const Duration(minutes: 5)),
        now: now,
      ),
      isFalse,
    );
    expect(
      NotificationService.shouldRescheduleReminder(
        reminderEnabled: true,
        startTime: now.subtract(const Duration(minutes: 5)),
        isRepeating: true,
        repeatInterval: 10,
        now: now,
      ),
      isTrue,
    );
  });
}
