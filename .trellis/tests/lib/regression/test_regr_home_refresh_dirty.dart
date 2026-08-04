// 回归测试: 切换回首页脏标记刷新 + 回前台数据刷新链路（e4981d1 + 本次便签直连监听）
// 原 bug: 后台 tab 修改任务时间后，BlocListener 因 _visible=false 丢弃事件；切回首页时
//   仅 setState 不调用 _loadData，导致时间轴/逾期不更新（e4981d1 引入 _needsRefresh 脏标记）
// 修复方式: _needsRefresh 标记后台变化，切回时按需刷新（不变量）；本次 P0-A/P1-E 将
//   _onAppResume 的 _rescheduleTaskReminders 移除 + 加 30s 节流，但不得破坏数据刷新链路
// 对应提交: e4981d1（历史）+ bf3e1cb 工作树（P0-A/P1-E 修改 _onAppResume）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State 无法无头实例化）
// Layer: REGRESSION
// TestedSource: _HomePageState._onAppResume + _debounceLoadTasks@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 应用回前台（AppLifecycleListener.onResume）触发 _onAppResume；30s 内第二次触发
// Q2: 旧代码在这条件下会怎样？
// A2: 每次 resume 都 await _rescheduleTaskReminders()（每任务 24 次平台通道取消调用，
//     115 任务 ~6.4s 拖住首帧白屏）；无节流时 6-12s 成对 LoadTasks 重载风暴
// Q3: 新代码在这条件下会怎样？
// A3: 30s 节流内第二次触发直接 return；节流外触发 _debounceLoadTasks()（保留本地刷新），
//     不再 await reschedule；本测试断言节流守卫存在 + _debounceLoadTasks 保留 + 无 await reschedule
//
// === 入参/出参标准 ===
// 入参: home_page.dart 源文件（当前工作树）
// 出参: 结构断言 — _lastResumeLoadTime 节流守卫 / _debounceLoadTasks 调用保留 /
//       _onAppResume 内无 await _rescheduleTaskReminders / _needsRefresh 脏标记仍存在

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home =
      File('lib/presentation/pages/home/home_page.dart').readAsStringSync();

  group('P1-E resume 30s 节流', () {
    test('_onAppResume 含 _lastResumeLoadTime 30s 节流守卫', () {
      expect(home.contains('_lastResumeLoadTime'), isTrue,
          reason: '节流字段缺失');
      expect(
        home.contains(
            'now.difference(_lastResumeLoadTime!) < const Duration(seconds: 30)'),
        isTrue,
        reason: '30s 节流守卫缺失');
    });
  });

  group('P0-A 移除 resume 秒级重调度', () {
    test('_onAppResume 内不再 await _rescheduleTaskReminders', () {
      // _onAppResume 后紧跟 void _debounceLoadTasks()，以此为方法体边界；
      // _initStorage（292 行）的启动一次 reschedule 调用是允许保留的，不在本断言范围内。
      final resumeBody = home.split('Future<void> _onAppResume()').last;
      final resumeSnippet = resumeBody.split('void _debounceLoadTasks()').first;
      final activityLines = resumeSnippet
          .split('\n')
          .where((l) =>
              l.contains('_rescheduleTaskReminders') &&
              !l.trimLeft().startsWith('//') &&
              l.contains('await'))
          .toList();
      expect(activityLines, isEmpty,
          reason: '_onAppResume 内残留 await _rescheduleTaskReminders：${activityLines.join('|')}');
    });
  });

  group('数据刷新链路保留（e4981d1 不变量）', () {
    test('_onAppResume 仍调用 _debounceLoadTasks 保本地刷新', () {
      final resumeBody = home.split('Future<void> _onAppResume()').last;
      final resumeSnippet = resumeBody.split('void _debounceLoadTasks()').first;
      expect(resumeSnippet.contains('_debounceLoadTasks();'), isTrue,
          reason: '回前台数据刷新调用被删除');
    });

    test('_needsRefresh 脏标记仍存在（后台变化切回首页按需刷新）', () {
      expect(home.contains('_needsRefresh'), isTrue,
          reason: 'e4981d1 脏标记被移除');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:197 的 `_debounceLoadTasks();` 后运行:
//   flutter test test_regr_home_refresh_dirty.dart
// 预期: FAIL (AssertionError: 回前台数据刷新调用被删除)
// 恢复后: PASS
