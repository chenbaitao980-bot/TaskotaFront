// TestedSource: openConnection + NativeDatabase.createInBackground@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
// Layer: REGRESSION
//
// 回归测试: 本地数据库 WAL 启用（prd 本地化性能方案 W6）
// 原 bug: drift 后台 isolate 写 + UI 读并发 → database is locked
// 修复方式: createInBackground setup 回调执行 PRAGMA journal_mode=WAL +
//         synchronous=NORMAL；Web 端不启用（Wasm 无文件 WAL，分平台文件隔离）
//
// === 必问三答 ===
// Q1: 触发条件：本地数据库连接建立（后台 isolate）
// Q2: 旧代码：无 WAL → 并发读写 database is locked
// Q3: 新代码：WAL + NORMAL → 后台写与 UI 读并发不阻塞
//
// 本测试用 dart:io 读取源文件做"结构不变量"断言：openConnection 返回
// LazyDatabase/QueryExecutor，无头无法实例化（依赖 LocalDataService 平台文件路径）。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// 过滤注释行，只保留活动代码（`//` 行注释开头视为注释）
List<String> _activeLines(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).toList();

void main() {
  final src = File('lib/data/database/connection/connection_native.dart')
      .readAsStringSync();
  final active = _activeLines(src).join('\n');

  group('回归: 本地数据库 WAL 启用', () {
    test('活动代码含 PRAGMA journal_mode=WAL', () {
      expect(active.contains("db.execute('PRAGMA journal_mode=WAL;')"), isTrue,
          reason: 'WAL 启用语句被移除或改注释');
    });

    test('活动代码含 PRAGMA synchronous=NORMAL', () {
      expect(
        active.contains("db.execute('PRAGMA synchronous=NORMAL;')"),
        isTrue,
        reason: 'synchronous=NORMAL 语句被移除或改注释',
      );
    });

    test('两个 PRAGMA 都在 setup 回调内', () {
      final setupIdx = active.indexOf('setup: (db)');
      final walIdx = active.indexOf('PRAGMA journal_mode=WAL');
      final syncIdx = active.indexOf('PRAGMA synchronous=NORMAL');
      expect(setupIdx, greaterThan(0), reason: 'setup 回调缺失');
      expect(walIdx, greaterThan(setupIdx),
          reason: 'WAL 未在 setup 回调内执行');
      expect(syncIdx, greaterThan(setupIdx),
          reason: 'synchronous 未在 setup 回调内执行');
    });

    test('使用后台 isolate 创建（createInBackground，W6）', () {
      expect(active.contains('NativeDatabase.createInBackground'), isTrue,
          reason: '后台 isolate 创建被移除（W6）');
    });

    test('区分平台：Web 端不启用 WAL 说明存在', () {
      expect(src.contains('Web 端不启用'), isTrue,
          reason: 'Web 端不启用 WAL 的分平台说明被移除');
    });
  });
}

// === 破坏性验证 ===
// 注释 lib/data/database/connection/connection_native.dart:18-19 的两个 PRAGMA 后运行:
//   flutter test .trellis/tests/generated/2026/08/test_connection_wal.dart
// 预期: FAIL (WAL 启用语句被移除或改注释)
// 恢复后: PASS
