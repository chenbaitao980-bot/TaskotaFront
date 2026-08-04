// 回归测试: 窗口恢复置前台 + 无分层窗口病理（P0-1 回滚 setOpacity + P0-2 TOPMOST 置前台）
// 原 bug: setOpacity(0)/setOpacity(1) 使主窗变 WS_EX_LAYERED 分层窗口且 alpha=0 全透明
//   → show() 时不可见需点任务栏 + 分层窗口渲染节流全窗卡顿（第三次报告复发根因）
// 修复方式: hideToTray 删 setOpacity(0)；restoreFullWindow 改 show()→setAlwaysOnTop(true)→
//   setAlwaysOnTop(false)→focus()（HWND_TOPMOST 强制提升 z 序绕过前台锁）
// 对应提交: bf3e1cb（工作树未提交，P0-1/P0-2 已在 controller:165-211 落地）
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State/原生窗口代码无法无头实例化）
// Layer: REGRESSION
// TestedSource: DesktopFloatingTabController.restoreFullWindow + hideToTray@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

// === 必问三答 ===
// Q1: 触发条件是什么？
// A1: 用户点便签/任务栏图标/tray 恢复主窗（restoreFullWindow），或隐藏主窗（hideToTray）
// Q2: 旧代码在这条件下会怎样？
// A2: restoreFullWindow 的 show() 在 setOpacity(0) 已置透明时执行 → 窗口不可见需点任务栏；
//     WS_EX_LAYERED 分层窗口 → 全窗卡顿；旧测试若断言 setOpacity 存在 → FAIL（已删除）
// Q3: 新代码在这条件下会怎样？
// A3: 无 setOpacity；restoreFullWindow 用 setAlwaysOnTop(true/false) 双切绕过前台锁 →
//     主窗直接弹出置顶；本测试断言 setOpacity 不存在 + TOPMOST 双切存在 → PASS
//
// === 入参/出参标准 ===
// 入参: desktop_floating_tab_controller.dart 源文件（当前工作树）
// 出参: 结构断言 — 无 setOpacity 调用 / 有 setAlwaysOnTop(true) + (false) / 有 focus()

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ctrl =
      File('lib/core/desktop/desktop_floating_tab_controller.dart').readAsStringSync();

  group('P0-1 回滚 setOpacity（分层窗口病理）', () {
    test('hideToTray 不再调用 setOpacity(0)', () {
      // 删除 setOpacity(0) 后源文件应无 setOpacity 活动调用（注释可含字样）
      final activityLines = ctrl
          .split('\n')
          .where((l) => l.contains('setOpacity') && !l.trimLeft().startsWith('//'))
          .toList();
      expect(activityLines, isEmpty,
          reason: 'setOpacity 活动代码残留：${activityLines.join('|')}');
    });
  });

  group('P0-2 TOPMOST 置前台', () {
    // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
    List<String> activeLines(String marker) => ctrl
        .split('\n')
        .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
        .toList();

    test('restoreFullWindow 含 setAlwaysOnTop(true)+setAlwaysOnTop(false) 双切', () {
      expect(activeLines('await windowManager.setAlwaysOnTop(true);'), isNotEmpty,
          reason: '置前台须先 TOPMOST 提升 z 序（活动代码）');
      expect(activeLines('await windowManager.setAlwaysOnTop(false);'), isNotEmpty,
          reason: '置前台后须解除 TOPMOST（活动代码）');
    });

    test('restoreFullWindow 后仍有 focus() 收尾', () {
      expect(activeLines('await windowManager.focus();'), isNotEmpty,
          reason: 'TOPMOST 双切后仍须 focus 获得键盘焦点（活动代码）');
    });
  });
}
// === 破坏性验证 ===
// 在 lib/core/desktop/desktop_floating_tab_controller.dart:191-192 注释 setAlwaysOnTop 双切后运行:
//   flutter test test_regr_window_restore_topmost.dart
// 预期: FAIL (AssertionError: 置前台须先 TOPMOST 提升 z 序)
// 恢复后: PASS
