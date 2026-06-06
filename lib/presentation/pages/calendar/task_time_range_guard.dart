import '../../../data/database/app_database.dart';

class TaskTimeRange {
  final DateTime start;
  final DateTime end;

  const TaskTimeRange({required this.start, required this.end});
}

TaskTimeRange? descendantTaskTimeRange({
  required Task parent,
  required Iterable<Task> tasks,
}) {
  final childrenByParent = <String, List<Task>>{};
  for (final task in tasks) {
    final parentId = task.parentId;
    if (parentId == null || task.deleted != 0) continue;
    childrenByParent.putIfAbsent(parentId, () => <Task>[]).add(task);
  }

  DateTime? earliest;
  DateTime? latest;
  final queue = <String>[parent.id];
  final visited = <String>{parent.id};

  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    for (final child in childrenByParent[current] ?? const <Task>[]) {
      if (!visited.add(child.id)) continue;
      final range = taskTimeRange(child);
      if (range != null) {
        if (earliest == null || range.start.isBefore(earliest)) {
          earliest = range.start;
        }
        if (latest == null || range.end.isAfter(latest)) {
          latest = range.end;
        }
      }
      queue.add(child.id);
    }
  }

  if (earliest == null || latest == null) return null;
  return TaskTimeRange(start: earliest, end: latest);
}

TaskTimeRange? taskTimeRange(Task task) {
  final startMillis = task.startDate;
  final endMillis = task.dueDate;
  if (startMillis == null && endMillis == null) return null;

  final start = DateTime.fromMillisecondsSinceEpoch(startMillis ?? endMillis!);
  final end = DateTime.fromMillisecondsSinceEpoch(endMillis ?? startMillis!);
  if (end.isBefore(start)) {
    return TaskTimeRange(start: end, end: start);
  }
  return TaskTimeRange(start: start, end: end);
}
