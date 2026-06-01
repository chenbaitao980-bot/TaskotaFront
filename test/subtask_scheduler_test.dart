import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/presentation/pages/tasks/widgets/task_create_sheet.dart';
import 'package:smart_assistant/services/subtask_scheduler.dart';

void main() {
  test(
    'autoInsert shifts a directly conflicting task after inserted range',
    () {
      final start = DateTime(2026, 5, 31, 9, 54);
      final end = DateTime(2026, 5, 31, 10, 54);
      final scheduler = SubtaskScheduler(
        existingTasks: [_task('existing', start: start, end: end)],
        skipWeekends: false,
      );

      final shifts = scheduler.autoInsert(insertStart: start, insertEnd: end);

      expect(shifts, hasLength(1));
      expect(shifts.first.taskId, 'existing');
      expect(shifts.first.start, DateTime(2026, 5, 31, 11, 9));
      expect(shifts.first.end, DateTime(2026, 5, 31, 12, 9));
    },
  );

  test('autoInsert cascades shifts through later occupied slots', () {
    final scheduler = SubtaskScheduler(
      existingTasks: [
        _task(
          'first',
          start: DateTime(2026, 5, 31, 9),
          end: DateTime(2026, 5, 31, 10),
        ),
        _task(
          'second',
          start: DateTime(2026, 5, 31, 10, 30),
          end: DateTime(2026, 5, 31, 11, 30),
        ),
      ],
      skipWeekends: false,
    );

    final shifts = scheduler.autoInsert(
      insertStart: DateTime(2026, 5, 31, 9),
      insertEnd: DateTime(2026, 5, 31, 10),
    );

    expect(shifts.map((s) => s.taskId), ['first', 'second']);
    expect(shifts[0].start, DateTime(2026, 5, 31, 10, 15));
    expect(shifts[0].end, DateTime(2026, 5, 31, 11, 15));
    expect(shifts[1].start, DateTime(2026, 5, 31, 11, 30));
    expect(shifts[1].end, DateTime(2026, 5, 31, 12, 30));
  });

  test('autoInsert moves a task to next workday when the day is full', () {
    final scheduler = SubtaskScheduler(
      existingTasks: [
        _task(
          'late',
          start: DateTime(2026, 5, 31, 20),
          end: DateTime(2026, 5, 31, 21),
        ),
      ],
      skipWeekends: false,
    );

    final shifts = scheduler.autoInsert(
      insertStart: DateTime(2026, 5, 31, 20),
      insertEnd: DateTime(2026, 5, 31, 21),
    );

    expect(shifts, hasLength(1));
    expect(shifts.first.start, DateTime(2026, 6, 1, 9));
    expect(shifts.first.end, DateTime(2026, 6, 1, 10));
  });

  test('task create timing filter excludes parent and root tasks', () {
    final tasks = [
      _task(
        'parent',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 5, 18),
      ),
      _task(
        'root',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
      ),
      _task(
        'subtask',
        parentId: 'other-parent',
        start: DateTime(2026, 6, 1, 10),
        end: DateTime(2026, 6, 1, 11),
      ),
    ];

    final occupants = tasks
        .where(
          (task) => isSubtaskTimingOccupantForTaskCreateSheet(
            task,
            parentTaskId: 'parent',
          ),
        )
        .map((task) => task.id);

    expect(occupants, ['subtask']);
  });

  test('autoInsert only shifts filtered subtasks, not parent day ranges', () {
    final tasks = [
      _task(
        'parent',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 5, 18),
      ),
      _task(
        'other-subtask',
        parentId: 'other-parent',
        start: DateTime(2026, 6, 1, 9),
        end: DateTime(2026, 6, 1, 10),
      ),
    ];
    final occupants = tasks
        .where(
          (task) => isSubtaskTimingOccupantForTaskCreateSheet(
            task,
            parentTaskId: 'parent',
          ),
        )
        .toList();
    final scheduler = SubtaskScheduler(
      existingTasks: occupants,
      skipWeekends: false,
    );

    final shifts = scheduler.autoInsert(
      insertStart: DateTime(2026, 6, 1, 9),
      insertEnd: DateTime(2026, 6, 1, 10),
    );

    expect(shifts.map((shift) => shift.taskId), ['other-subtask']);
    expect(shifts.first.start, DateTime(2026, 6, 1, 10, 15));
    expect(shifts.first.end, DateTime(2026, 6, 1, 11, 15));
  });
}

Task _task(
  String id, {
  String? parentId,
  required DateTime start,
  required DateTime end,
}) {
  return Task(
    id: id,
    projectId: 'project',
    parentId: parentId,
    title: id,
    description: '',
    priority: 0,
    status: 0,
    startDate: start.millisecondsSinceEpoch,
    dueDate: end.millisecondsSinceEpoch,
    isAllDay: 0,
    sortOrder: 0,
    deleted: 0,
    createdAt: 0,
    updatedAt: 0,
    remindBeforeMinutes: 15,
    reminderEnabled: 1,
  );
}
