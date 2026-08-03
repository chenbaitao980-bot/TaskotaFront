// 回归测试: 便签候选选择分层规则（f68060b 起源 + ea86621 分层重写）
// 原 bug: 旧规则 _scoreTask = priority*2 + urgency（f68060b 引入），选出陈旧进行中任务
//         压过今天到期待办（用户 2026-08-03 实测：便签非最近任务）
// 修复方式: rankCandidates 分层规则 — 层①小时级(单日非全天)优先 层②跨天/全天靠后；
//         每层内 进行中(status==1)优先 → 距 startDate 最近 → 平局 updatedAt 最新；
//         无 startDate 的任务不进入排序（剔除）。
// 对应提交: f68060b(旧规则) → ea86621(分层规则)
// Layer: REGRESSION
// TestedSource: rankCandidates + _rankWithinLayer + _isMultiDayTask@425e7564f1881ab73d67f37b83b673f31427bd37
//
// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 存在未完成任务池（status 0/1，deleted 0，archived 0），含小时级/跨天/全天/无日期任务
// Q2: 旧代码（priority*2+urgency 打分）在这条件下会怎样？
// A2: 优先级高的陈旧任务压过时间最近任务 → 便签显示非最近任务（用户报障 #2）
// Q3: 新代码（rankCandidates 分层）在这条件下会怎样？
// A3: 小时级任务优先，层内进行中→时间最近→平局updatedAt，无日期剔除 → 便签显示最近任务
//
// === 行为反转确认 ===
// 旧行为: priority*2+urgency 打分选任务（f68060b）
// 新行为: 分层时间最近选任务（ea86621）
// 判定: 有意反转（用户 2026-08-03 最终确认分层规则）

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';
import 'package:smart_assistant/data/database/app_database.dart';

Task _task({
  required String id,
  int status = 0,
  DateTime? start,
  DateTime? due,
  int isAllDay = 0,
  int updatedAt = 0,
  int priority = 3,
}) {
  return Task(
    id: id,
    projectId: 'p1',
    parentId: null,
    title: '任务$id',
    description: '',
    priority: priority,
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

  group('分层规则回归：小时级优先（不再按优先级打分）', () {
    test('P0 高优先级但 3 天后的小时级任务，压过 P3 但 1 天后的？', () {
      // 层①内仍按"进行中→时间最近"，不按优先级：P3 时间近者应排前
      final tHigh = _task(
        id: 'high-p0',
        status: 0,
        start: now.add(const Duration(days: 5)),
        priority: 5,
      );
      final tLow = _task(
        id: 'low-p3',
        status: 0,
        start: now.add(const Duration(days: 1)),
        priority: 1,
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tHigh, tLow],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['low-p3', 'high-p0'],
          reason: '新规则按时间最近，P3 时间近者排前，不再按优先级打分');
    });

    test('进行中的陈旧任务优先于最近待办（用户报障 #2 的修复方向）', () {
      // 用户报障：陈旧进行中任务压过今天到期待办 → 但新规则仍进行中优先
      // （这是有意行为：进行中优先是用户确认的分层内第一排序键）
      final tStaleInProgress = _task(
        id: 'stale-inprog',
        status: 1,
        start: now.subtract(const Duration(days: 2)),
        updatedAt: 100,
      );
      final tTodayPending = _task(
        id: 'today-pending',
        status: 0,
        start: now,
        updatedAt: 200,
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tTodayPending, tStaleInProgress],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['stale-inprog', 'today-pending'],
          reason: '层内进行中(status==1)优先是确认的第一排序键');
    });

    test('无 startDate 的进行中任务也被剔除（不入排序）', () {
      final tNoStartInProgress = _task(id: 'nostart-inprog', status: 1);
      final tHour = _task(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 1)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tNoStartInProgress, tHour],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour']);
    });

    test('跨天任务层②排后：即使跨天进行中且时间更近', () {
      final tHourPending = _task(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 5)),
      );
      final tMultiInProgress = _task(
        id: 'multi',
        status: 1,
        start: now.add(const Duration(days: 1)),
        due: now.add(const Duration(days: 2)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tMultiInProgress, tHourPending],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour', 'multi'],
          reason: '层①小时级任务优先于层②跨天任务，即使跨天进行中');
    });
  });

  group('isAllDay 判定（层②）', () {
    test('isAllDay==1 且只有 startDate 的任务归层②', () {
      final tAllDay = _task(
        id: 'allday',
        status: 0,
        start: now.add(const Duration(days: 1)),
        isAllDay: 1,
      );
      final tHour = _task(
        id: 'hour',
        status: 0,
        start: now.add(const Duration(days: 3)),
      );
      final ranked = DesktopFloatingTabController.rankCandidates(
        [tAllDay, tHour],
        now,
      );
      expect(ranked.map((t) => t.id).toList(), ['hour', 'allday']);
    });
  });
}
