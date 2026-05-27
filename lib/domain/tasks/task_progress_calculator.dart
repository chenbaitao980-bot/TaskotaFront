import '../../data/database/app_database.dart';

class TaskProgressSnapshot {
  final Map<String, int> taskProgress;
  final Map<String, int> projectProgress;
  final Map<String, int> groupProgress;

  const TaskProgressSnapshot({
    required this.taskProgress,
    required this.projectProgress,
    this.groupProgress = const {},
  });
}

class TaskProgressCalculator {
  static TaskProgressSnapshot calculate({
    required List<Task> tasks,
    required List<ChecklistItem> checklistItems,
    List<Project> projects = const [],
  }) {
    final childrenByParent = <String, List<Task>>{};
    for (final task in tasks) {
      final parentId = task.parentId;
      if (parentId == null) continue;
      childrenByParent.putIfAbsent(parentId, () => []).add(task);
    }

    final itemsByTask = <String, List<ChecklistItem>>{};
    for (final item in checklistItems) {
      itemsByTask.putIfAbsent(item.taskId, () => []).add(item);
    }

    final memo = <String, _ProgressTally>{};
    _ProgressTally tallyForTask(Task task, Set<String> visiting) {
      final cached = memo[task.id];
      if (cached != null) return cached;
      if (!visiting.add(task.id)) return const _ProgressTally(0, 0);

      var tally = _ownTally(task, itemsByTask[task.id] ?? const []);
      for (final child in childrenByParent[task.id] ?? const <Task>[]) {
        tally += tallyForTask(child, visiting);
      }
      if (task.status == 2) {
        tally = tally.asCompleted;
      }

      visiting.remove(task.id);
      memo[task.id] = tally;
      return tally;
    }

    final taskProgress = <String, int>{};
    for (final task in tasks) {
      taskProgress[task.id] = tallyForTask(task, <String>{}).percent;
    }

    final projectTotals = <String, _ProgressTally>{};
    for (final task in tasks) {
      projectTotals[task.projectId] =
          (projectTotals[task.projectId] ?? const _ProgressTally(0, 0)) +
          _projectUnitTally(task, itemsByTask[task.id] ?? const []);
    }

    final projectProgress = <String, int>{
      for (final entry in projectTotals.entries) entry.key: entry.value.percent,
    };

    // 组进度：把同 groupId 的项目 tally 累加
    final groupTotals = <String, _ProgressTally>{};
    for (final p in projects) {
      final gid = p.groupId;
      if (gid == null) continue;
      final t = projectTotals[p.id] ?? const _ProgressTally(0, 0);
      groupTotals[gid] = (groupTotals[gid] ?? const _ProgressTally(0, 0)) + t;
    }
    final groupProgress = <String, int>{
      for (final e in groupTotals.entries) e.key: e.value.percent,
    };

    return TaskProgressSnapshot(
      taskProgress: taskProgress,
      projectProgress: projectProgress,
      groupProgress: groupProgress,
    );
  }

  static _ProgressTally _ownTally(
    Task task,
    List<ChecklistItem> checklistItems,
  ) {
    if (checklistItems.isEmpty) {
      return _ProgressTally(task.status == 2 ? 1 : 0, 1);
    }

    return _ProgressTally(
      checklistItems.where((item) => item.status == 1).length,
      checklistItems.length,
    );
  }

  static _ProgressTally _projectUnitTally(
    Task task,
    List<ChecklistItem> checklistItems,
  ) {
    if (task.status == 2) {
      return const _ProgressTally(100, 100);
    }

    if (checklistItems.isEmpty) {
      return const _ProgressTally(0, 100);
    }

    final completed = checklistItems.where((item) => item.status == 1).length;
    final percent = ((completed / checklistItems.length) * 100).round();
    return _ProgressTally(percent, 100);
  }
}

class _ProgressTally {
  final int completed;
  final int total;

  const _ProgressTally(this.completed, this.total);

  int get percent {
    if (total == 0) return 0;
    return ((completed / total) * 100).round().clamp(0, 100).toInt();
  }

  _ProgressTally operator +(_ProgressTally other) {
    return _ProgressTally(completed + other.completed, total + other.total);
  }

  _ProgressTally get asCompleted => _ProgressTally(total, total);
}
