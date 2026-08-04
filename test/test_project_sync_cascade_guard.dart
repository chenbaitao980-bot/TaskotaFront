// TestedSource: _upsertProjectFromRow + _upsertGroupFromRow@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: ProjectSync 级联软删停用保护（prd Bug A / Decision 2 断连）
// 原 bug: 云端 projects 表 16 个墓碑项目 updated_at 晚于本地存活项目 →
//         tombstone-accept 把本地项目翻为 deleted=1 → 级联块把该项目下所有 tasks
//         软删 → "任务消失"（活库 313/483 任务被误删，日志实证）
// 修复方式: 级联软删块整段注释保留（含恢复保护说明），活动代码无 deleted=1 级联赋值；
//         墓碑接受仅保留单行 LWW 写 deleted: Value(remoteDeleted)；项目组同步照常
//
// === 必问三答 ===
// Q1: 触发条件：收到 projects 表远端 deleted=1 且墓碑 updated_at 晚于本地
// Q2: 旧代码：级联块把该项目下 tasks/checklist_items 软删 → 任务消失
// Q3: 新代码：级联已停用（注释保留），只有单行墓碑写，任务不再被级联误删
//
// 本测试用 dart:io 读取源文件做"结构不变量"断言：级联块须保持注释（无活动代码），
// 用过滤注释行后的活动代码断言锁定。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码（`//` 行注释开头视为注释）
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  final src =
      File('lib/services/project_sync_service.dart').readAsStringSync();
  final active = _activeLines(src).join('\n');

  group('回归: ProjectSync 级联软删保护', () {
    test('级联软删停用止血注释存在', () {
      expect(src.contains('级联软删已停用'), isTrue,
          reason: '级联软删停用止血注释被移除');
    });

    test('注释保留了恢复保护要求（任务 updatedAt > 墓碑保护）', () {
      expect(src.contains('重启云同步前，必须给此级联加'), isTrue,
          reason: '级联恢复保护说明被移除');
    });

    test('活动代码无 deleted=1 级联赋值', () {
      expect(active.contains('deleted: const Value(1)'), isFalse,
          reason: '级联软删块仍为活动代码（应整段注释）');
      expect(active.contains('TasksCompanion(deleted: const Value(1)'), isFalse,
          reason: 'tasks 级联软删写入仍为活动代码');
    });

    test('级联触发条件仅存在于注释（活动代码不含 if (remoteDeleted == 1）', () {
      expect(
        src.contains('if (remoteDeleted == 1 && (localProject == null'),
        isTrue,
        reason: '级联触发条件注释被删除',
      );
      expect(
        active.contains('if (remoteDeleted == 1 && (localProject == null'),
        isFalse,
        reason: '级联触发条件仍是活动代码',
      );
    });

    test('墓碑接受保留单行 LWW 写 deleted: Value(remoteDeleted)', () {
      expect(active.contains('deleted: Value(remoteDeleted),'), isTrue,
          reason: '墓碑接受写被移除（LWW 单行写应保留）');
    });

    test('保留更新逻辑 insertOnConflictUpdate 存在', () {
      expect(active.contains('insertOnConflictUpdate'), isTrue,
          reason: '项目 upsert 更新逻辑被移除');
    });

    test('_upsertProjectFromRow 方法存在', () {
      expect(active.contains('Future<void> _upsertProjectFromRow'), isTrue,
          reason: '_upsertProjectFromRow 被移除');
    });

    test('_upsertGroupFromRow 项目组同步保留', () {
      expect(active.contains('Future<void> _upsertGroupFromRow'), isTrue,
          reason: '项目组同步方法被移除');
      final idx = active.indexOf('Future<void> _upsertGroupFromRow');
      final end = (idx + 800).clamp(0, active.length);
      final body = active.substring(idx, end);
      expect(body.contains('projectGroups'), isTrue,
          reason: '项目组表操作被移除');
      expect(body.contains('insertOnConflictUpdate'), isTrue,
          reason: '项目组 upsert 逻辑被移除');
    });
  });
}

// === 破坏性验证 ===
// 取消注释 lib/services/project_sync_service.dart:338-357 的级联软删块后运行:
//   flutter test .trellis/tests/generated/2026/08/test_project_sync_cascade_guard.dart
// 预期: FAIL (活动代码无 deleted=1 级联赋值)
// 恢复后: PASS
