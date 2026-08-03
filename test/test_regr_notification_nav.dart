// 回归测试: 通知点击导航 + postFrame 时序（6cac55f / 0c8c6ed）
// 原 bug: 过期任务通知弹窗点击导航行为异常/重复弹窗（6cac55f 修"点击导航、防重复、去冗余"；
//         0c8c6ed 修"点击逾期提醒跳转最早逾期任务"）
// 本次变更: postFrame 在 _processPendingNotificationTask 后新增 _processFloatingTabFocusTask，
//         仅当 focus 未命中才 _scrollToNow。必须保持"通知处理在前"的既有时序。
// 对应提交: 6cac55f → 0c8c6ed → ea86621(focus 消费)
// Layer: REGRESSION
//
// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: _loadData postFrame 回调触发
// Q2: 旧代码在这条件下会怎样？
// A2: _processPendingNotificationTask() 后无条件 _scrollToNow
// Q3: 新代码在这条件下会怎样？
// A3: 通知处理在前；focus 命中则跳过 _scrollToNow；未命中则保持原 _scrollToNow（行为等价）

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// TestedSource: _processFloatingTabFocusTask + _processPendingNotificationTask@425e7564f1881ab73d67f37b83b673f31427bd37
void main() {
  test('postFrame 时序：通知处理 → focus 消费 → 未命中才 scrollToNow', () {
    final src = File('lib/presentation/pages/home/home_page.dart')
        .readAsStringSync();
    final notifIdx = src.indexOf('_processPendingNotificationTask();');
    final focusIdx = src.indexOf('_processFloatingTabFocusTask();');
    final scrollIdx = src.indexOf('if (!focused) _scrollToNow(animated: false);');

    expect(notifIdx, greaterThan(0), reason: '通知处理调用缺失');
    expect(focusIdx, greaterThan(0), reason: '便签 focus 消费调用缺失');
    expect(scrollIdx, greaterThan(0), reason: 'scrollToNow 兜底调用缺失');
    expect(notifIdx, lessThan(focusIdx),
        reason: '通知处理必须仍在 focus 消费之前（6cac55f 时序被破坏）');
    expect(focusIdx, lessThan(scrollIdx),
        reason: 'focus 消费应在 scrollToNow 之前');
  });

  test('_processPendingNotificationTask 本身未被移除', () {
    final src = File('lib/presentation/pages/home/home_page.dart')
        .readAsStringSync();
    expect(src.contains('void _processPendingNotificationTask()'), isTrue,
        reason: '通知点击导航处理函数被移除');
  });
}
