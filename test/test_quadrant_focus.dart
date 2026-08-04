// 回归测试: 四象限点击定位链路（R3/A4）— 竖向回滚 + 复用 _selectTask 选中
// 原 bug: 四象限点击任务只高亮/滚动横向，时间轴被竖向滚动移出可视区时点击无感；
//   点击卡片不先竖向滚回时间轴可视区 → 用户看不到选中结果
// 修复方式: _selectTaskFromQuadrant 先 postFrame 用 _timelineSectionKey 竖向 ensureVisible
//   滚回可视区，再走 _selectTask(task) 复用完整选中+横向定位链路；onTap 绑定到此方法
// 对应提交: bf3e1cb（工作树，R3 已在 home_page.dart:1455/5619 落地）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomeContentState._selectTaskFromQuadrant + _HomeContentState._buildQuadrant.taskItem@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户在四象限面板点击任一任务卡片（onTap 绑定 _selectTaskFromQuadrant）
// Q2: 旧代码在这条件下会怎样？
// A2: 无 _timelineSectionKey 竖向回滚 → 时间轴在可视区外时点击只横向定位，选中结果不可见
// Q3: 新代码在这条件下会怎样？
// A3: postFrame 先 ensureVisible(_timelineSectionKey) 竖向回滚，再 _selectTask 选中+横向定位
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — _timelineSectionKey 锚点 / _selectTask 复用 / 回滚先于选中 /
//       onTap 绑定 _selectTaskFromQuadrant(task)

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

  // _selectTaskFromQuadrant 方法体（签名后 → 下一方法前）
  final quadrantSel = src
      .split('void _selectTaskFromQuadrant(_TimelineTask task) {')
      .last
      .split('String _dbPriorityToLabel(')
      .first;

  group('四象限竖向回滚（R3/A4）', () {
    test('活动代码含 _timelineSectionKey（时间轴竖向滚动锚点）', () {
      expect(
        activeLines('_timelineSectionKey', quadrantSel),
        isNotEmpty,
        reason: '四象限点击竖向滚回时间轴的锚点被删除（R3 回归）',
      );
    });

    test('锚点经 Scrollable.ensureVisible 竖向滚动', () {
      expect(
        activeLines('Scrollable.ensureVisible', quadrantSel),
        isNotEmpty,
        reason: '竖向回滚调用缺失 → 时间轴可视区外点击仍无感',
      );
    });

    test('复用选中链路: 活动代码含 _selectTask(', () {
      expect(
        activeLines('_selectTask(', quadrantSel),
        isNotEmpty,
        reason: '四象限点击未复用 _selectTask 选中链路 → 不选中/不横向定位',
      );
    });

    test('顺序不变量: 先注册 ensureVisible 竖向回滚，再 _selectTask', () {
      final keyIdx = quadrantSel.indexOf('_timelineSectionKey');
      final selIdx = quadrantSel.indexOf('_selectTask(');
      expect(keyIdx, greaterThan(0), reason: '_timelineSectionKey 锚点缺失');
      expect(keyIdx, lessThan(selIdx),
          reason: 'R3: 须先竖向滚回时间轴可视区，再走 _selectTask 选中+横向定位');
    });
  });

  group('onTap 绑定', () {
    test('活动代码含 onTap: () => _selectTaskFromQuadrant(task)', () {
      expect(
        activeLines('onTap: () => _selectTaskFromQuadrant(task)', src),
        isNotEmpty,
        reason: '四象限卡片 onTap 未绑定 _selectTaskFromQuadrant（点击链路断）',
      );
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:1458 `final ctx = _timelineSectionKey.currentContext;` → FAIL(竖向滚动锚点)
// 注释 home_page.dart:1460 `Scrollable.ensureVisible(` → FAIL(ensureVisible 回滚)
// 注释 home_page.dart:1467 `_selectTask(task);` → FAIL(复用选中链路)
// 注释 home_page.dart:5619 `onTap: () => _selectTaskFromQuadrant(task),` → FAIL(onTap 绑定)
// 运行: flutter test test_quadrant_focus.dart
// 预期: FAIL (AssertionError)
// 恢复后: PASS
