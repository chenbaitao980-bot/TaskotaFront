import 'dart:io' show Platform;
import 'package:alarm/alarm.dart';

/// 闹钟式提醒服务（绕过静音，全屏唤醒）
/// 仅在 Android/iOS 上生效，桌面端静默降级到普通通知。
class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!_isMobile) return;
    await Alarm.init();
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
    // id 不能为 0
    final alarmId = id == 0 ? 1 : id;

    final settings = AlarmSettings(
      id: alarmId,
      dateTime: scheduledDate,
      assetAudioPath: 'assets/audio/alarm.wav',
      loopAudio: true,
      vibrate: true,
      androidFullScreenIntent: true,
      warningNotificationOnKill: Platform.isIOS,
      volumeSettings: const VolumeSettings.fixed(volume: 0.8),
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
    await Alarm.stop(alarmId);
  }
}
