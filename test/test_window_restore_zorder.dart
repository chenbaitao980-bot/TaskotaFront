// 回归测试: 主窗恢复置前台 z 序（R3-2 前台已就绪跳过 TOPMOST）+ 关闭代际（R2-2）+ P0-1 回滚
// 变更点: restoreFullWindow 先读 isFocused，前台已聚焦时跳过 setAlwaysOnTop 双切（消除 z 序连爆闪烁）；
//   restore 入口 _closeRequestId 代际递增，打断进行中的关闭请求（令其放弃 hideToTray）；
//   hideToTray 删 setOpacity(0)（分层窗口病理回归源）。
// 本测试用 dart:io 读源文件做结构不变量断言（私有方法/原生窗口代码无法无头实例化）
// Layer: REGRESSION
// TestedSource: DesktopFloatingTabController.restoreFullWindow + hideToTray@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ctrl = File(
    'lib/core/desktop/desktop_floating_tab_controller.dart',
  ).readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker) => ctrl
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  // 取 open 关键字所在 { } 块（验证标记嵌套于指定作用域内）
  String blockAfter(String open) {
    final start = ctrl.indexOf(open);
    if (start < 0) return '';
    var depth = 0;
    for (var i = start; i < ctrl.length; i++) {
      final ch = ctrl[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return ctrl.substring(start, i + 1);
      }
    }
    return '';
  }

  group('R3-2 前台已就绪跳过 TOPMOST', () {
    test('restoreFullWindow 先读 isFocused 判定前台是否已就绪', () {
      expect(
        activeLines('final alreadyFocused = await windowManager.isFocused();'),
        isNotEmpty,
        reason: '须读 isFocused 判定前台就绪，已聚焦则跳过 TOPMOST（活动代码）',
      );
    });

    test(
      'TOPMOST 双切 setAlwaysOnTop(true)/(false) 位于 if (!alreadyFocused) 块内',
      () {
        expect(
          activeLines('if (!alreadyFocused) {'),
          isNotEmpty,
          reason: '前台未就绪分支缺失（活动代码）',
        );
        final topmostBlock = blockAfter('if (!alreadyFocused) {');
        expect(topmostBlock, isNotEmpty, reason: 'if (!alreadyFocused) 块未闭合');
        final inBlock = (String m) => topmostBlock
            .split('\n')
            .where((l) => l.contains(m) && !l.trimLeft().startsWith('//'))
            .toList();
        expect(
          inBlock('await windowManager.setAlwaysOnTop(true);'),
          isNotEmpty,
          reason: 'TOPMOST 提升 z 序必须在 if (!alreadyFocused) 内（活动代码）',
        );
        expect(
          inBlock('await windowManager.setAlwaysOnTop(false);'),
          isNotEmpty,
          reason: 'TOPMOST 解除也必须在同一分支内（活动代码）',
        );
      },
    );
  });

  group('restoreFullWindow 收尾与代际', () {
    test('TOPMOST 双切后仍以 focus() 收尾', () {
      expect(
        activeLines('await windowManager.focus();'),
        isNotEmpty,
        reason: '置前台后须 focus 获得键盘焦点（活动代码）',
      );
    });

    test('restore 入口 _closeRequestId 代际递增（R2-2 打断进行中关闭请求）', () {
      expect(
        activeLines('_closeRequestId++;'),
        isNotEmpty,
        reason: 'restore 须递增代际，使进行中的 hideToTray 放弃（活动代码）',
      );
    });
  });

  group('P0-1 hideToTray 回滚 setOpacity', () {
    test('hideToTray 不再调用 setOpacity(0)（分层窗口病理）', () {
      // 注释可含 setOpacity 字样，仅断言活动代码无调用
      final opLines = activeLines('setOpacity');
      expect(
        opLines,
        isEmpty,
        reason: 'setOpacity 活动代码残留（alpha=0 分层窗回归源）：${opLines.join('|')}',
      );
    });
  });
}

// === 破坏性验证 ===
// 在 lib/core/desktop/desktop_floating_tab_controller.dart 中:
//   1) 注释 :189 `final alreadyFocused = await windowManager.isFocused();` → 「先读 isFocused」变红
//   2) 注释/移除 :191-192 setAlwaysOnTop 双切（或移出 if 块）→ 「双切在 if(!alreadyFocused) 内」变红
//   3) 注释 :196 `await windowManager.focus();` → 「focus 收尾」变红
//   4) 注释 :168 `_closeRequestId++;` → 「代际递增」变红
//   5) 在 hideToTray 恢复 setOpacity(0) → 「hideToTray 无 setOpacity」变红
// 验证: flutter test test_window_restore_zorder.dart
