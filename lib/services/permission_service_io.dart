import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'battery_optimization_service.dart';

class PermissionService {
  static const _prefKeyNotifAsked = 'notif_permission_asked';
  static const _prefKeyBatteryAsked = 'battery_opt_asked';

  /// 申请通知权限，返回是否已授予
  static Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final plugin = FlutterLocalNotificationsPlugin();

    if (Platform.isAndroid) {
      final android = plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsGranted =
          await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return notificationsGranted;
    }

    if (Platform.isIOS) {
      final ios = plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  /// 首次启动时弹出权限引导 dialog，之后不再重复弹出
  static Future<void> showNotificationGuideIfNeeded(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeyNotifAsked) == true) return;
    await prefs.setBool(_prefKeyNotifAsked, true);

    if (!context.mounted) return;

    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, size: 22),
            SizedBox(width: 8),
            Text(
              '开启任务提醒',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: const Text(
          '允许发送通知，并在系统的“闹钟和提醒”中允许 Taskora 设置精确提醒。\n\n如果提醒仍不准时，请在手机系统设置里关闭 Taskora 的省电限制，并允许后台运行。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('允许'),
          ),
        ],
      ),
    );

    if (granted == true) {
      await requestNotificationPermission();
    }

    // Android：首次引导用户关闭电池优化
    if (Platform.isAndroid && context.mounted) {
      await _showBatteryOptimizationGuideIfNeeded(context);
    }
  }

  static Future<void> _showBatteryOptimizationGuideIfNeeded(
    BuildContext context,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeyBatteryAsked) == true) return;
    final alreadyIgnored = await BatteryOptimizationService.isIgnoring();
    if (alreadyIgnored) return;
    await prefs.setBool(_prefKeyBatteryAsked, true);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.battery_alert_outlined, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '关闭电池优化',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: const Text(
          '为保证退出APP后任务提醒仍能正常触发，请允许 Taskora 不受电池优化限制。\n\n'
          '此外建议在系统设置中：\n'
          '• 允许 Taskora 自启动\n'
          '• 允许 Taskora 后台运行',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去设置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BatteryOptimizationService.request();
    }
  }
}
