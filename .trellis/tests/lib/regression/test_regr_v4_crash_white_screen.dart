// 回归测试: V4 崩溃+白屏修复（方案 A，用户 2026-08-03 确认）
// 原 bug: 关闭主窗 → 弹白屏小窗 → 整个应用崩溃消失
// 根因1(崩溃): _initNoteWindowChrome 漏 waitUntilReadyToShow() 直接 setSkipTaskbar(true)
//             → taskbar_ 空指针 0xc0000005 → window_manager_plugin.dll 崩溃（同进程多引擎连锁）
// 根因2(白屏): 主引擎 create 后立即 note.show()，便签引擎未 runApp 窗口无内容
// 修复方式: 首帧 postFrame 后才初始化 chrome + show（渲染后自显示）；waitUntilReadyToShow 在 setSkipTaskbar 前
// 对应提交: ea86621（V4 方案 A）
// Layer: REGRESSION
// TestedSource: _initNoteWindowChrome + runNoteWindow@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d
//
// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户关闭主窗，控制器创建便签窗（第二引擎），便签引擎初始化窗口 chrome
// Q2: 旧代码在这条件下会怎样？
// A2: setSkipTaskbar 解引用空 taskbar_ → 0xc0000005 崩溃 → 主进程消失
// Q3: 新代码在这条件下会怎样？
// A3: waitUntilReadyToShow 先初始化 taskbar_ → 不崩；首帧渲染后 show → 不白屏

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/presentation/pages/floating_note/note_window_app.dart')
      .readAsStringSync();

  group('V4 崩溃修复回归', () {
    test('waitUntilReadyToShow 必须在 setSkipTaskbar 之前', () {
      final readyIdx = src.indexOf('waitUntilReadyToShow()');
      final skipIdx = src.indexOf('setSkipTaskbar(true)');
      expect(readyIdx, greaterThan(0), reason: 'waitUntilReadyToShow 缺失（崩溃根因）');
      expect(skipIdx, greaterThan(0), reason: 'setSkipTaskbar 缺失');
      expect(readyIdx, lessThan(skipIdx),
          reason: '必须先初始化 taskbar_（waitUntilReadyToShow）再 setSkipTaskbar，否则空指针崩溃');
    });

    test('便签窗以 hiddenAtLaunch 创建（渲染后自显示，规避白屏）', () {
      final ctrl = File('lib/core/desktop/desktop_floating_tab_controller.dart')
          .readAsStringSync();
      expect(ctrl.contains('hiddenAtLaunch: true'), isTrue,
          reason: '便签窗创建必须 hiddenAtLaunch，由便签引擎渲染首帧后自显示');
    });

    test('chrome 初始化末尾才 show（渲染后显示，消白屏）', () {
      final showIdx = src.indexOf('windowManager.show();');
      final bgIdx = src.indexOf('setBackgroundColor');
      expect(showIdx, greaterThan(0), reason: 'show 调用缺失');
      expect(bgIdx, greaterThan(0));
      expect(bgIdx, lessThan(showIdx),
          reason: '先设置透明背景与样式，最后 show');
    });

    test('首帧后初始化 chrome（runNoteWindow addPostFrameCallback）', () {
      expect(src.contains('addPostFrameCallback'), isTrue,
          reason: 'chrome 初始化应在首帧渲染后，而非 runApp 前');
    });

    test('main.dart 便签引擎分支：role==note 时 runNoteWindow 并跳过业务初始化', () {
      final mainSrc = File('lib/main.dart').readAsStringSync();
      expect(mainSrc.contains('await runNoteWindow();'), isTrue,
          reason: 'main() 便签引擎分支缺失');
      expect(mainSrc.contains('_isNoteWindowRole'), isTrue,
          reason: 'role 判定缺失');
    });
  });
}
