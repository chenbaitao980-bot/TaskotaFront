import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';

/// 闹钟式提醒服务（绕过静音，全屏唤醒）
/// 仅在 Android/iOS 上生效，桌面端静默降级到普通通知。
///
/// 支持两种模式（通过 [useNativeAlarm] 切换）：
/// - true（默认）：使用原生 AlarmManager.setAlarmClock()，进程被杀后最可靠
/// - false：使用 `alarm` 包兜底（旧方案，回滚时用）
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  bool _initialized = false;

  /// 切换到原生 AlarmManager 实现（更可靠）。
  /// 设为 false 可回滚到 alarm 包（保持依赖不动，方便回退）。
  static bool useNativeAlarm = true;

  /// MethodChannel，与原生侧通讯
  static const _channel = MethodChannel('com.taskora/native_alarm');

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!_isMobile) return;

    if (useNativeAlarm && Platform.isAndroid) {
      // 原生模式：无需初始化 alarm 包
      return;
    }

    // 回滚模式：使用 alarm 包
    await Alarm.init();
    // 清除所有旧版本遗留的 alarm
    await Alarm.stopAll();
  }

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// 调度一条闹钟式提醒（绕过静音模式，Android 全屏唤醒）
  /// [id] 不能为 0 或 -1
  Future<void> scheduleAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!_isMobile || !_initialized) return;
    if (scheduledDate.isBefore(DateTime.now())) return;
    final alarmId = id == 0 ? 1 : id;

    if (useNativeAlarm && Platform.isAndroid) {
      // 原生 AlarmManager.setAlarmClock()，进程被杀后最可靠
      try {
        await _channel.invokeMethod('scheduleNotification', {
          'id': alarmId,
          'title': title,
          'body': body,
          'scheduledAtMillis': scheduledDate.millisecondsSinceEpoch,
        });
      } catch (e) {
        // MethodChannel 失败时静默处理，通知由 flutter_local_notifications 兜底
      }
      return;
    }

    // 回滚模式：使用 alarm 包
    final settings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledDate,
      // 使用系统默认通知音（不指定 assetAudioPath）
      // volume: null → 使用当前系统音量，不强制静音
      volumeSettings: const VolumeSettings.fixed(volume: null),
      loopAudio: false,
      vibrate: true,
      androidFullScreenIntent: false,
      warningNotificationOnKill: Platform.isIOS,
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: '关闭',
        icon: 'ic_notification',
      ),
    );
    await Alarm.set(alarmSettings: settings);
  }

  /// 取消指定 id 的闹钟
  Future<void> cancelAlarm(int id) async {
    if (!_isMobile || !_initialized) return;
    final alarmId = id == 0 ? 1 : id;

    if (useNativeAlarm && Platform.isAndroid) {
      try {
        await _channel.invokeMethod('cancelNotification', {
          'id': alarmId,
        });
      } catch (_) {}
      return;
    }

    // 回滚模式
    await Alarm.stop(alarmId);
  }
}
