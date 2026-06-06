import 'dart:io' show Platform;
import 'package:flutter/services.dart';

class BatteryOptimizationService {
  static const _channel = MethodChannel('com.taskora/battery');

  static Future<bool> isIgnoring() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> request() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  static Future<void> openSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('openBatteryOptimizationSettings');
    } catch (_) {}
  }
}
