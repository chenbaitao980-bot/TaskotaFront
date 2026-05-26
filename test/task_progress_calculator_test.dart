import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/domain/tasks/task_progress_calculator.dart';

void main() {
  test('leaf task progress follows checklist completion', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [_task('task')],
      checklistItems: [
        _item('item-1', 'task', status: 1),
        _item('item-2', 'task', status: 1),
        _item('item-3', 'task'),
        _item('item-4', 'task'),
      ],
    );

    expect(snapshot.taskProgress['task'], 50);
    expect(snapshot.projectProgress['project'], 50);
  });

  test('completed leaf task overrides incomplete checklist progress', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [_task('task', status: 2)],
      checklistItems: [
        _item('item-1', 'task', status: 1),
        _item('item-2', 'task'),
      ],
    );

    expect(snapshot.taskProgress['task'], 100);
    expect(snapshot.projectProgress['project'], 100);
  });

  test('leaf task without checklist follows task completion status', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [_task('pending'), _task('done', status: 2)],
      checklistItems: const [],
    );

    expect(snapshot.taskProgress['pending'], 0);
    expect(snapshot.taskProgress['done'], 100);
    expect(snapshot.projectProgress['project'], 50);
  });

  test('parent task recursively includes self and descendant work units', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [
        _task('parent'),
        _task('done-child', parentId: 'parent', status: 2),
        _task('pending-child', parentId: 'parent'),
        _task('checklist-child', parentId: 'parent'),
      ],
      checklistItems: [
        _item('child-item-1', 'checklist-child', status: 1),
        _item('child-item-2', 'checklist-child'),
      ],
    );

    expect(snapshot.taskProgress['parent'], 40);
    expect(snapshot.projectProgress['project'], 38);
  });

  test('project progress counts each work unit once', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [
        _task('parent'),
        _task('child', parentId: 'parent', status: 2),
      ],
      checklistItems: const [],
    );

    expect(snapshot.taskProgress['parent'], 50);
    expect(snapshot.taskProgress['child'], 100);
    expect(snapshot.projectProgress['project'], 50);
  });

  test('project progress does not overweight checklist item count', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [
        _task('parent', status: 2),
        _task('child', parentId: 'parent', status: 2),
        _task('other'),
      ],
      checklistItems: [
        _item('other-item-1', 'other'),
        _item('other-item-2', 'other'),
        _item('other-item-3', 'other'),
      ],
    );

    expect(snapshot.taskProgress['parent'], 100);
    expect(snapshot.taskProgress['child'], 100);
    expect(snapshot.taskProgress['other'], 0);
    expect(snapshot.projectProgress['project'], 67);
  });

  test('completed parent overrides descendant progress for project total', () {
    final snapshot = TaskProgressCalculator.calculate(
      tasks: [
        _task('parent', status: 2),
        _task('child', parentId: 'parent', status: 2),
      ],
      checklistItems: [
        _item('child-item-1', 'child', status: 1),
        _item('child-item-2', 'child'),
      ],
    );

    expect(snapshot.taskProgress['parent'], 100);
    expect(snapshot.taskProgress['child'], 100);
    expect(snapshot.projectProgress['project'], 100);
  });
}

Task _task(
  String id, {
  String projectId = 'project',
  String? parentId,
  int status = 0,
}) {
  return Task(
    id: id,
    projectId: projectId,
    parentId: parentId,
    title: id,
    description: '',
    priority: 0,
    status: status,
    isAllDay: 0,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
  );
}

ChecklistItem _item(String id, String taskId, {int status = 0}) {
  return ChecklistItem(
    id: id,
    taskId: taskId,
    title: id,
    status: status,
    sortOrder: 0,
    createdAt: 0,
    updatedAt: 0,
  );
}
