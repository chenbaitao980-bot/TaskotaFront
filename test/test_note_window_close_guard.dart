// 回归测试: 便签窗防销毁（R2-1 创建即保护 + onWindowClose 兜底只隐藏不销毁）
// 变更点: setPreventClose(true) 提前到 runApp 前（消除"创建→首帧"无保护窗口期，
//   此期间 WM_CLOSE 可击穿销毁第二引擎 → 复用 note.show() 静默失败 → 便签消失）；
//   _NoteWindowCloseListener.onWindowClose 兜底：只 hide 不销毁引擎（双保险）。
// 本测试用 dart:io 读源文件做结构不变量断言（独立第二 Flutter 引擎无法无头实例化）
// Layer: REGRESSION
// TestedSource: _NoteWindowCloseListener + runNoteWindow@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final note = File(
    'lib/presentation/pages/floating_note/note_window_app.dart',
  ).readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker) => note
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  // 取 open 关键字所在 { } 块（验证标记嵌套于指定作用域内）
  String blockAfter(String open) {
    final start = note.indexOf(open);
    if (start < 0) return '';
    var depth = 0;
    for (var i = start; i < note.length; i++) {
      final ch = note[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return note.substring(start, i + 1);
      }
    }
    return '';
  }

  group('R2-1 创建即保护', () {
    test('setPreventClose(true) 为活动代码', () {
      expect(
        activeLines('await windowManager.setPreventClose(true);'),
        isNotEmpty,
        reason: 'note 窗须 setPreventClose(true) 防 WM_CLOSE 销毁（活动代码）',
      );
    });

    test('setPreventClose(true) 在 runApp 之前生效（无保护窗口期消除）', () {
      final preventIdx = note.indexOf(
        'await windowManager.setPreventClose(true);',
      );
      final runAppIdx = note.indexOf('runApp(const NoteWindowApp());');
      expect(
        preventIdx,
        greaterThanOrEqualTo(0),
        reason: 'setPreventClose 调用缺失',
      );
      expect(
        runAppIdx,
        greaterThan(preventIdx),
        reason: 'setPreventClose 须在 runApp 前生效（R2-1）',
      );
    });
  });

  group('onWindowClose 兜底只隐藏不销毁', () {
    test('存在 _NoteWindowCloseListener extends WindowListener', () {
      expect(
        activeLines('class _NoteWindowCloseListener extends WindowListener'),
        isNotEmpty,
        reason: 'note 引擎须注册关闭兜底监听（活动代码）',
      );
    });

    test('onWindowClose 只隐藏（c.hide()）不销毁（无 destroy）', () {
      final listenerBlock = blockAfter(
        'class _NoteWindowCloseListener extends WindowListener {',
      );
      expect(listenerBlock, isNotEmpty, reason: '监听器类未闭合');
      final blockActive = listenerBlock
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .toList();
      expect(
        blockActive.any((l) => l.contains('.then((c) => c.hide())')),
        isTrue,
        reason: 'onWindowClose 须走 WindowController.hide() 只隐藏引擎（活动代码）',
      );
      expect(
        blockActive.any((l) => l.contains('destroy')),
        isFalse,
        reason: 'onWindowClose 不得销毁引擎（活动代码禁止 destroy）',
      );
    });
  });
}

// === 破坏性验证 ===
// 在 lib/presentation/pages/floating_note/note_window_app.dart 中:
//   1) 注释 :39 `await windowManager.setPreventClose(true);` → 「setPreventClose 活动」变红
//   2) 将 :39 的调用移到 runApp(:44) 之后 → 「在 runApp 之前」变红（preventIdx > runAppIdx）
//   3) 注释 :57 `class _NoteWindowCloseListener ...` → 「存在兜底监听」变红
//   4) 将 :60-62 的 c.hide() 改为 c.destroy() 或注释掉 → 「只隐藏不销毁」变红
// 验证: flutter test test_note_window_close_guard.dart
