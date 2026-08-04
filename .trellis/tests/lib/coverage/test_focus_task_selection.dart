// 回归测试: 便签点击定位链路（BP3/BP5 + P0-B）— 仓库直查兜底 + 消费即清 + 选中必达
// 原 bug: 便签点击任务被项目排除/筛选时时间轴不含该任务 → 定位不命中任务"消失"（BP3）；
//   pendingFocusTaskId 消费后未清空 → 每次恢复窗口反复触发定位（BP5）；
//   State dispose 后定位回调 setState → Null check 崩溃（P0-B，flog 11:27:27 ×2）
// 修复方式: _processFloatingTabFocusTask 找不到任务时仓库直查兜底（A3）；命中即清
//   controller.pendingFocusTaskId = null（消费即清防重复）；结尾必走 _selectTask(task) 选中。
//   _selectTask 开头加 if(!mounted) return 守卫（P0-B），且 _modeSwitchGuard（c66ef28）
//   在 R1 跨天分支前 — 手动切换模式不被自动切换覆盖。
// 对应提交: bf3e1cb（工作树，BP1-BP5 + P0-B 已在 home_page.dart:1191/1410 落地）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomeContentState._processFloatingTabFocusTask + _HomeContentState._selectTask@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户点便签任务 → restoreFullWindow → _onDesktopTabNotify → _processFloatingTabFocusTask；
//     且该任务因项目排除/筛选不在 _timelineTasks 中；或窗口恢复瞬间 State 正在 dispose
// Q2: 旧代码在这条件下会怎样？
// A2: 时间轴不含任务 → 找不到 task 直接 return false，任务"消失"不选中（BP3）；
//     pendingFocusTaskId 未清 → 每恢复一次重复定位（BP5）；dispose 后 setState → Null check（P0-B）
// Q3: 新代码在这条件下会怎样？
// A3: 仓库直查兜底构造 _TimelineTask → 必走 _selectTask 选中；消费即清 pendingFocusTaskId；
//     _selectTask 开头 mounted 守卫 → dispose 后静默返回；_modeSwitchGuard 保持手动切换
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — A3 兜底存在 / 消费即清存在且先于兜底 / _selectTask 结尾 /
//       _selectTask 内 mounted 守卫 + _modeSwitchGuard + R1 且顺序正确

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

  // _processFloatingTabFocusTask 方法体（签名后 → 下一方法前）
  final tabFocus = src
      .split('Future<bool> _processFloatingTabFocusTask() async {')
      .last
      .split('bool _processBlocFocusTask()')
      .first;
  // _selectTask 方法体（签名后 → 下一方法前）
  final selectTask = src
      .split('void _selectTask(_TimelineTask task) {')
      .last
      .split('void _selectTaskFromQuadrant(')
      .first;

  group('BP3/A3 仓库直查兜底（任务不消失）', () {
    test('活动代码含 if (task == null && widget.taskRepository != null)', () {
      expect(
        activeLines('if (task == null && widget.taskRepository != null)', tabFocus),
        isNotEmpty,
        reason: '时间轴不含任务时仓库直查兜底被删除（BP3 任务消失复发）',
      );
    });

    test('兜底从 DB 直查 taskRepository.get(taskId)', () {
      expect(
        activeLines('final dbTask = await widget.taskRepository!.get(taskId);', tabFocus),
        isNotEmpty,
        reason: '仓库直查 get(taskId) 缺失 → 兜底无法取回被排除任务',
      );
    });

    test('兜底构造 _TimelineTask 穿透 isAllDay（R1 跨天判定依赖）', () {
      expect(
        activeLines('isAllDay: dbTask.isAllDay == 1', tabFocus),
        isNotEmpty,
        reason: '兜底构造未穿透 isAllDay → 选中后 R1 跨天切 day 失效',
      );
    });
  });

  group('BP5 消费即清（防重复定位）', () {
    test('活动代码含 controller.pendingFocusTaskId = null;', () {
      expect(
        activeLines('controller.pendingFocusTaskId = null;', tabFocus),
        isNotEmpty,
        reason: '定位后未清空 pendingFocusTaskId → 每次恢复窗口反复定位（BP5 复发）',
      );
    });

    test('消费即清先于仓库兜底（先清标记再查数据）', () {
      final clearIdx = tabFocus.indexOf('controller.pendingFocusTaskId = null;');
      final fallbackIdx =
          tabFocus.indexOf('if (task == null && widget.taskRepository != null)');
      expect(clearIdx, greaterThan(0), reason: '消费即清语句缺失');
      expect(clearIdx, lessThan(fallbackIdx),
          reason: '必须先消费 pendingFocusTaskId 再走兜底，否则兜底期间又触发');
    });
  });

  group('定位必选中（结尾 _selectTask）', () {
    test('活动代码含 _selectTask(task);', () {
      expect(
        activeLines('_selectTask(task);', tabFocus),
        isNotEmpty,
        reason: '兜底/命中后未调用 _selectTask → 便签点击不选中任务',
      );
    });

    test('_selectTask(task) 在兜底分支之后（结尾选中）', () {
      final fallbackIdx =
          tabFocus.indexOf('if (task == null && widget.taskRepository != null)');
      final selectIdx = tabFocus.indexOf('_selectTask(task);');
      expect(fallbackIdx, greaterThan(0), reason: '仓库兜底分支缺失');
      expect(fallbackIdx, lessThan(selectIdx),
          reason: '_selectTask(task) 必须在仓库兜底之后（兜底/命中统一走选中）');
    });

    test('定位成功 return true（跳过默认滚到 now）', () {
      expect(
        activeLines('return true;', tabFocus),
        isNotEmpty,
        reason: '定位成功未返回 true → _loadData 继续默认滚到 now 覆盖定位',
      );
    });
  });

  group('_selectTask 守卫不变量', () {
    test('P0-B mounted 守卫: 活动代码含 if (!mounted) return;', () {
      expect(
        activeLines('if (!mounted) return;', selectTask),
        isNotEmpty,
        reason: 'P0-B mounted 守卫被移除 → dispose 后 _selectTask setState 抛 Null check',
      );
    });

    test('c66ef28 不变量: 活动代码含 if (_modeSwitchGuard)', () {
      expect(
        activeLines('if (_modeSwitchGuard)', selectTask),
        isNotEmpty,
        reason: '手动切换守卫被移除 → 点任务自动切换覆盖手动选择的模式',
      );
    });

    test('R1 跨天判定: 活动代码含 _isMultiDayNode(task) || task.isAllDay', () {
      expect(
        activeLines('_isMultiDayNode(task) || task.isAllDay', selectTask),
        isNotEmpty,
        reason: '跨天/isAllDay 切 day 判定被移除（R1 回归）',
      );
    });

    test('顺序不变量: mounted 守卫 → _modeSwitchGuard → R1 跨天分支', () {
      final mountedIdx = selectTask.indexOf('if (!mounted) return;');
      final guardIdx = selectTask.indexOf('if (_modeSwitchGuard)');
      final r1Idx =
          selectTask.indexOf('_isMultiDayNode(task) || task.isAllDay');
      expect(mountedIdx, greaterThan(0), reason: 'mounted 守卫缺失');
      expect(mountedIdx, lessThan(guardIdx),
          reason: 'mounted 守卫必须最先执行（State 生命周期先于业务守卫）');
      expect(guardIdx, lessThan(r1Idx),
          reason: 'R1 必须在 _modeSwitchGuard 之后，手动切换不被 R1 强制切 day');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:1205 `if (task == null && widget.taskRepository != null)` → FAIL(A3 兜底)
// 注释 home_page.dart:1195 `controller.pendingFocusTaskId = null;` → FAIL(消费即清)
// 注释 home_page.dart:1234 `_selectTask(task);` → FAIL(定位必选中)
// 注释 home_page.dart:1412 `if (!mounted) return;` → FAIL(P0-B mounted 守卫)
// 注释 home_page.dart:1419 `if (_modeSwitchGuard)` → FAIL(c66ef28 手动切换守卫)
// 注释 home_page.dart:1425 `(_isMultiDayNode(task) || task.isAllDay)` → FAIL(R1 跨天判定)
// 运行: flutter test test_focus_task_selection.dart
// 预期: FAIL (AssertionError)
// 恢复后: PASS
