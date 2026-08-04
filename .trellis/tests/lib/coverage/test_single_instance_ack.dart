// 回归测试: 单实例握手 ack 分支 + 首实例常驻监听
// 变更点: _notifyExistingInstance 收到 taskora-ok ack → return !isTaskora（即 false）
//   令调用方退出（同款应用已接管）；tryAcquire 首实例 bind 成功 → _server!.listen
//   常驻处理握手（持 subscription 引用防 GC 关闭端口）。
// 补充 single_instance_test.dart 未覆盖的「收到 ack → 返回 false」分支。
// 本测试用 dart:io 读源文件做结构不变量断言（回环 socket 握手需真实 OS 端口，无头环境不可执行）
// Layer: REGRESSION
// TestedSource: SingleInstance.tryAcquire + _notifyExistingInstance@bf3e1cb072553db828e25b7fd3b67fdc2e61b50d

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final single = File('lib/platform/single_instance.dart').readAsStringSync();

  // 活动代码行 = 非注释行（R-G-R 红验证时注释掉活动行，测试必须能区分）
  List<String> activeLines(String marker) => single
      .split('\n')
      .where((l) => l.contains(marker) && !l.trimLeft().startsWith('//'))
      .toList();

  // 取 open 关键字所在 { } 块（验证标记嵌套于指定作用域内）
  String blockAfter(String open) {
    final start = single.indexOf(open);
    if (start < 0) return '';
    var depth = 0;
    for (var i = start; i < single.length; i++) {
      final ch = single[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return single.substring(start, i + 1);
      }
    }
    return '';
  }

  group('首实例常驻监听', () {
    test('tryAcquire bind 成功后 _server!.listen 常驻处理握手', () {
      expect(
        activeLines(
          '_server!.listen((client) => _handleHandshake(client, onActivate));',
        ),
        isNotEmpty,
        reason: '首实例须常驻监听端口接收握手（活动代码）',
      );
    });
  });

  group('第二实例 ack 分支', () {
    test('_notifyExistingInstance 用 ack 串比对判断同款应用', () {
      expect(
        activeLines('String.fromCharCodes(bytes).trim() == _handshakeAck'),
        isNotEmpty,
        reason: '须比对握手 ack 才能确认同款应用接管（活动代码）',
      );
    });

    test('收到 ack → return !isTaskora（即 false，令调用方退出）', () {
      final notifyBlock = blockAfter(
        'static Future<bool> _notifyExistingInstance() async {',
      );
      expect(
        notifyBlock,
        isNotEmpty,
        reason: '_notifyExistingInstance 未找到或未闭合',
      );
      final blockActive = notifyBlock
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .toList();
      expect(
        blockActive.any((l) => l.contains('return !isTaskora;')),
        isTrue,
        reason: '收到 ack 应返回 false（同款已接管，本实例退出）（活动代码）',
      );
    });
  });
}

// === 破坏性验证 ===
// 在 lib/platform/single_instance.dart 中:
//   1) 注释 :33 `_server!.listen(...)` → 「首实例常驻监听」变红
//   2) 注释 :71 `String.fromCharCodes(bytes).trim() == _handshakeAck` → 「ack 比对」变红
//   3) 将 :73 `return !isTaskora;` 改为 return true / 注释掉 → 「ack→false」变红
// 验证: flutter test test_single_instance_ack.dart
