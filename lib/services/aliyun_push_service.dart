import 'dart:io' show Platform;
import 'package:aliyun_push/aliyun_push.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/router/app_router.dart';
import '../core/utils/file_logger.dart';
import 'notification_service.dart';

/// 阿里云移动推送服务
/// 负责初始化 SDK、获取设备 deviceId、注册回调并上传到 Supabase。
class AliyunPushService {
  static final AliyunPushService _instance = AliyunPushService._internal();
  factory AliyunPushService() => _instance;
  AliyunPushService._internal();

  // 来自 aliyun-emas-services.json：emas.appKey（数字型）
  static const String _appKey = '335723639';
  // 来自 aliyun-emas-services.json：emas.appSecret（十六进制）
  static const String _appSecret = '2fc267edc1b1424ea61952c0f13fb124';

  // 复用 NotificationService 中已有的 channel，确保 Android 8+ 通知显示
  static const String _channelId = 'schedule_reminders';
  static const String _channelName = 'Schedule Reminders';

  bool _initialized = false;
  final _plugin = AliyunPush();

  Future<void> init() async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;
    _initialized = true;

    try {
      final result = await _plugin.initPush(
        appKey: _appKey,
        appSecret: _appSecret,
      );
      final code = result['code'] as String? ?? '';
      final errMsg = result['errorMsg'] as String? ?? '';
      flog('[AliyunPush] init: code=$code $errMsg');

      // 注册通知 channel（Android 8+）
      if (Platform.isAndroid) {
        await _plugin.createAndroidChannel(
          _channelId,
          _channelName,
          4, // importance: HIGH
          '任务到期/开始时的提醒通知',
        );
      }

      // 注册消息回调
      _plugin.addMessageReceiver(
        // App 在前台时通知到达：手动展示本地通知
        onAndroidNotificationReceivedInApp: (message) async {
          flog('[AliyunPush] foreground notification: $message');
          final title = (message['title'] as String?) ?? '';
          final body  = (message['summary'] as String?) ?? message['body'] as String? ?? '';
          await _showLocalNotification(title, body);
        },
        // 通知被点击
        onNotificationOpened: (message) async {
          flog('[AliyunPush] notification opened: $message');
          final extras = message['extras'];
          String? taskId;
          if (extras is Map) taskId = extras['task_id'] as String?;
          if (taskId != null && taskId.isNotEmpty) {
            NotificationService.pendingTaskId = taskId;
          }
          AppRouter.navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/', (route) => false);
        },
        // 后台/透传消息（非通知类型）
        onMessage: (message) async {
          flog('[AliyunPush] message received: $message');
        },
      );

      // 尝试立即上传 deviceId（如果用户已登录）
      await _tryUploadDeviceId();
    } catch (e) {
      flog('[AliyunPush] init error: $e');
    }
  }

  /// 在前台收到推送时，用 flutter_local_notifications 弹本地通知
  Future<void> _showLocalNotification(String title, String body) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: '任务到期/开始时的提醒通知',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7fffffff,
        title,
        body,
        details,
      );
    } catch (e) {
      flog('[AliyunPush] showLocalNotification error: $e');
    }
  }

  /// 登录成功后调用，确保 deviceId 上传到服务端
  Future<void> onUserLoggedIn() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await _tryUploadDeviceId();
  }

  Future<void> _tryUploadDeviceId() async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) return;

    try {
      final deviceId = await _plugin.getDeviceId();
      if (deviceId.isEmpty) {
        flog('[AliyunPush] deviceId is empty, skip upload');
        return;
      }
      flog('[AliyunPush] deviceId: ${deviceId.substring(0, deviceId.length.clamp(0, 8))}...');
      await _uploadDeviceId(deviceId);
    } catch (e) {
      flog('[AliyunPush] getDeviceId error: $e');
    }
  }

  Future<void> _uploadDeviceId(String deviceId) async {
    try {
      final client = Supabase.instance.client;
      await client.functions.invoke(
        'register-device',
        method: HttpMethod.post,
        body: {
          'registration_id': deviceId,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
      flog('[AliyunPush] device registered OK');
    } catch (e) {
      flog('[AliyunPush] upload device ID error: $e');
    }
  }
}
