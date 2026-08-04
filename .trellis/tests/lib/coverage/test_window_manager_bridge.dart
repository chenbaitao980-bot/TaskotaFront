// 回归测试: 主窗关闭链路 await 化（R2-2 竞态修复）
// 变更点: _TrayCloseListener.onWindowClose 由 fire-and-forget 改 await handler()，
//   消除 handleCloseRequested 未完成即隐藏的竞态（便签窗创建期间主窗被跳过）。
// 本测试用 dart:io 读源文件做结构不变量断言（WindowListener 原生回调无法无头实例化）
// Layer: REGRESSION
// TestedSource: _TrayCloseListener + setupCloseToTray@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bridge = File(
    'lib/platform/window_manager_bridge_desktop.dart',
  ).readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker) => bridge
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  // 取 open 关键字所在 { } 块（验证标记嵌套于指定作用域内）
  String blockAfter(String open) {
    final start = bridge.indexOf(open);
    if (start < 0) return '';
    var depth = 0;
    for (var i = start; i < bridge.length; i++) {
      final ch = bridge[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return bridge.substring(start, i + 1);
      }
    }
    return '';
  }

  group('R2-2 关闭链路 await 化', () {
    test('存在 _TrayCloseListener extends WindowListener', () {
      expect(
        activeLines('class _TrayCloseListener extends WindowListener'),
        isNotEmpty,
        reason: '关闭到托盘须经 WindowListener 回调（活动代码）',
      );
    });

    test('onWindowClose 为 async 且 await handler()（竞态修复）', () {
      final closeBlock = blockAfter('Future<void> onWindowClose() async {');
      expect(closeBlock, isNotEmpty, reason: 'onWindowClose 未找到或未闭合');
      final blockActive = closeBlock
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .toList();
      expect(
        blockActive.any((l) => l.contains('await handler();')),
        isTrue,
        reason: 'onWindowClose 须 await 关闭请求 handler（活动代码）',
      );
      expect(
        blockActive.any((l) => l.contains('await windowManager.hide();')),
        isTrue,
        reason: '兜底路径须 await hide（活动代码）',
      );
    });
  });
}

// === 破坏性验证 ===
// 在 lib/platform/window_manager_bridge_desktop.dart 中:
//   1) 注释 :45 `class _TrayCloseListener ...` → 「存在 _TrayCloseListener」变红
//   2) 将 :52 `await handler();` 改回无 await 的 handler(); → 「await handler」变红
//   3) 注释 :56 `await windowManager.hide();` → 「兜底 hide await」变红
// 验证: flutter test test_window_manager_bridge.dart
