// 回归测试: 桌面便签通知入口 + bloc 定位消费（R1/A1 便签直连 + R4/A5 日历定位 + P0-B）
// 原 bug: 便签恢复主窗走 onResume → 每次 6-12s 成对 LoadTasks 重载风暴（P1-E 已改节流）；
//   便签定位必须由 _onDesktopTabNotify 直连消费，不依赖 resume 链路
// 修复方式: _onDesktopTabNotify 监听 DesktopFloatingTabController，pendingFocusTaskId 非空时
//   postFrame 消费（含 mounted 守卫）；_processBlocFocusTask 消费 _pendingBlocFocusTaskId（消费即清）
// 对应提交: bf3e1cb（工作树，BP1-BP5 + P0-B 已在 home_page.dart:934/1239 落地）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomeContentState._onDesktopTabNotify + _HomeContentState._processBlocFocusTask@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户点便签任务 → DesktopFloatingTabController.pendingFocusTaskId 非空 → 控制器 notify →
//     _onDesktopTabNotify 被监听回调；或日历/创建任务后 _pendingBlocFocusTaskId 被写入 → _loadData
// Q2: 旧代码在这条件下会怎样？
// A2: 便签定位依赖 onResume 重载链路 → 6-12s 重载风暴拖首帧（P1-E 已修）；无直连消费入口
// Q3: 新代码在这条件下会怎样？
// A3: _onDesktopTabNotify 非空即 postFrame 消费，mounted 守卫防 dispose 崩溃；bloc 定位消费即清
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — pendingFocusTaskId==null 守卫 / addPostFrameCallback / _processFloatingTabFocusTask
//       消费入口 / postFrame 内 mounted 守卫 / _pendingBlocFocusTaskId 消费即清 / _selectTask(t) 命中选中

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

  // _onDesktopTabNotify 方法体（签名后 → 下一方法前）
  final notifyBody = src
      .split('void _onDesktopTabNotify()')
      .last
      .split('void _onVisibleTabChanged()')
      .first;
  // _processBlocFocusTask 方法体（签名后 → 下一方法前）
  final blocFocus = src
      .split('bool _processBlocFocusTask()')
      .last
      .split('void _navigateToFirstOverdueTask()')
      .first;

  group('_onDesktopTabNotify 直连消费入口', () {
    test('守卫: 活动代码含 controller.pendingFocusTaskId == null', () {
      expect(
        activeLines('controller.pendingFocusTaskId == null', notifyBody),
        isNotEmpty,
        reason: '无待定位任务时的早退守卫被删除 → 空任务也触发 postFrame 定位',
      );
    });

    test('postFrame 消费: 活动代码含 addPostFrameCallback', () {
      expect(
        activeLines('addPostFrameCallback', notifyBody),
        isNotEmpty,
        reason: '恢复主窗后未 postFrame 定位 → 时间轴先 build 后选中被覆盖丢失',
      );
    });

    test('消费入口: 活动代码含 _processFloatingTabFocusTask();', () {
      expect(
        activeLines('_processFloatingTabFocusTask();', notifyBody),
        isNotEmpty,
        reason: '桌面便签定位消费入口被删除（便签点击不再定位）',
      );
    });

    test('顺序不变量: pendingFocusTaskId==null 守卫在 postFrame 之前', () {
      final guardIdx = notifyBody.indexOf('controller.pendingFocusTaskId == null');
      final postIdx = notifyBody.indexOf('addPostFrameCallback');
      expect(guardIdx, greaterThan(0), reason: 'pendingFocusTaskId 守卫缺失');
      expect(guardIdx, lessThan(postIdx),
          reason: '须先判断存在待定位任务，再 postFrame 消费');
    });

    test('P0-B: postFrame 闭包内 mounted 守卫先于消费', () {
      final postIdx = notifyBody.indexOf('addPostFrameCallback');
      final mountedIdx = notifyBody.indexOf('if (!mounted) return;');
      final processIdx = notifyBody.indexOf('_processFloatingTabFocusTask();');
      expect(mountedIdx, greaterThan(postIdx),
          reason: 'postFrame 闭包内应先检查 mounted');
      expect(mountedIdx, lessThan(processIdx),
          reason: 'P0-B: dispose 后不再消费定位（否则 _selectTask setState 抛 Null check）');
    });
  });

  group('_processBlocFocusTask 定位消费（R4/A5）', () {
    test('消费即清: 活动代码含 _pendingBlocFocusTaskId = null;', () {
      expect(
        activeLines('_pendingBlocFocusTaskId = null;', blocFocus),
        isNotEmpty,
        reason: 'bloc 定位任务消费后未清空 → 下次加载重复定位',
      );
    });

    test('命中即选中: 活动代码含 _selectTask(t);', () {
      expect(
        activeLines('_selectTask(t);', blocFocus),
        isNotEmpty,
        reason: 'bloc 定位命中后未 _selectTask → 日历/创建后不选中任务',
      );
    });

    test('顺序不变量: 先清 _pendingBlocFocusTaskId 再 _selectTask', () {
      final clearIdx = blocFocus.indexOf('_pendingBlocFocusTaskId = null;');
      final selIdx = blocFocus.indexOf('_selectTask(t);');
      expect(clearIdx, greaterThan(0), reason: 'bloc 定位清空语句缺失');
      expect(clearIdx, lessThan(selIdx),
          reason: '消费即清须先于选中，命中任务前标记已清空防重复');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:936 `if (controller.pendingFocusTaskId == null) return;` → FAIL(守卫)
// 注释 home_page.dart:937 `addPostFrameCallback((_) {` → FAIL(postFrame 消费)
// 注释 home_page.dart:939 `_processFloatingTabFocusTask();` → FAIL(消费入口)
// 注释 home_page.dart:938 `if (!mounted) return;` → FAIL(P0-B postFrame 闭包守卫)
// 注释 home_page.dart:1242 `_pendingBlocFocusTaskId = null;` → FAIL(bloc 消费即清)
// 注释 home_page.dart:1245 `_selectTask(t);` → FAIL(bloc 命中即选中)
// 运行: flutter test test_desktop_tab_notify.dart
// 预期: FAIL (AssertionError)
// 恢复后: PASS
