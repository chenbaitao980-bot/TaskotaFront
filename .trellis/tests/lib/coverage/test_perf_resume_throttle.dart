// 性能契约测试: P0-A/P1-E resume 节流（bf3e1cb 工作树）
// 原 bug: 回前台 onResume 每 6-12s 成对 LoadTasks 重载风暴（setAlwaysOnTop/便签第二引擎抢焦点）；
//   P0-A 移除 resume 秒级重调度（每任务 24 次平台通道取消，115 任务 ~6.4s 拖住首帧白屏）
// 修复方式: _lastResumeLoadTime 30s 节流守卫（命中直接 return）+ 保留 _debounceLoadTasks 本地刷新；
//   启动一次性重调度（_initStorage:302）是合法保留，不得误判为 resume 内残留
// 本测试用 dart:io 读源文件做结构不变量断言（_HomePageState 私有 State 无法无头实例化）
// Layer: GENERATED
// TestedSource: _HomePageState._onAppResume + _HomePageState._debounceLoadTasks@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 应用回前台（AppLifecycleListener.onResume）触发 _onAppResume；30s 内第二次触发
// Q2: 旧代码在这条件下会怎样？
// A2: 每次 resume 都 await _rescheduleTaskReminders()（每任务 24 次通道取消）+ 无节流
//     LoadTasks 重载风暴 → 首帧白屏
// Q3: 新代码在这条件下会怎样？
// A3: 30s 节流内第二次触发直接 return；节流外 _debounceLoadTasks() 本地刷新；
//     resume 内无 await 重调度（启动一次性重调度保留在 _initStorage）
//
// === 入参/出参标准 ===
// 入参: lib/presentation/pages/home/home_page.dart（当前工作树）
// 出参: 结构断言 — 节流字段声明 / 30s 守卫后 return 短路 / _debounceLoadTasks 保留 /
//       resume 方法体（_onAppResume→_debounceLoadTasks 边界）无 await 重调度 /
//       _initStorage 启动一次性重调度保留

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final home =
      File('lib/presentation/pages/home/home_page.dart').readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证注释活动行时测试必须能区分）
  List<String> activeLines(String marker, [String? haystack]) {
    final src = haystack ?? home;
    return src
        .split('\n')
        .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
        .toList();
  }

  // _onAppResume 方法体边界：签名处起，至 _debounceLoadTasks()（205）止。
  // _initStorage(302) 的启动一次性重调度在边界之外，不会被误判为 resume 内残留。
  final resumeBody = home
      .split('void _onAppResume()')
      .last
      .split('void _debounceLoadTasks()')
      .first;

  group('P1-E 30s 节流', () {
    test('节流字段 _lastResumeLoadTime 声明存在（活动代码）', () {
      expect(activeLines('DateTime? _lastResumeLoadTime;'), isNotEmpty,
          reason: '节流字段声明缺失（应含 DateTime? _lastResumeLoadTime;）');
    });

    test('30s 节流守卫后紧接 return 短路', () {
      final lines = resumeBody.split('\n');
      final guardIdx = lines.indexWhere((l) =>
          l.contains('now.difference(_lastResumeLoadTime!)') &&
          !l.trimLeft().startsWith('//'));
      expect(guardIdx, greaterThan(-1),
          reason: '30s 节流守卫缺失（活动代码）');
      expect(
          guardIdx + 1 < lines.length &&
              lines[guardIdx + 1].contains('return;'),
          isTrue,
          reason: '节流命中后必须 return 短路，不得继续重载');
    });
  });

  group('P0-A 移除 resume 秒级重调度', () {
    test('resume 方法体内无 await 重调度（_initStorage 边界外合法保留）', () {
      final activityLines = resumeBody
          .split('\n')
          .where((l) =>
              l.contains('_rescheduleTaskReminders') &&
              !l.trimLeft().startsWith('//') &&
              l.contains('await'))
          .toList();
      expect(activityLines, isEmpty,
          reason: 'resume 内残留 await 重调度：${activityLines.join('|')}');
    });
  });

  group('数据刷新链路保留（e4981d1 不变量）', () {
    test('resume 仍调用 _debounceLoadTasks 保本地刷新', () {
      expect(activeLines('_debounceLoadTasks();', resumeBody), isNotEmpty,
          reason: '回前台本地刷新调用被删除');
    });
  });

  group('启动一次性重调度（合法保留）', () {
    test('_initStorage 保留启动 await _rescheduleTaskReminders', () {
      final initBody = home.split('Future<void> _initStorage() async {').last;
      expect(activeLines('await _rescheduleTaskReminders();', initBody),
          isNotEmpty,
          reason: '启动一次性重调度被误删（仅 resume 内移除，非全删）');
    });
  });
}
// === 破坏性验证 ===
// 注释 home_page.dart:186 的 30s 守卫行（now.difference...）后运行:
//   flutter test test_perf_resume_throttle.dart
// 预期: FAIL (AssertionError: 30s 节流守卫缺失（活动代码）)
// 恢复后: PASS
