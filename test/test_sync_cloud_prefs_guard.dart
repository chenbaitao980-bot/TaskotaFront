// TestedSource: _syncCloudPrefsAfterLoad + LoadTasks@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: DataBackend 云端偏好拉取守卫（P0-C / prd Decision 2 断连架构）
// 原 bug: 本地后端（默认）在 LoadTasks 后台也会发起 fetchPreferences 网络请求，
//         断连路径仍触发云访问
// 修复方式: _syncCloudPrefsAfterLoad 方法体首行本地直接 return；调用点仅云端才
//         unawaited 后台拉取（task_bloc.dart:343 / :514-518）
//
// === 必问三答 ===
// Q1: 触发条件：LoadTasks 加载完成，进入云端偏好后台拉取路径
// Q2: 旧代码：本地后端也会发起 fetchPreferences → 断网/降级窗口内意外云访问
// Q3: 新代码：DataBackendConfig.current != cloud 直接 return；调用点 == cloud 才拉取
//
// 本测试用 dart:io 读取源文件做"结构不变量"断言：task_bloc 无法无头实例化
// （依赖平台/Bloc 基建），只能锁定活动代码中的守卫标记与执行顺序。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码（`//` 行注释开头视为注释）
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  final src =
      File('lib/presentation/blocs/task_new/task_bloc.dart').readAsStringSync();
  final active = _activeLines(src).join('\n');

  group('回归: _syncCloudPrefsAfterLoad DataBackend 守卫', () {
    test('import data_backend.dart 存在（守卫类型可用）', () {
      expect(src.contains('data_backend.dart'), isTrue,
          reason: 'DataBackendConfig 导入被移除');
    });

    test('方法体活动代码含本地直接返回守卫（P0-C）', () {
      expect(
        active.contains(
            'if (DataBackendConfig.current != DataBackend.cloud) return;'),
        isTrue,
        reason: 'P0-C 本地后端直接返回守卫被移除',
      );
    });

    test('调用点活动代码含云端守卫（== cloud）', () {
      expect(
        active.contains('if (DataBackendConfig.current == DataBackend.cloud) {'),
        isTrue,
        reason: '调用点云守卫被移除（本地后端不应发起拉取）',
      );
    });

    test('守卫位于 fetchPreferences 调用之前', () {
      final guardIdx = active.indexOf(
          'if (DataBackendConfig.current != DataBackend.cloud) return;');
      final fetchIdx = active.indexOf('fetchPreferences()');
      expect(guardIdx, greaterThan(0), reason: '方法体守卫缺失');
      expect(fetchIdx, greaterThan(0), reason: 'fetchPreferences 调用缺失');
      expect(guardIdx, lessThan(fetchIdx),
          reason: '本地直接返回须在发起云拉取之前，否则断连路径仍会访问网络');
    });

    test('_syncCloudPrefsAfterLoad 方法签名存在且带 localPrefs 参数', () {
      expect(
        active.contains('Future<void> _syncCloudPrefsAfterLoad('),
        isTrue,
        reason: '_syncCloudPrefsAfterLoad 方法被移除',
      );
      expect(
        active.contains('Map<String, dynamic>? localPrefs'),
        isTrue,
        reason: '方法签名 localPrefs 参数被改动',
      );
    });
  });
}

// === 破坏性验证 ===
// 注释 lib/presentation/blocs/task_new/task_bloc.dart:518 的本地直接返回守卫后运行:
//   flutter test .trellis/tests/generated/2026/08/test_sync_cloud_prefs_guard.dart
// 预期: FAIL (P0-C 本地后端直接返回守卫被移除)
// 恢复后: PASS
