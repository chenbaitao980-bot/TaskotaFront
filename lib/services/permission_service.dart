import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionService {
  static const _prefKeyNotifAsked = 'notif_permission_asked';

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
          '允许发送通知，以便在任务开始前准时提醒您。\n\n关闭后可在系统设置中重新开启。',
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
  }
}
