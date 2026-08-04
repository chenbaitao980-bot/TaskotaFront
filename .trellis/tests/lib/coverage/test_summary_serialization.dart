// 覆盖测试: DesktopFloatingTaskSummary 跨窗序列化（直接层）
// 变更点: ea86621 新增跨引擎摘要协议（便签窗不读 SQLite，靠 toJson/fromJson 传递）
// Layer: 直接
// TestedSource: DesktopFloatingTaskSummary@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
//
// 业务不变量:
// 1. toJson → fromJson 往返无损（含 dueDate=null）
// 2. anchorDate 用 ISO8601，往返保留到秒精度
// 3. fromJson 遇缺失/类型不符字段抛异常（TypeError），不静默产出坏摘要

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/core/desktop/desktop_floating_tab_controller.dart';

void main() {
  group('DesktopFloatingTaskSummary 序列化往返', () {
    test('完整字段往返无损', () {
      final summary = DesktopFloatingTaskSummary(
        taskId: 'task-123',
        title: '写周报',
        priority: 3,
        anchorDate: DateTime(2026, 8, 4, 9, 30, 15),
        dueDate: DateTime(2026, 8, 5, 18, 0),
        extraTaskCount: 2,
      );
      final decoded = DesktopFloatingTaskSummary.fromJson(summary.toJson());
      expect(decoded.taskId, 'task-123');
      expect(decoded.title, '写周报');
      expect(decoded.priority, 3);
      expect(decoded.anchorDate, DateTime(2026, 8, 4, 9, 30, 15));
      expect(decoded.dueDate, DateTime(2026, 8, 5, 18, 0));
      expect(decoded.extraTaskCount, 2);
    });

    test('dueDate 为 null 的往返（跨天/全天任务无截止时间）', () {
      final summary = DesktopFloatingTaskSummary(
        taskId: 't',
        title: '全天任务',
        priority: 1,
        anchorDate: DateTime(2026, 8, 4),
        dueDate: null,
        extraTaskCount: 0,
      );
      final decoded = DesktopFloatingTaskSummary.fromJson(summary.toJson());
      expect(decoded.dueDate, isNull);
      expect(decoded.extraTaskCount, 0);
    });

    test('toJson 字段名与便签窗 _loadInitialSummary 契约一致', () {
      final summary = DesktopFloatingTaskSummary(
        taskId: 'a',
        title: 'b',
        priority: 3,
        anchorDate: DateTime(2026, 8, 4),
        dueDate: null,
        extraTaskCount: 0,
      );
      final json = summary.toJson();
      expect(json.keys, containsAll(['taskId', 'title', 'priority', 'anchorDate', 'dueDate', 'extraTaskCount']));
    });

    test('fromJson 缺失必填字段抛异常（不静默产出坏摘要）', () {
      expect(
        () => DesktopFloatingTaskSummary.fromJson(<String, dynamic>{'taskId': 'a'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
