import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/services/task_sync_service.dart';

void main() {
  test('task sync row preserves parent id for subtasks', () {
    final task = _task(parentId: 'parent-1');

    final row = TaskSyncService.taskToSyncRow(task, userId: 'user-1');

    expect(row['user_id'], 'user-1');
    expect(row['parent_id'], 'parent-1');
  });

  test('task sync row maps parent_id back to parentId', () {
    final json = TaskSyncService.syncRowToTaskJson({
      'id': 'child-1',
      'deleted': 0,
      'project_id': 'project-1',
      'parent_id': 'parent-1',
      'title': 'Child',
      'description': '',
      'priority': 0,
      'status': 0,
      'start_date': null,
      'due_date': null,
      'is_all_day': 0,
      'completed_time': null,
      'sort_order': 0,
      'remind_before_minutes': 15,
      'reminder_enabled': 1,
      'estimated_minutes': null,
      'created_at': 1,
      'updated_at': 2,
    });

    expect(json['parentId'], 'parent-1');
    expect(json['projectId'], 'project-1');
  });

  test('task sync row preserves reminder settings', () {
    final task = _task(remindBeforeMinutes: 30, reminderEnabled: 0);

    final row = TaskSyncService.taskToSyncRow(task, userId: 'user-1');
    final json = TaskSyncService.syncRowToTaskJson(row);

    expect(row['remind_before_minutes'], 30);
    expect(row['reminder_enabled'], 0);
    expect(json['remindBeforeMinutes'], 30);
    expect(json['reminderEnabled'], 0);
  });
}

Task _task({
  String? parentId,
  int remindBeforeMinutes = 15,
  int reminderEnabled = 1,
}) {
  return Task(
    id: 'child-1',
    projectId: 'project-1',
    parentId: parentId,
    title: 'Child',
    description: '',
    priority: 0,
    status: 0,
    isAllDay: 0,
    sortOrder: 0,
    deleted: 0,
    createdAt: 1,
    updatedAt: 2,
    remindBeforeMinutes: remindBeforeMinutes,
    reminderEnabled: reminderEnabled,
  );
}
