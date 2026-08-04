// 回归测试: 时间轴自动切换 + _modeSwitchGuard（c66ef28 / f11eb24 / c233936）
// 原 bug: 手动切换天/小时模式后，_selectTask 的自动切换会把模式跳回（c66ef28）
// 修复方式: _selectTask 开头加 _modeSwitchGuard 守卫 — 用户手动切换时置位，跳过自动切换
// 本次变更: _selectTask 新增 R1（跨天/isAllDay 且 hour → 切 day），必须在 _modeSwitchGuard
//          之后执行，否则手动切换模式后点跨天任务会被强制切回 day（破坏 c66ef28）
// 对应提交: c66ef28(守卫) → f11eb24(模式切换) → ea86621(R1 新增)
// Layer: REGRESSION
//
// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户在 hour 模式手动切到 day（_modeSwitchGuard=true 期间），随后点选任务
// Q2: 旧代码在这条件下会怎样？
// A2: 若无守卫或 R1 在守卫前，自动切换把模式跳回 hour/day（c66ef28 前的 bug）
// Q3: 新代码在这条件下会怎样？
// A3: 守卫在 R1 前 → 手动切换不被覆盖；R1 只在正常点选时对跨天/isAllDay 生效
//
// 本测试用 dart:io 读取源文件做"顺序不变量"断言：无法无头实例化私有 State，
// 结构断言精确锁定守卫→R1→旧自动切换的执行顺序，防止未来改动打乱。

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// TestedSource: _selectTask + _modeSwitchGuard@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
void main() {
  final srcFile = 'lib/presentation/pages/home/home_page.dart';
  final src = File(srcFile).readAsStringSync();

  group('时间轴模式切换守卫回归', () {
    test('_modeSwitchGuard 字段存在', () {
      expect(src.contains('bool _modeSwitchGuard = false;'), isTrue,
          reason: 'c66ef28 引入的手动切换守卫字段被移除');
    });

    test('_selectTask 内守卫检查在 R1 跨天分支之前', () {
      final guardIdx = src.indexOf('if (_modeSwitchGuard)');
      final r1Idx = src.indexOf('_isMultiDayNode(task) || task.isAllDay');
      expect(guardIdx, greaterThan(0), reason: '_modeSwitchGuard 检查缺失');
      expect(r1Idx, greaterThan(0), reason: 'R1 跨天分支缺失');
      expect(guardIdx, lessThan(r1Idx),
          reason: 'R1 必须在 _modeSwitchGuard 之后执行，否则手动切换会被强制切回 day');
    });

    test('R1 只在 hour 模式触发（跨天/isAllDay 切 day）', () {
      expect(
        src.contains(
            "if ((_isMultiDayNode(task) || task.isAllDay) && _timelineMode == 'hour')"),
        isTrue,
        reason: 'R1 条件缺失或条件被改动（应只在 hour 模式触发）',
      );
    });

    test('旧自动切换规则仍在（非今天+hour→day；今天+day→hour）', () {
      expect(src.contains("if (!isToday && _timelineMode == 'hour')"), isTrue,
          reason: '旧规则:非今天小时任务切 day 被移除');
      expect(src.contains("else if (isToday && _timelineMode == 'day')"), isTrue,
          reason: '旧规则:今天天视图任务切 hour 被移除');
    });

    test('_TimelineTask 新增 isAllDay 字段并默认 false', () {
      expect(src.contains('final bool isAllDay;'), isTrue,
          reason: '_TimelineTask 缺少 isAllDay 字段');
      expect(src.contains('this.isAllDay = false,'), isTrue,
          reason: 'isAllDay 应默认 false');
    });

    test('_loadData 从 DB Task 带出 isAllDay（t.isAllDay == 1）', () {
      expect(src.contains('isAllDay: t.isAllDay == 1,'), isTrue,
          reason: '时间轴任务构造未穿透 isAllDay 字段（R1 判定会失效）');
    });

    test('四象限高亮 isSelected 存在（主色描边）', () {
      expect(src.contains('final isSelected = task.id == _selectedTaskId;'), isTrue,
          reason: '四象限高亮 taskItem(isSelected) 缺失');
      expect(src.contains('color: AppTheme.primaryColor.withValues(alpha: 0.08)'), isTrue,
          reason: '高亮背景色缺失');
    });

    test('R1 分支 return 后不执行旧的 isToday 判定（跨天 start 今天不再推进 hour）', () {
      // R1 修复的是"跨天 start 今天被推进 hour"缺陷：R1 命中时直接 return
      final r1Start = src.indexOf('_isMultiDayNode(task) || task.isAllDay');
      final r1Block = src.substring(r1Start, r1Start + 400);
      expect(r1Block.contains('return;'), isTrue,
          reason: 'R1 命中后应 return，避免继续走 isToday 逻辑把跨天任务推进 hour');
    });
  });
}
