import '../data/database/app_database.dart';

/// 一个待排程的叶子任务输入
class LeafToSchedule {
  final String taskId;
  final int minutes;
  const LeafToSchedule({required this.taskId, required this.minutes});
}

/// 排程结果（单条）
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

/// 子任务排程器：把叶子按顺序排到 9:00–21:00 工作时段，
/// 15 分钟缓冲，5 分钟吸附，避让 [occupied] 中已占用区间，
/// skipWeekends=true 时整天跳过周六/周日。
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
  }) : _occupied = _buildOccupiedRanges(existingTasks, ignoreTaskIds ?? const {});

  static List<_Range> _buildOccupiedRanges(
      List<Task> tasks, Set<String> ignoreIds) {
    final ranges = <_Range>[];
    for (final t in tasks) {
      if (ignoreIds.contains(t.id)) continue;
      if (t.startDate == null || t.dueDate == null) continue;
      final s = DateTime.fromMillisecondsSinceEpoch(t.startDate!);
      final e = DateTime.fromMillisecondsSinceEpoch(t.dueDate!);
      if (!e.isAfter(s)) continue;
      ranges.add(_Range(s, e));
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    return ranges;
  }

  /// 按顺序排程所有叶子。从 `from` 开始（默认 now）。
  List<ScheduledSlot> scheduleLeaves(
    List<LeafToSchedule> leaves, {
    DateTime? from,
  }) {
    final result = <ScheduledSlot>[];
    DateTime cursor = _alignToWorkStart(from ?? DateTime.now());

    for (final leaf in leaves) {
      int remain = leaf.minutes.clamp(1, 480);
      // 单段不允许跨日：循环直到找到当日能放下的窗口
      DateTime placed;
      while (true) {
        cursor = _alignToWorkStart(cursor);
        final dayEnd = DateTime(
            cursor.year, cursor.month, cursor.day, workEndHour, 0);
        final availableMin = dayEnd.difference(cursor).inMinutes;
        if (availableMin <= 0) {
          cursor = _nextDayWorkStart(cursor);
          continue;
        }
        // 检测从 cursor 起的 [cursor, cursor+remain] 是否被 occupied 阻挡
        final candidateEnd = cursor.add(Duration(minutes: remain));
        if (candidateEnd.isAfter(dayEnd)) {
          // 当日剩余不够，整段推到次日
          cursor = _nextDayWorkStart(cursor);
          continue;
        }
        final conflict = _firstConflict(cursor, candidateEnd);
        if (conflict != null) {
          // 跳到冲突结束 + 缓冲，再吸附
          cursor = _alignSnap(conflict.end.add(const Duration(minutes: bufferMinutes)));
          continue;
        }
        placed = candidateEnd;
        result.add(ScheduledSlot(
          taskId: leaf.taskId,
          start: cursor,
          end: placed,
        ));
        // 占位加入 occupied 防止后续叶子撞它
        _occupied.add(_Range(cursor, placed));
        _occupied.sort((a, b) => a.start.compareTo(b.start));
        // 移动 cursor
        cursor = _alignSnap(placed.add(const Duration(minutes: bufferMinutes)));
        break;
      }
    }
    return result;
  }

  /// 在已占用区间中找第一个与 [s, e) 相交的
  _Range? _firstConflict(DateTime s, DateTime e) {
    for (final r in _occupied) {
      if (!r.end.isAfter(s)) continue; // 完全在前
      if (!r.start.isBefore(e)) break; // 后续都在后（已排序）
      return r;
    }
    return null;
  }

  DateTime _alignSnap(DateTime t) {
    final m = t.minute;
    final snapped = ((m + snapMinutes - 1) ~/ snapMinutes) * snapMinutes;
    if (snapped >= 60) {
      return DateTime(t.year, t.month, t.day, t.hour + 1, 0);
    }
    return DateTime(t.year, t.month, t.day, t.hour, snapped);
  }

  DateTime _alignToWorkStart(DateTime t) {
    DateTime cur = _alignSnap(t);
    while (true) {
      if (skipWeekends && (cur.weekday == DateTime.saturday ||
          cur.weekday == DateTime.sunday)) {
        cur = _nextDayWorkStart(cur);
        continue;
      }
      if (cur.hour < workStartHour) {
        cur = DateTime(cur.year, cur.month, cur.day, workStartHour, 0);
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
    return DateTime(next.year, next.month, next.day, workStartHour, 0);
  }
}

class _Range {
  final DateTime start;
  final DateTime end;
  _Range(this.start, this.end);
}

/// 给定一个 DFS 顺序的叶子排程结果，计算每个父任务节点的
/// (start=最早叶子的当日 00:00, end=最晚叶子的当日 23:59:59)。
/// 输入 `parentToLeafIds`：每个父任务 id → 所有叶子后代 id 列表
/// 输入 `slots`：所有叶子的排程结果
/// 返回 `{parentId: (start, end)}`
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
    // 强制跨天：start = 当日 00:00，end = 当日 23:59
    final startDay = DateTime(minStart.year, minStart.month, minStart.day);
    final endDay = DateTime(maxEnd.year, maxEnd.month, maxEnd.day,
        23, 59, 59);
    out[parentId] = (start: startDay, end: endDay);
  });
  return out;
}
