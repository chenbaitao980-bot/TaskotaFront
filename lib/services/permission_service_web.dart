import 'package:flutter/material.dart';

class PermissionService {
  static Future<bool> requestNotificationPermission() async => false;

  static Future<void> showNotificationGuideIfNeeded(
    BuildContext context,
  ) async {}
}
