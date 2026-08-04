// TestedSource: LazyLogResult + LazyLogResult.fromJson + HomeLazyLogService.structure@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: 懒人日志父任务上下文 + 项目路由 + 空输入边界
// 原 bug: 1) 3237d44 之前懒人日志结构化结果未带 parentTitle，创建任务丢失父任务上下文
//         2) 0d55b30 之前懒人日志项目按 group hints 路由不准，projectHint/projectGroupHint 未解析
//         3) 23d8cb6 空输入仍可能触发请求流程
// 修复方式: LazyLogResult 增加 parentTitle/projectHint/projectGroupHint 解析；structure 空输入直接返回空结果
//
// === 必问三答 ===
// Q1: 触发条件：LazyLogResult.fromJson 传入含 parentTitle/projectHint/projectGroupHint 的 JSON
// Q2: 旧代码：字段丢失 → parentTitle 为空 → 父任务上下文丢失（回归会 FAIL）
// Q3: 新代码：字段正确解析 → 断言通过（PASS）

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/models/assistant/assistant_models.dart';
import 'package:smart_assistant/models/assistant/lazy_log_models.dart';
import 'package:smart_assistant/services/home_lazy_log_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('回归 3237d44: 懒人日志父任务上下文', () {
    test('解析 parentTitle 非空值', () {
      final result = LazyLogResult.fromJson({
        'summary': '整理',
        'parentTitle': 'SRM 周报',
        'tasks': <Object?>[],
        'schedules': <Object?>[],
      });
      expect(result.parentTitle, 'SRM 周报');
    });

    test('parentTitle 缺省/空白 → 默认空字符串', () {
      final missing = LazyLogResult.fromJson({'summary': 'x'});
      expect(missing.parentTitle, '');
      final blank = LazyLogResult.fromJson({
        'summary': 'x',
        'parentTitle': '  ',
      });
      expect(blank.parentTitle, '');
    });

    test('parentTitle 空白时 isEmpty 不受影响', () {
      final result = LazyLogResult.fromJson({'parentTitle': ''});
      expect(result.isEmpty, isTrue);
    });
  });

  group('回归 0d55b30: 懒人日志项目按 group hints 路由', () {
    test('解析 projectGroupHint / projectHint', () {
      final result = LazyLogResult.fromJson({
        'summary': '整理',
        'projectGroupHint': '工作',
        'projectHint': 'SRM',
        'tasks': <Object?>[],
        'schedules': <Object?>[],
      });
      expect(result.projectGroupHint, '工作');
      expect(result.projectHint, 'SRM');
    });

    test('hints 缺省 → 空字符串', () {
      final result = LazyLogResult.fromJson({'summary': 'x'});
      expect(result.projectGroupHint, '');
      expect(result.projectHint, '');
    });
  });

  group('回归 23d8cb6: 空输入边界', () {
    test('空白输入直接返回空结果，不触发 AI 请求', () async {
      final result = await HomeLazyLogService().structure(
        config: const AssistantModelConfig(),
        input: '   ',
      );
      expect(result.isEmpty, isTrue);
      expect(result.usedFallback, isFalse);
    });

    test('完整模型配置 + 空输入同样直接返回空结果', () async {
      final result = await HomeLazyLogService().structure(
        config: const AssistantModelConfig(
          baseUrl: 'https://example.com',
          apiKey: 'key',
          model: 'glm-4.6',
          reasoningEffort: 'off',
        ),
        input: '',
      );
      expect(result.isEmpty, isTrue);
    });
  });
}

// === 破坏性验证 ===
// 注释 lib/models/assistant/lazy_log_models.dart:117 的 parentTitle 解析后运行:
//   flutter test .trellis/tests/generated/2026/08/test_regr_lazy_log_parent.dart
// 预期: FAIL (parentTitle 为空)
// 恢复后: PASS
