import '../data/database/app_database.dart';
import '../data/repositories/task_repository.dart';
import 'subtask_scheduler.dart';

enum ConflictChoice { cancel, parallel, autoDelay, autoInsert }

class ConflictInfo {
  final String title;
  final DateTime start;
  final DateTime end;
  final DateTime conflictEnd;
  const ConflictInfo({
    required this.title,
    required this.start,
    required this.end,
    required this.conflictEnd,
  });
}

class TaskConflictService {
  final TaskRepository taskRepository;

  const TaskConflictService({required this.taskRepository});

  static bool isTimingOccupant(Task t, {String? excludeParentId}) {
    if (t.startDate == null || t.dueDate == null) return false;
    if (t.status == 2 || t.deleted != 0) return false;
    if (excludeParentId != null && t.id == excludeParentId) return false;
    if (_isMultiDay(t)) return false;
    return true;
  }

  static bool _isMultiDay(Task t) {
    if (t.startDate == null || t.dueDate == null) return false;
    final s = DateTime.fromMillisecondsSinceEpoch(t.startDate!);
    final e = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
    return !(s.year == e.year && s.month == e.month && s.day == e.day);
  }

  static bool isRangeMultiDay(DateTime start, DateTime end) {
    return !(start.year == end.year &&
        start.month == end.month &&
        start.day == end.day);
  }

  Future<ConflictInfo?> checkConflict(
    DateTime newStart,
    DateTime newEnd, {
    String? excludeTaskId,
    String? excludeParentId,
  }) async {
    final all = await taskRepository.getAll();
    for (final t in all.where(
      (t) => isTimingOccupant(t, excludeParentId: excludeParentId),
    )) {
      if (excludeTaskId != null && t.id == excludeTaskId) continue;
      final s = DateTime.fromMillisecondsSinceEpoch(t.startDate!);
      final e = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
      if (s.isBefore(newEnd) && e.isAfter(newStart)) {
        return ConflictInfo(title: t.title, start: s, end: e, conflictEnd: e);
      }
    }
    return null;
  }

  Future<ScheduledSlot?> calcDelayedSlot(
    DateTime start,
    DateTime end,
    DateTime from, {
    String? excludeTaskId,
    String? excludeParentId,
  }) async {
    final duration = end.difference(start).inMinutes.clamp(1, 480);
    final all = await taskRepository.getAll();
    final occupants = all
        .where(
          (t) => isTimingOccupant(t, excludeParentId: excludeParentId),
        )
        .where((t) => excludeTaskId == null || t.id != excludeTaskId)
        .toList();
    final scheduler = SubtaskScheduler(
      existingTasks: occupants,
      skipWeekends: false,
    );
    final slots = scheduler.scheduleLeaves([
      LeafToSchedule(taskId: 'tmp', minutes: duration),
    ], from: from);
    return slots.isNotEmpty ? slots.first : null;
  }

  Future<List<ScheduledTaskShift>> calcInsertedShifts(
    DateTime start,
    DateTime end, {
    String? excludeTaskId,
    String? excludeParentId,
  }) async {
    final all = await taskRepository.getAll();
    final occupants = all
        .where(
          (t) => isTimingOccupant(t, excludeParentId: excludeParentId),
        )
        .where((t) => excludeTaskId == null || t.id != excludeTaskId)
        .toList();
    final scheduler = SubtaskScheduler(
      existingTasks: occupants,
      skipWeekends: false,
    );
    return scheduler.autoInsert(insertStart: start, insertEnd: end);
  }
}
