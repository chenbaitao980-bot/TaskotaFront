import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 单实例互斥锁（Windows 桌面端专用）：本地回环 socket 独占固定端口。
///
/// 为什么用 socket 而非 pid 锁文件：进程异常退出后端口由 OS 自动释放，无陈旧锁文件
/// 残留；且握手协议能区分"同款应用"与"无关程序占端口"，比文件锁更可靠。
///
/// 首实例：bind 成功 → 常驻 accept，收到握手 → 回调唤起主窗。
/// 第二实例：bind 失败 → 连接端口发握手 → 收到 taskora-ok → 返回 false（调用方 exit）。
/// 无关程序占端口：握手无 ack → 返回 true 放行（无法确认是同款，避免误杀用户应用）。
class SingleInstance {
  SingleInstance._();

  /// 固定回环端口：选高位端口，避开常见服务端口。
  static const int port = 49527;

  static const String _handshakeRequest = 'taskora-show';
  static const String _handshakeAck = 'taskora-ok';
  static const Duration _timeout = Duration(seconds: 2);

  static ServerSocket? _server;

  /// 尝试成为首实例。返回 true = 本实例继续运行；false = 已有实例，调用方应退出。
  static Future<bool> tryAcquire({void Function()? onActivate}) async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      // 持有 subscription 引用，确保监听常驻（否则可能被 GC 关闭端口）。
      _server!.listen((client) => _handleHandshake(client, onActivate));
      return true;
    } on SocketException {
      return _notifyExistingInstance();
    }
  }

  static Future<void> _handleHandshake(
    Socket client,
    void Function()? onActivate,
  ) async {
    try {
      final bytes = await client.first.timeout(_timeout);
      if (String.fromCharCodes(bytes).trim() == _handshakeRequest) {
        client.add(utf8.encode('$_handshakeAck\n'));
        await client.flush();
        onActivate?.call();
      }
    } catch (_) {
      // 握手超时/内容不符：无关程序占用端口，忽略。
    } finally {
      try {
        await client.close();
      } catch (_) {}
    }
  }

  static Future<bool> _notifyExistingInstance() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: _timeout,
      );
      socket.add(utf8.encode('$_handshakeRequest\n'));
      await socket.flush();
      final bytes = await socket.first.timeout(_timeout);
      final isTaskora = String.fromCharCodes(bytes).trim() == _handshakeAck;
      // 收到 ack → 同款应用已接管 → 本实例退出（返回 false）；否则放行。
      return !isTaskora;
    } catch (_) {
      // 连接失败/超时/无数据：无法确认占用者 → 放行本实例，避免误杀用户应用。
      return true;
    } finally {
      try {
        await socket?.close();
      } catch (_) {}
    }
  }

  /// 释放占用的端口，允许同一进程内再次获取（测试专用）。
  /// 正常流程进程退出时端口由 OS 自动释放，无需调用。
  static Future<void> resetForTest() async {
    await _server?.close();
    _server = null;
  }
}
