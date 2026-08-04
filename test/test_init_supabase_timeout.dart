// 测试: _initSupabase 2s 超时不阻塞首帧（P1-A）
// 变更点: main.dart `_initSupabase()` 带 `.timeout(const Duration(seconds: 2))`，
//   弱网悬挂不再阻塞 runApp 前关键路径；超时/失败仅记录，本地模式 currentUser 降级 null
// 本测试用 dart:io 读源文件做结构断言（main() 无法无头实例化）
// Layer: GENERATED
// TestedSource: main._initSupabase@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件：应用启动，Supabase.initialize 网络悬挂
// Q2: 旧代码：无 timeout → Future.wait 挂起 → runApp 前首帧白窗卡住数秒
// Q3: 新代码：`.timeout(const Duration(seconds: 2))` → 2s 内返回，超时仅记录 →
//     不阻塞首帧（契约6）
//
// === 入参/出参标准 ===
// 入参: lib/main.dart 源文件（当前工作树）
// 出参: 结构断言 — _initSupabase 方法存在 / .timeout(2s) 存在 / try-catch 记录日志 /
//       Future.wait 并行路径保留

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  final main =
      File('lib/main.dart').readAsStringSync();
  final active = _activeLines(main).join('\n');

  group('契约6: _initSupabase 2s 超时', () {
    test('_initSupabase 方法存在', () {
      expect(active.contains('Future<void> _initSupabase() async'), isTrue,
          reason: '_initSupabase 方法缺失');
    });

    test('Supabase.initialize 带 .timeout(2s)（弱网悬挂 2s 内返回）', () {
      expect(active.contains('.timeout(const Duration(seconds: 2))'), isTrue,
          reason: '2s 超时缺失（P1-A 契约6 失效）');
    });

    test('超时/失败仅记录日志不抛出', () {
      expect(active.contains("flog('[App] Supabase.initialize 超时/失败"), isTrue,
          reason: '超时降级日志缺失');
    });

    test('_initSupabase 在 Future.wait 并行路径中（不串行阻塞）', () {
      final waitIdx = active.indexOf('Future.wait<void>');
      final initIdx = active.indexOf('_initSupabase(),');
      expect(waitIdx, greaterThan(-1), reason: 'Future.wait 并行路径缺失');
      expect(initIdx, greaterThan(waitIdx),
          reason: '_initSupabase 须在 Future.wait 内（并行）');
    });
  });
}
// === 破坏性验证 ===
// 注释 lib/main.dart:186 的 `.timeout(const Duration(seconds: 2))` 后运行:
//   flutter test test_init_supabase_timeout.dart
// 预期: FAIL (契约6 2s 超时缺失)
// 恢复后: PASS
