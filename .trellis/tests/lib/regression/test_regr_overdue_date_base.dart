// 回归测试: 逾期判断基准（3554580 / eee4e76f）
// 原 bug: 逾期判断误用 startDate 而非 dueDate（3554580 修复"以 dueDate 为逾期基准，
//         无 dueDate 永不逾期"；eee4e76f 修复"右上角逾期数也用 startDate 的遗漏"）
// 本次变更: 控制器新增 anchorDateOf = startDate ?? dueDate ?? now（便签展示锚点），
//         与首页逾期口径是不同语义，不得互相污染
// 对应提交: 3554580 → eee4e76f → ea86621(anchorDateOf)
// Layer: REGRESSION
//
// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 任务有 startDate 无 dueDate（或反之），进入逾期判断/便签锚点计算
// Q2: 旧代码在这条件下会怎样？
// A2: 逾期判断用 startDate 导致误判逾期
// Q3: 新代码在这条件下会怎样？
// A3: 首页逾期仍以 dueDate/endDate 为准；便签锚点 anchorDateOf 独立用 startDate ?? dueDate ?? now

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';
import 'package:smart_assistant/data/database/app_database.dart';

Task _task({required String id, DateTime? start, DateTime? due, int updatedAt = 0}) {
  return Task(
    id: id,
    projectId: 'p1',
    parentId: null,
    title: '任务$id',
    description: '',
    priority: 3,
    status: 0,
    startDate: start?.millisecondsSinceEpoch,
    dueDate: due?.millisecondsSinceEpoch,
    isAllDay: 0,
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

// TestedSource: anchorDateOf@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
void main() {
  final now = DateTime(2026, 8, 3, 12, 0);

  group('anchorDateOf（便签展示锚点，新语义）', () {
    test('startDate 优先于 dueDate', () {
      final t = _task(
        id: 'a',
        start: DateTime(2026, 8, 4),
        due: DateTime(2026, 8, 5),
      );
      expect(DesktopFloatingTabController.anchorDateOf(t, now),
          DateTime(2026, 8, 4));
    });

    test('无 startDate 用 dueDate（无 dueDate 才回退 now）', () {
      final tDue = _task(id: 'b', due: DateTime(2026, 8, 5));
      expect(DesktopFloatingTabController.anchorDateOf(tDue, now),
          DateTime(2026, 8, 5));
      final tNone = _task(id: 'c');
      expect(DesktopFloatingTabController.anchorDateOf(tNone, now), now,
          reason: '便签锚点允许回退 now；但这与逾期口径无关（逾期无 dueDate 永不逾期）');
    });
  });

  group('首页逾期口径（结构性回归）', () {
    test('四象限逾期判定仍以 (endDate ?? date) 为准', () {
      final src = File('lib/presentation/pages/home/home_page.dart')
          .readAsStringSync();
      expect(
        src.contains('final isOverdueItem = (task.endDate ?? task.date).isBefore(today);'),
        isTrue,
        reason: '3554580/eee4e76f 的逾期基准被改动',
      );
    });
  });
}
