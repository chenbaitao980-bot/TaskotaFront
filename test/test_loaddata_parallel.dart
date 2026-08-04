// 回归测试: _loadData 三查询并行 + 定位消费点（P1-D + P0-B + R4/A5 + R1/A1）
// 原 bug: 三查询串行 await → 每次回首页/刷新 6-12s 成对 LoadTasks 重载风暴拖首帧（P1-E 相关）；
//   postFrame 闭包无 mounted 守卫 → State dispose 后消费 setState → Null check 崩溃（P0-B）
// 修复方式: 三路查询互不依赖，Future.wait<List<Object>> 并行；postFrame 闭包开头
//   if(!mounted) return 守卫；闭包内依次消费 _processBlocFocusTask()（日历/创建定位）+
//   _processFloatingTabFocusTask()（桌面便签定位），命中则跳过默认滚到 now
// 对应提交: bf3e1cb（工作树，P1-D + P0-B 已在 home_page.dart:970/1139 落地）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomeContentState._loadData@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 回首页/刷新触发 _loadData；加载完成后 postFrame 闭包消费待定位任务
// Q2: 旧代码在这条件下会怎样？
// A2: 三查询串行 await → 首帧/刷新被拖慢（P1-D）；闭包无 mounted 守卫 → dispose 后崩溃（P0-B）
// Q3: 新代码在这条件下会怎样？
// A3: Future.wait 三路并行；mounted 守卫在消费前；bloc/便签定位消费点都在闭包内且顺序固定
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — Future.wait<List<Object>> 并行 / 三路查询存在 / postFrame 闭包 mounted 守卫 /
//       _processBlocFocusTask + _processFloatingTabFocusTask 消费点 / 顺序不变量

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src =
      File('lib/presentation/pages/home/home_page.dart').readAsStringSync();

  // 活动代码行 = 非注释行（红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker, String snippet) => snippet
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  // _loadData 方法体（签名后 → 下一方法前，含结尾 postFrame 闭包）
  final loadSnippet = src
      .split('Future<void> _loadData() async {')
      .last
      .split('void _processPendingNotificationTask()')
      .first;

  group('P1-D 三查询并行', () {
    test('活动代码含 Future.wait<List<Object>>（并行替代串行 await）', () {
      expect(
        activeLines('Future.wait<List<Object>>', loadSnippet),
        isNotEmpty,
        reason: '三查询 Future.wait 并行被拆回串行 await（P1-D 性能回归）',
      );
    });

    test('并行含三路互不依赖查询（projects/groups/tasks）', () {
      expect(
        activeLines('widget.projectRepository?.getActive()', loadSnippet),
        isNotEmpty,
        reason: '并行 projects 查询缺失',
      );
      expect(
        activeLines('widget.projectGroupRepository?.getAll()', loadSnippet),
        isNotEmpty,
        reason: '并行 groups 查询缺失',
      );
      expect(
        activeLines('widget.taskRepository?.getAll()', loadSnippet),
        isNotEmpty,
        reason: '并行 tasks 查询缺失',
      );
    });
  });

  group('P0-B postFrame 闭包守卫', () {
    test('活动代码含 if (!mounted) return;（闭包内，消费前）', () {
      expect(
        activeLines('if (!mounted) return;', loadSnippet),
        isNotEmpty,
        reason: 'P0-B postFrame 闭包 mounted 守卫被移除 → dispose 后消费 setState 抛错',
      );
    });
  });

  group('定位消费点（R4/A5 + R1/A1）', () {
    test('活动代码含 _processBlocFocusTask()（日历/创建后定位）', () {
      expect(
        activeLines('_processBlocFocusTask();', loadSnippet),
        isNotEmpty,
        reason: '加载后 bloc 定位消费点被删除',
      );
    });

    test('活动代码含 _processFloatingTabFocusTask()（桌面便签定位）', () {
      expect(
        activeLines('_processFloatingTabFocusTask();', loadSnippet),
        isNotEmpty,
        reason: '加载后桌面便签定位消费点被删除',
      );
    });

    test('顺序不变量: Future.wait → mounted 守卫 → bloc 定位 → 便签定位', () {
      final waitIdx = loadSnippet.indexOf('Future.wait<List<Object>>');
      final mountedIdx = loadSnippet.indexOf('if (!mounted) return;');
      final blocIdx = loadSnippet.indexOf('_processBlocFocusTask();');
      final tabIdx = loadSnippet.indexOf('_processFloatingTabFocusTask();');
      expect(waitIdx, greaterThan(0), reason: 'Future.wait 并行缺失');
      expect(waitIdx, lessThan(mountedIdx),
          reason: '数据加载须先于定位消费');
      expect(mountedIdx, lessThan(blocIdx),
          reason: 'mounted 守卫须先于定位消费（P0-B）');
      expect(blocIdx, lessThan(tabIdx),
          reason: 'bloc 定位先于桌面便签定位消费');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:983 `await Future.wait<List<Object>>([` → FAIL(P1-D 三查询并行)
// 注释 home_page.dart:1142 `if (!mounted) return;` → FAIL(P0-B postFrame 闭包守卫)
// 注释 home_page.dart:1144 `_processBlocFocusTask();` → FAIL(bloc 定位消费点)
// 注释 home_page.dart:1145 `_processFloatingTabFocusTask();` → FAIL(便签定位消费点)
// 运行: flutter test test_loaddata_parallel.dart
// 预期: FAIL (AssertionError)
// 恢复后: PASS
