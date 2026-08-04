// TestedSource: SupabaseService._client + SupabaseService.currentUser@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: Supabase 容错（prd P1-A）
// 原 bug: Supabase.initialize 带 2s 超时，超时未完成时构造 SupabaseService()
//         （runApp 的 BlocProvider 即构造）会抛 LateInitializationError
// 修复方式: _client 改为 getter 延迟到首次使用才取；currentUser 包 try/catch
//         降级返回 null → 走本地路径
//
// === 必问三答 ===
// Q1: 触发条件：Supabase 未初始化 / 2s 超时降级窗口内访问
// Q2: 旧代码：字段初始化抛 LateInitializationError / 访问抛异常
// Q3: 新代码：getter 延迟 + currentUser 容错返回 null → 走本地路径
//
// 本测试用 dart:io 读取源文件做"结构不变量"断言：SupabaseService 依赖
// supabase_flutter 平台初始化，无法无头实例化，只断言结构标记。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码（`//` 行注释开头视为注释）
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  final src = File('lib/services/supabase_service.dart').readAsStringSync();
  final active = _activeLines(src).join('\n');

  group('回归: Supabase 容错结构不变量', () {
    test('_client 为 getter 延迟初始化', () {
      expect(
        active.contains(
            'SupabaseClient get _client => Supabase.instance.client;'),
        isTrue,
        reason: '_client 字段初始化回归（P1-A 会抛 LateInitializationError）',
      );
    });

    test('currentUser 含 try/catch', () {
      final idx = active.indexOf('User? get currentUser');
      expect(idx, greaterThan(0), reason: 'currentUser getter 缺失');
      final block = active.substring(idx, idx + 300);
      expect(block.contains('try {'), isTrue,
          reason: 'currentUser 无 try 保护');
      expect(block.contains('} catch (_) {'), isTrue,
          reason: 'currentUser 无 catch 降级');
    });

    test('currentUser catch 返回 null（走本地路径）', () {
      final idx = active.indexOf('User? get currentUser');
      final block = active.substring(idx, idx + 300);
      expect(block.contains('return null;'), isTrue,
          reason: '容错降级未返回 null');
      final tryIdx = block.indexOf('try {');
      final catchIdx = block.indexOf('} catch (_) {');
      final retNullIdx = block.indexOf('return null;');
      expect(tryIdx, lessThan(catchIdx),
          reason: 'try 须在 catch 之前');
      expect(catchIdx, lessThan(retNullIdx),
          reason: 'return null 须在 catch 内');
    });

    test('P1-A 容错注释保留（2s 超时降级窗口说明）', () {
      expect(src.contains('P1-A'), isTrue, reason: 'P1-A 注释被移除');
      expect(src.contains('2s 超时'), isTrue, reason: '2s 超时说明被移除');
    });
  });
}

// === 破坏性验证 ===
// 将 lib/services/supabase_service.dart:10 的 getter 改回字段初始化
// （final SupabaseClient _client = Supabase.instance.client;）后运行:
//   flutter test .trellis/tests/generated/2026/08/test_supabase_fault_tolerance.dart
// 预期: FAIL (_client 字段初始化回归)
// 恢复后: PASS
