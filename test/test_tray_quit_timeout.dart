// 回归测试: 托盘"退出"路径强制 exit(0)（R1 退出竞态死代码修复）
// 变更点: 原 `await windowManager.destroy(); exit(0)` 中 exit(0) 是死代码——destroy() 发
//   PostQuitMessage → 主循环退出 → main() 返回 → CRT 引擎 teardown 在便签第二引擎线程
//   上挂起 → Dart 事件循环已死 → 后续 exit(0) 永不执行（窗口消失但进程存活、托盘图标残留）。
//   现改为直接 exit(0) 强制 ExitProcess 绕过 teardown；同步打点 task_exit.log 作实机证据。
//   注：初版 destroy().timeout(1s)+exit(0) 经实机复测进程仍存活，最终收敛为纯 exit(0)。
// 本测试用 dart:io 读源文件做结构不变量断言（托盘原生菜单点击无法无头实例化）
// Layer: REGRESSION
// TestedSource: initTray + _systemTray@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tray = File(
    'lib/platform/tray_service_desktop.dart',
  ).readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker) => tray
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  group('R1 退出路径强制 exit(0)', () {
    test('退出菜单 onClicked 活动代码含 exit(0) 强制退出', () {
      expect(
        activeLines('exit(0);'),
        isNotEmpty,
        reason: '托盘退出须直接 exit(0) 强制 ExitProcess（活动代码）',
      );
    });

    test('退出路径不再调用 windowManager.destroy()（消除 exit(0) 死代码前驱）', () {
      final destroyLines = activeLines('windowManager.destroy');
      expect(
        destroyLines,
        isEmpty,
        reason: 'destroy() 会使 exit(0) 变为竞态死代码，R1 已移除：${destroyLines.join('|')}',
      );
    });
  });
}

// === 破坏性验证 ===
// 在 lib/platform/tray_service_desktop.dart 中:
//   1) 注释 :56 `exit(0);` → 「exit(0) 强制退出」变红
//   2) 在 exit(0) 前恢复 `await windowManager.destroy();` → 「无 destroy」变红
//   （注意: :41-45 的 R1 注释含 windowManager.destroy 字样，不影响断言——注释行被过滤）
// 验证: flutter test test_tray_quit_timeout.dart
