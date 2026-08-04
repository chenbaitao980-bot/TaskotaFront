import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/platform/single_instance.dart';

void main() {
  tearDown(() async {
    // 释放端口，避免影响后续用例/真实应用（本文件测试环境无真实应用）。
    await SingleInstance.resetForTest();
  });

  test('无关程序占端口（不响应握手）→ tryAcquire 放行返回 true', () async {
    // 用不回 ack 的裸监听模拟无关程序占住固定端口。
    final blocker = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      SingleInstance.port,
    );
    final requests = <String>[];
    blocker.listen((client) async {
      final bytes = await client.first;
      requests.add(String.fromCharCodes(bytes).trim());
      await client.close(); // 读握手但不回 ack
    });

    final result = await SingleInstance.tryAcquire();

    expect(requests, contains('taskora-show')); // 确实发出了握手
    expect(result, isTrue); // 无 ack → 放行本实例，避免误杀用户应用
    await blocker.close();
  });

  test('首实例占端口：tryAcquire 首返回 true，第二实例返回 false 且触发 onActivate', () async {
    var activated = false;

    // 场景1：无其他实例 → 成为首实例（bind 成功，返回 true 并常驻监听）
    final primary = await SingleInstance.tryAcquire(
      onActivate: () => activated = true,
    );
    expect(primary, isTrue);

    // 场景2：模拟第二实例再启动 → bind 失败 → 握手 → 返回 false（调用方应退出）
    final secondary = await SingleInstance.tryAcquire();
    expect(secondary, isFalse);

    // 场景3：首实例收到第二实例握手 → onActivate 回调被触发（唤起主窗）
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(activated, isTrue);
  });
}
