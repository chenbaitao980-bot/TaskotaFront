// 覆盖测试: rankCandidates 分层排序（直接层，分支决策表穷举）
// 变更点: ea86621 重写 rankCandidates 为分层规则
// Layer: 直接
// TestedSource: rankCandidates + _rankWithinLayer + _isMultiDayTask@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
//
// 决策表（层归属）:
//   startDate=null → 剔除（不入任何层）
//   isAllDay=1     → 层②
//   跨日(start/due 不同日) → 层②
//   单日非全天      → 层①
// 层内排序: status==1 优先 → |start-now| 升序 → updatedAt 降序

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';
import 'package:smart_assistant/data/database/app_database.dart';

Task _t({
  required String id,
  int status = 0,
  DateTime? start,
  DateTime? due,
  int isAllDay = 0,
  int updatedAt = 0,
}) {
  return Task(
    id: id,
    projectId: 'p1',
    parentId: null,
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

  group('层归属决策表', () {
    test('单日非全天 → 层①；跨日 → 层②', () {
      final hour = _t(
        id: 'h',
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 1, hours: 2)), // 同日
      );
      final crossDay = _t(
        id: 'cd',
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 3)), // 跨日
      );
      final ranked = DesktopFloatingTabController.rankCandidates([crossDay, hour], now);
      expect(ranked.map((t) => t.id).toList(), ['h', 'cd']);
    });

    test('跨日且 isAllDay=1 → 层②（双条件都命中）', () {
      final crossAllDay = _t(
        id: 'ca',
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 2)),
        isAllDay: 1,
      );
      final hour = _t(id: 'h', start: now.add(const Duration(days: 1)));
      final ranked = DesktopFloatingTabController.rankCandidates([crossAllDay, hour], now);
      expect(ranked.map((t) => t.id).toList(), ['h', 'ca']);
    });

    test('startDate==null 无论 status/isAllDay 均剔除', () {
      final noStartInProgress = _t(id: 'ns1', status: 1);
      final noStartAllDay = _t(id: 'ns2', isAllDay: 1);
      final hour = _t(id: 'h', start: now.add(const Duration(days: 1)));
      final ranked = DesktopFloatingTabController.rankCandidates(
          [noStartInProgress, noStartAllDay, hour], now);
      expect(ranked.map((t) => t.id).toList(), ['h']);
    });

    test('dueDate 为 null 但单日 start → 层①', () {
      final noDue = _t(id: 'nd', start: now.add(const Duration(days: 1)));
      expect(DesktopFloatingTabController.rankCandidates([noDue], now).single.id, 'nd');
    });
  });

  group('层内排序', () {
    test('进行中优先于待办，即使待办时间更近', () {
      final inProgress = _t(id: 'ip', status: 1, start: now.add(const Duration(days: 9)));
      final pending = _t(id: 'pd', status: 0, start: now.add(const Duration(days: 1)));
      final ranked = DesktopFloatingTabController.rankCandidates([pending, inProgress], now);
      expect(ranked.map((t) => t.id).toList(), ['ip', 'pd']);
    });

    test('同 status 距 now 绝对值最近优先（过去与未来同权）', () {
      final future = _t(id: 'f', status: 0, start: now.add(const Duration(hours: 2)));
      final past = _t(id: 'p', status: 0, start: now.subtract(const Duration(hours: 1)));
      final ranked = DesktopFloatingTabController.rankCandidates([future, past], now);
      // |−1h|=1h < |+2h|=2h → past 排前
      expect(ranked.map((t) => t.id).toList(), ['p', 'f']);
    });

    test('距离相同平局 → updatedAt 降序（最新优先）', () {
      final old = _t(id: 'old', status: 0, start: now.add(const Duration(days: 1)), updatedAt: 50);
      final mid = _t(id: 'mid', status: 0, start: now.add(const Duration(days: 1)), updatedAt: 100);
      final newest = _t(id: 'new', status: 0, start: now.add(const Duration(days: 1)), updatedAt: 200);
      final ranked = DesktopFloatingTabController.rankCandidates([mid, old, newest], now);
      expect(ranked.map((t) => t.id).toList(), ['new', 'mid', 'old']);
    });

    test('空池返回空；单任务返回自身', () {
      expect(DesktopFloatingTabController.rankCandidates([], now), isEmpty);
      final single = _t(id: 's', start: now);
      expect(DesktopFloatingTabController.rankCandidates([single], now).single.id, 's');
    });

    test('跨天层内同样进行中优先', () {
      final crossPending = _t(id: 'cp', status: 0, start: now.add(const Duration(days: 1)), due: now.add(const Duration(days: 2)));
      final crossInProg = _t(id: 'ci', status: 1, start: now.add(const Duration(days: 5)), due: now.add(const Duration(days: 6)));
      final ranked = DesktopFloatingTabController.rankCandidates([crossPending, crossInProg], now);
      expect(ranked.map((t) => t.id).toList(), ['ci', 'cp']);
    });
  });

  group('跨层整体顺序不变量', () {
    test('层①任何任务恒在层②任何任务之前', () {
      final multiAllDay = _t(id: 'ma', isAllDay: 1, start: now.add(const Duration(days: 1)));
      final hourFar = _t(id: 'hf', start: now.add(const Duration(days: 30)));
      final ranked = DesktopFloatingTabController.rankCandidates([multiAllDay, hourFar], now);
      expect(ranked.map((t) => t.id).toList(), ['hf', 'ma'],
          reason: '层①小时级(30天后)仍排层②全天(明天)之前');
    });
  });
}
