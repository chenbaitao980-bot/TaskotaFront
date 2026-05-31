import '../data/database/app_database.dart';

class LeafToSchedule {
  final String taskId;
  final int minutes;
  const LeafToSchedule({required this.taskId, required this.minutes});
}

class ScheduledSlot {
  final String taskId;
  final DateTime start;
  final DateTime end;
  const ScheduledSlot({
    required this.taskId,
    required this.start,
    required this.end,
  });
}

class ScheduledTaskShift {
  final String taskId;
  final DateTime start;
  final DateTime end;
  const ScheduledTaskShift({
    required this.taskId,
    required this.start,
    required this.end,
  });
}

class SubtaskScheduler {
  static const int workStartHour = 9;
  static const int workEndHour = 21;
  static const int snapMinutes = 5;
  static const int bufferMinutes = 15;

  final bool skipWeekends;
  final List<_Range> _occupied;

  SubtaskScheduler({
    required List<Task> existingTasks,
    required this.skipWeekends,
    Set<String>? ignoreTaskIds,
  }) : _occupied = _buildOccupiedRanges(
         existingTasks,
         ignoreTaskIds ?? const {},
       );

  static List<_Range> _buildOccupiedRanges(
    List<Task> tasks,
    Set<String> ignoreIds,
  ) {
    final ranges = <_Range>[];
    for (final t in tasks) {
      if (ignoreIds.contains(t.id)) continue;
      if (t.status == 2 || t.deleted != 0) continue;
      if (t.startDate == null || t.dueDate == null) continue;
      final s = DateTime.fromMillisecondsSinceEpoch(t.startDate!);
      final e = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
      if (!e.isAfter(s)) continue;
      ranges.add(_Range(s, e, taskId: t.id));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  List<ScheduledSlot> scheduleLeaves(
    List<LeafToSchedule> leaves, {
    DateTime? from,
  }) {
    final result = <ScheduledSlot>[];
    DateTime cursor = _alignToWorkStart(from ?? DateTime.now());

    for (final leaf in leaves) {
      final remain = leaf.minutes.clamp(1, 480);
      DateTime placed;
      while (true) {
        cursor = _alignToWorkStart(cursor);
        final dayEnd = DateTime(
          cursor.year,
          cursor.month,
          cursor.day,
          workEndHour,
        );
        final availableMin = dayEnd.difference(cursor).inMinutes;
        if (availableMin <= 0) {
          cursor = _nextDayWorkStart(cursor);
          continue;
        }
        final candidateEnd = cursor.add(Duration(minutes: remain));
        if (candidateEnd.isAfter(dayEnd)) {
          cursor = _nextDayWorkStart(cursor);
          continue;
        }
        final conflict = _firstConflict(cursor, candidateEnd);
        if (conflict != null) {
          cursor = _alignSnap(
            conflict.end.add(const Duration(minutes: bufferMinutes)),
          );
          continue;
        }
        placed = candidateEnd;
        result.add(
          ScheduledSlot(taskId: leaf.taskId, start: cursor, end: placed),
        );
        _occupied.add(_Range(cursor, placed));
        _occupied.sort((a, b) => a.start.compareTo(b.start));
        cursor = _alignSnap(placed.add(const Duration(minutes: bufferMinutes)));
        break;
      }
    }
    return result;
  }

  List<ScheduledTaskShift> autoInsert({
    required DateTime insertStart,
    required DateTime insertEnd,
  }) {
    if (!insertEnd.isAfter(insertStart)) return const [];

    final shifts = <ScheduledTaskShift>[];
    final occupied = <_Range>[_Range(insertStart, insertEnd)];
    final tasks = _occupied.where((r) => r.taskId != null).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    for (final taskRange in tasks) {
      final conflict = _firstConflictIn(
        occupied,
        taskRange.start,
        taskRange.end,
      );
      if (conflict == null) {
        occupied.add(taskRange);
        occupied.sort((a, b) => a.start.compareTo(b.start));
        continue;
      }

      final duration = taskRange.end
          .difference(taskRange.start)
          .inMinutes
          .clamp(1, 480);
      final placed = _findSlotIn(
        occupied,
        from: conflict.end.add(const Duration(minutes: bufferMinutes)),
        minutes: duration,
      );
      shifts.add(
        ScheduledTaskShift(
          taskId: taskRange.taskId!,
          start: placed.start,
          end: placed.end,
        ),
      );
      occupied.add(_Range(placed.start, placed.end, taskId: taskRange.taskId));
      occupied.sort((a, b) => a.start.compareTo(b.start));
    }

    return shifts;
  }

  _Range? _firstConflict(DateTime s, DateTime e) {
    return _firstConflictIn(_occupied, s, e);
  }

  _Range? _firstConflictIn(List<_Range> ranges, DateTime s, DateTime e) {
    for (final r in ranges) {
      if (!r.end.isAfter(s)) continue;
      if (!r.start.isBefore(e)) break;
      return r;
    }
    return null;
  }

  ({DateTime start, DateTime end}) _findSlotIn(
    List<_Range> ranges, {
    required DateTime from,
    required int minutes,
  }) {
    var cursor = _alignToWorkWindow(from);
    while (true) {
      cursor = _alignToWorkWindow(cursor);
      final dayEnd = DateTime(
        cursor.year,
        cursor.month,
        cursor.day,
        workEndHour,
      );
      final candidateEnd = cursor.add(Duration(minutes: minutes));
      if (candidateEnd.isAfter(dayEnd)) {
        cursor = _nextDayWorkStart(cursor);
        continue;
      }
      final conflict = _firstConflictIn(ranges, cursor, candidateEnd);
      if (conflict != null) {
        cursor = _alignToWorkWindow(
          conflict.end.add(const Duration(minutes: bufferMinutes)),
        );
        continue;
      }
      return (start: cursor, end: candidateEnd);
    }
  }

  DateTime _alignSnap(DateTime t) {
    final m = t.minute;
    final snapped = ((m + snapMinutes - 1) ~/ snapMinutes) * snapMinutes;
    if (snapped >= 60) {
      return DateTime(t.year, t.month, t.day, t.hour + 1);
    }
    return DateTime(t.year, t.month, t.day, t.hour, snapped);
  }

  DateTime _alignToWorkStart(DateTime t) {
    DateTime cur = _alignSnap(t);
    return _alignToWorkWindow(cur);
  }

  DateTime _alignToWorkWindow(DateTime t) {
    DateTime cur = t;
    while (true) {
      if (skipWeekends &&
          (cur.weekday == DateTime.saturday ||
              cur.weekday == DateTime.sunday)) {
        cur = _nextDayWorkStart(cur);
        continue;
      }
      if (cur.hour < workStartHour) {
        cur = DateTime(cur.year, cur.month, cur.day, workStartHour);
        continue;
      }
      if (cur.hour >= workEndHour) {
        cur = _nextDayWorkStart(cur);
        continue;
      }
      return cur;
    }
  }

  DateTime _nextDayWorkStart(DateTime t) {
    final next = DateTime(t.year, t.month, t.day).add(const Duration(days: 1));
    return DateTime(next.year, next.month, next.day, workStartHour);
  }
}

class _Range {
  final DateTime start;
  final DateTime end;
  final String? taskId;
  _Range(this.start, this.end, {this.taskId});
}

Map<String, ({DateTime start, DateTime end})> computeParentSpans({
  required Map<String, List<String>> parentToLeafIds,
  required List<ScheduledSlot> slots,
}) {
  final byId = {for (final s in slots) s.taskId: s};
  final out = <String, ({DateTime start, DateTime end})>{};
  parentToLeafIds.forEach((parentId, leafIds) {
    DateTime? minStart;
    DateTime? maxEnd;
    for (final lid in leafIds) {
      final s = byId[lid];
      if (s == null) continue;
      if (minStart == null || s.start.isBefore(minStart)) minStart = s.start;
      if (maxEnd == null || s.end.isAfter(maxEnd)) maxEnd = s.end;
    }
    if (minStart == null || maxEnd == null) return;
    final startDay = DateTime(minStart.year, minStart.month, minStart.day);
    final endDay = DateTime(maxEnd.year, maxEnd.month, maxEnd.day, 23, 59, 59);
    out[parentId] = (start: startDay, end: endDay);
  });
  return out;
}
