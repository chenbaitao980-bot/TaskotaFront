// TestedSource: AttachmentSyncService + ChecklistSyncService + NodeTemplateSyncService + SubscriptionService + TaskSyncService@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: 5 个 sync service 的 DataBackend 本地守卫（prd Decision 2 断连架构）
// 原 bug: 本地后端（默认）仍会走云同步 pullAll/subscribe/push，断连路径发起云访问
// 修复方式: 各 service 入口方法首行 DataBackendConfig.current == DataBackend.local
//        直接 return；数据只走本地 drift（唯一真源）
//
// === 必问三答 ===
// Q1: 触发条件：本地后端模式（默认）触发同步
// Q2: 旧代码：仍走云同步 → 断网路径意外云访问
// Q3: 新代码：local 直接 return → 数据只走本地 drift
//
// 本测试用 dart:io 读取源文件做"结构不变量"断言：sync service 无法无头实例化
// （依赖 Supabase/Realtime 平台通道），只锁定活动代码中的守卫标记。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码（`//` 行注释开头视为注释）
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  const targets = <String, String>{
    'lib/services/attachment_sync_service.dart': 'AttachmentSyncService',
    'lib/services/checklist_sync_service.dart': 'ChecklistSyncService',
    'lib/services/node_template_sync_service.dart': 'NodeTemplateSyncService',
    'lib/services/subscription_service.dart': 'SubscriptionService',
    'lib/services/task_sync_service.dart': 'TaskSyncService',
  };

  for (final entry in targets.entries) {
    group(entry.value, () {
      final src = File(entry.key).readAsStringSync();
      final active = _activeLines(src).join('\n');

      test('类声明存在', () {
        expect(active.contains('class ${entry.value}'), isTrue,
            reason: '${entry.value} 类被移除/改名');
      });

      test('import data_backend.dart 存在', () {
        expect(src.contains('data_backend.dart'), isTrue,
            reason: '${entry.value} 的 DataBackendConfig 导入被移除');
      });

      test('活动代码含 DataBackend.local 守卫', () {
        expect(
          active.contains('DataBackendConfig.current == DataBackend.local'),
          isTrue,
          reason: '${entry.value} 的本地后端守卫被移除',
        );
      });
    });
  }
}

// === 破坏性验证 ===
// 注释任一 service 的 `if (DataBackendConfig.current == DataBackend.local) return;`
// （如 attachment_sync_service.dart:27）后运行:
//   flutter test .trellis/tests/generated/2026/08/test_sync_service_guards.dart
// 预期: FAIL (该 service 的本地后端守卫被移除)
// 恢复后: PASS
