import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/presentation/pages/calendar/task_time_range_guard.dart';

void main() {
  test('descendantTaskTimeRange includes nested child task ranges', () {
    final parent = _task('parent');
    final range = descendantTaskTimeRange(
      parent: parent,
      tasks: [
        parent,
        _task(
          'child',
          parentId: 'parent',
          start: DateTime(2026, 6, 2, 9),
          end: DateTime(2026, 6, 2, 10),
        ),
        _task(
          'grandchild',
          parentId: 'child',
          start: DateTime(2026, 6, 3, 14),
          end: DateTime(2026, 6, 3, 15),
        ),
      ],
    );

    expect(range?.start, DateTime(2026, 6, 2, 9));
    expect(range?.end, DateTime(2026, 6, 3, 15));
  });

  test('descendantTaskTimeRange ignores deleted and undated descendants', () {
    final parent = _task('parent');
    final range = descendantTaskTimeRange(
      parent: parent,
      tasks: [
        parent,
        _task('undated', parentId: 'parent'),
        _task(
          'deleted',
          parentId: 'parent',
          deleted: 1,
          start: DateTime(2026, 6, 1),
          end: DateTime(2026, 6, 5),
        ),
        _task(
          'active',
          parentId: 'parent',
          start: DateTime(2026, 6, 2),
          end: DateTime(2026, 6, 2, 1),
        ),
      ],
    );

    expect(range?.start, DateTime(2026, 6, 2));
    expect(range?.end, DateTime(2026, 6, 2, 1));
  });

  test('parent range can be checked against descendant range', () {
    final parent = _task('parent');
    final range = descendantTaskTimeRange(
      parent: parent,
      tasks: [
        parent,
        _task(
          'child',
          parentId: 'parent',
          start: DateTime(2026, 6, 2, 9),
          end: DateTime(2026, 6, 2, 10),
        ),
      ],
    )!;

    final covers =
        !DateTime(2026, 6, 1).isAfter(range.start) &&
        !DateTime(2026, 6, 3).isBefore(range.end);
    final shrunkTooFar =
        !DateTime(2026, 6, 1).isAfter(range.start) &&
        !DateTime(2026, 6, 1, 23, 59).isBefore(range.end);

    expect(covers, isTrue);
    expect(shrunkTooFar, isFalse);
  });
}

Task _task(
  String id, {
  String? parentId,
  DateTime? start,
  DateTime? end,
  int deleted = 0,
}) {
  return Task(
    id: id,
    projectId: 'project',
    parentId: parentId,
    title: id,
    description: '',
    priority: 0,
    status: 0,
    startDate: start?.millisecondsSinceEpoch,
    dueDate: end?.millisecondsSinceEpoch,
    isAllDay: 0,
    sortOrder: 0,
    deleted: deleted,
    archived: 0,
    createdAt: 0,
    updatedAt: 0,
    remindBeforeMinutes: 15,
    reminderEnabled: 1,
  );
}
