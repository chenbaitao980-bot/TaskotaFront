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
    // 进度计算排除已归档任务
    final activeTasks = tasks.where((t) => t.archived == 0).toList();
    final childrenByParent = <String, List<Task>>{};
    for (final task in activeTasks) {
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

      final children = childrenByParent[task.id] ?? const <Task>[];
      final items = itemsByTask[task.id] ?? const <ChecklistItem>[];
      var tally = children.isEmpty
          ? _leafTally(task, items)
          : const _ProgressTally(0, 0); // 有子任务时进度由子任务决定
      for (final child in children) {
        tally += tallyForTask(child, visiting);
      }
      visiting.remove(task.id);
      memo[task.id] = tally;
      return tally;
    }

    final taskProgress = <String, int>{};
    for (final task in activeTasks) {
      taskProgress[task.id] = tallyForTask(task, <String>{}).percent;
    }

    // 项目进度：只累加根任务，每个根任务贡献其递归进度（已含子任务聚合）
    final projectTotals = <String, _ProgressTally>{};
    for (final task in activeTasks) {
      if (task.parentId != null) continue; // 跳过子任务，避免重复计入
      projectTotals[task.projectId] =
          (projectTotals[task.projectId] ?? const _ProgressTally(0, 0)) +
          tallyForTask(task, <String>{});
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

  static _ProgressTally _leafTally(
    Task task,
    List<ChecklistItem> checklistItems,
  ) {
    if (task.status == 2) return const _ProgressTally(1, 1);
    final completedItems = checklistItems.where((item) => item.status == 1).length;
    return _ProgressTally(completedItems, 1 + checklistItems.length);
  }

  /// 有子任务时，仅统计检查项贡献（无检查项则贡献 0/0，不影响子任务计算）
  static _ProgressTally _checklistTally(List<ChecklistItem> checklistItems) {
    if (checklistItems.isEmpty) return const _ProgressTally(0, 0);
    return _ProgressTally(
      checklistItems.where((item) => item.status == 1).length,
      checklistItems.length,
    );
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
}
