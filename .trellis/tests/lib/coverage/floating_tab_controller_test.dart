import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';
import 'package:smart_assistant/data/database/app_database.dart';

Task _buildTask({
  required String id,
  int status = 0,
  DateTime? start,
  DateTime? due,
  int isAllDay = 0,
  int updatedAt = 0,
  String? parentId,
}) {
  return Task(
    id: id,
    projectId: 'p1',
    parentId: parentId,
    title: '任务$id',
    description: '',
    priority: 3,
    status: status,
    startDate: start?.millisecondsSinceEpoch,
    dueDate: due?.millisecondsSinceEpoch,
    isAllDay: isAllDay,
    completedTime: null,
    sortOrder: 0,
    deleted: 0,
    createdAt: 0,
    updatedAt: updatedAt,
    remindBeforeMinutes: 15,
    reminderEnabled: 1,
    estimatedMinutes: null,
    archived: 0,
  );
}

void main() {
  final now = DateTime(2026, 8, 3, 12, 0);

  group('anchorDateOf', () {
    test('startDate 优先于 dueDate', () {
      final t = _buildTask(
        id: 'a',
        start: DateTime(2026, 8, 4),
        due: DateTime(2026, 8, 5),
      );
      expect(
        DesktopFloatingTabController.anchorDateOf(t, now),
        DateTime(2026, 8, 4),
      );
    });

    test('无 startDate 用 dueDate', () {
      final t = _buildTask(id: 'a', due: DateTime(2026, 8, 5));
      expect(
        DesktopFloatingTabController.anchorDateOf(t, now),
        DateTime(2026, 8, 5),
      );
    });

    test('都无则返回 now', () {
      final t = _buildTask(id: 'a');
      expect(DesktopFloatingTabController.anchorDateOf(t, now), now);
    });
  });

  group('rankCandidates 分层规则', () {
    test('层①小时级任务优先于层②跨天任务，即使跨天时间更近', () {
      final tHour = _buildTask(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 2)),
      );
      final tMulti = _buildTask(
        id: 'multi',
        status: 0,
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 2)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tMulti, tHour],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour', 'multi']);
    });

    test('层①内进行中优先于待办', () {
      final tPending = _buildTask(
        id: 'pending',
        status: 0,
        start: now,
      );
      final tInProgress = _buildTask(
        id: 'inprog',
        status: 1,
        start: now.add(const Duration(days: 1)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tPending, tInProgress],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['inprog', 'pending']);
    });

    test('无 startDate 的任务不进入排序（被剔除）', () {
      final tNoStart = _buildTask(id: 'nostart', status: 0);
      final tHour = _buildTask(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 1)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tNoStart, tHour],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour']);
    });

    test('层内距 now 最近，平局取 updatedAt 最新', () {
      final t1 = _buildTask(
        id: 't1',
        status: 0,
        start: now.add(const Duration(days: 1)),
        updatedAt: 100,
      );
      final t2 = _buildTask(
        id: 't2',
        status: 0,
        start: now.add(const Duration(days: 1)),
        updatedAt: 200,
      );
      final t3 = _buildTask(
        id: 't3',
        status: 0,
        start: now.add(const Duration(days: 3)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [t3, t1, t2],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['t2', 't1', 't3']);
    });

    test('全天任务归层②，排在小时级任务之后', () {
      final tAllDay = _buildTask(
        id: 'allday',
        status: 0,
        start: now.add(const Duration(days: 1)),
        isAllDay: 1,
      );
      final tHour = _buildTask(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 2)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tAllDay, tHour],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour', 'allday']);
    });

    test('跨天层内仍进行中优先，时间其次', () {
      final tHour = _buildTask(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 1)),
      );
      final tMultiInProgress = _buildTask(
        id: 'multi-inprog',
        status: 1,
        start: now.add(const Duration(days: 5)),
        due: now.add(const Duration(days: 6)),
      );
      final tMultiPending = _buildTask(
        id: 'multi-pending',
        status: 0,
        start: now.add(const Duration(days: 2)),
        due: now.add(const Duration(days: 3)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tMultiPending, tHour, tMultiInProgress],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), [
        'hour',
        'multi-inprog',
        'multi-pending',
      ]);
    });

    test('空池返回空', () {
      final ranked = DesktopFloatingTabController.rankCandidates([], now);
      expect(ranked, isEmpty);
    });
  });

  group('pending focus 字段', () {
    test('写入后可读取并清除', () {
      final controller = DesktopFloatingTabController.instance;
      controller.pendingFocusTaskId = 'task-1';
      controller.pendingFocusRequestToken = 123;
      expect(controller.pendingFocusTaskId, 'task-1');
      expect(controller.pendingFocusRequestToken, 123);
      controller.pendingFocusTaskId = null;
      controller.pendingFocusRequestToken = null;
      expect(controller.pendingFocusTaskId, isNull);
    });
  });
}
