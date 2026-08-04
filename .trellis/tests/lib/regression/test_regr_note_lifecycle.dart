// 回归测试: 便签窗生命周期 + 闸门 + 通道协议（ea86621 V3/V4）
// 变更点: 控制器重写（_enterFloatingMode 删除 → 便签窗懒建复用 + 跨窗协议）+ 便签引擎通道
// 本测试用 dart:io 读源文件做结构不变量断言（私有 State/窗口代码无法无头实例化）
// Layer: REGRESSION
// TestedSource: handleCloseRequested + restoreFullWindow + _ensureNoteWindow + _showNoteWindow + _registerMainWindowChannel + _registerNoteChannelHandler + _NoteWindowHome@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ctrl =
      File('lib/core/desktop/desktop_floating_tab_controller.dart').readAsStringSync();
  final note =
      File('lib/presentation/pages/floating_note/note_window_app.dart').readAsStringSync();

  group('关闭闸门与候选', () {
    test('handleCloseRequested 闸门：非Windows/转换中/不可显示/未启用/dismissed 均仅隐藏', () {
      expect(ctrl.contains('if (!isWindows || _isTransitioning)'), isTrue);
      expect(
        ctrl.contains(
            'if (!_canShowFloatingTab || !_defaultEnabled || _dismissedUntilRestore)'),
        isTrue,
        reason: '关闭闸门缺失（canShow/enabled/dismissed 任一不满足只隐藏）');
      expect(ctrl.contains('_dismissedUntilRestore = false'),
          isTrue, reason: 'restore 时重置 dismissed');
    });

    test('_selectTaskForFloatingTab 候选池=未完成(0/1)+deleted0+archived0', () {
      expect(ctrl.contains('task.status == 0 || task.status == 1'), isTrue,
          reason: '候选池须含待办+进行中');
      expect(ctrl.contains('task.deleted == 0'), isTrue);
      expect(ctrl.contains('task.archived == 0'), isTrue);
    });

    test('无候选 → 仅隐藏（不弹便签）', () {
      expect(ctrl.contains('if (candidates.isEmpty) return null;'), isTrue,
          reason: '无候选时 _selectTaskForFloatingTab 应返回 null');
      expect(ctrl.contains('if (candidate == null)'), isTrue,
          reason: 'handleCloseRequested 无候选分支缺失');
    });
  });

  group('便签窗生命周期', () {
    test('restoreFullWindow 写 pendingFocus 并重置 dismissed + 隐藏便签 + show/focus', () {
      expect(ctrl.contains('pendingFocusTaskId = openTaskId;'), isTrue,
          reason: 'restore 时应写入待定位任务');
      expect(ctrl.contains('pendingFocusRequestToken = DateTime.now().microsecondsSinceEpoch;'), isTrue);
      expect(ctrl.contains('await windowManager.show();'), isTrue);
      expect(ctrl.contains('await windowManager.focus();'), isTrue);
    });

    test('便签窗懒建一次（_ensureNoteWindow 复用规避 #484 句柄泄漏）', () {
      expect(ctrl.contains('if (_noteWindow != null) return;'), isTrue,
          reason: '便签窗应懒建一次、后续复用');
    });

    test('首次创建不立即 show（等便签引擎渲染后自显示，消白屏）', () {
      expect(ctrl.contains('final wasCreated = _noteWindow != null;'), isTrue,
          reason: '_showNoteWindow 须区分首次创建与复用');
      expect(ctrl.contains('if (wasCreated)'), isTrue,
          reason: '仅复用时才 notifyTask + show');
    });

    test('主窗收命令 handler：showMain→restoreFullWindow / dismissNote→closeFloatingTab', () {
      expect(ctrl.contains("case 'showMain':"), isTrue);
      expect(ctrl.contains('await restoreFullWindow(openTaskId: openTaskId);'), isTrue,
          reason: 'showMain 应唤起主窗并带 openTaskId 定位');
      expect(ctrl.contains("case 'dismissNote':"), isTrue);
      expect(ctrl.contains('await closeFloatingTab();'), isTrue,
          reason: 'dismissNote 应置 dismissed');
    });
  });

  group('便签引擎通道', () {
    test('notifyTask 用 _parseSummary 解析载荷（String/Map 均可）', () {
      expect(note.contains('noteSummaryNotifier.value = _parseSummary(call.arguments);'), isTrue,
          reason: 'notifyTask 应通过 _parseSummary 统一解析摘要');
      expect(note.contains('if (raw is String)'), isTrue,
          reason: '_parseSummary 应支持 String JSON');
      expect(note.contains('if (raw is Map)'), isTrue,
          reason: '_parseSummary 应支持 Map');
    });

    test('便签窗收 notifyTask/hideNote', () {
      expect(note.contains("case 'notifyTask':"), isTrue);
      expect(note.contains("case 'hideNote':"), isTrue);
    });

    test('_NoteWindowHome：无摘要显示空壳，有摘要渲染卡片', () {
      expect(note.contains('if (summary == null) return const SizedBox.shrink();'), isTrue,
          reason: '无摘要时便签窗应显示空壳而非白屏');
      expect(note.contains('DesktopFloatingTaskTab('), isTrue);
    });

    test('点便签自隐并 invoke showMain；关闭 invoke dismissNote', () {
      expect(note.contains("invokeMethod('showMain', {'openTaskId': taskId})"), isTrue,
          reason: '点击便签应通知主窗唤起定位');
      expect(note.contains("invokeMethod('dismissNote')"), isTrue);
    });
  });
}
