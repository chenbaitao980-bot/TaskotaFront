import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class WechatBindingStatus {
  final bool bound;
  final bool enabled;
  final String? uid;
  final String? boundAt;

  const WechatBindingStatus({
    this.bound = false,
    this.enabled = false,
    this.uid,
    this.boundAt,
  });

  factory WechatBindingStatus.fromJson(Map<String, dynamic> json) {
    return WechatBindingStatus(
      bound: json['bound'] == true,
      enabled: json['enabled'] == true,
      uid: json['uid'] as String?,
      boundAt: json['boundAt'] as String?,
    );
  }
}

class WechatReminderService {
  static final WechatReminderService _instance =
      WechatReminderService._internal();
  factory WechatReminderService() => _instance;
  WechatReminderService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<WechatBindingStatus> getStatus() async {
    try {
      final resp = await _client.functions.invoke(
        'wechat-binding',
        method: HttpMethod.get,
      );
      if (resp.data is Map<String, dynamic>) {
        return WechatBindingStatus.fromJson(resp.data);
      }
      return const WechatBindingStatus();
    } catch (e) {
      print('[WechatReminder] getStatus error: $e');
      return const WechatBindingStatus();
    }
  }

  Future<bool> toggleEnabled(bool enabled) async {
    try {
      final resp = await _client.functions.invoke(
        'wechat-binding',
        method: HttpMethod.put,
        body: {'enabled': enabled},
      );
      return resp.data?['success'] == true;
    } catch (e) {
      print('[WechatReminder] toggleEnabled error: $e');
      return false;
    }
  }

  Future<bool> unbind() async {
    try {
      final resp = await _client.functions.invoke(
        'wechat-binding',
        method: HttpMethod.delete,
      );
      return resp.data?['success'] == true;
    } catch (e) {
      print('[WechatReminder] unbind error: $e');
      return false;
    }
  }

  String getBindQrCodeUrl() {
    final user = _client.auth.currentUser;
    if (user == null) return '';
    return 'https://wxpusher.zjiecode.com/api/fun/create/qrcode/'
        '${AppConstants.wxpusherAppToken}'
        '?extra=${Uri.encodeComponent(user.id)}';
  }

  Future<bool> sendTestMessage() async {
    try {
      final status = await getStatus();
      if (!status.bound || status.uid == null) return false;

      final resp = await _client.functions.invoke(
        'wechat-binding',
        method: HttpMethod.post,
        body: {'action': 'test'},
      );
      return resp.data?['success'] == true;
    } catch (e) {
      print('[WechatReminder] sendTest error: $e');
      return false;
    }
  }

  /// 注册一条服务端定时推送（微信+FCM），作为本地通知的兜底
  Future<bool> scheduleServerPush({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    try {
      final resp = await _client.functions.invoke(
        'schedule-push',
        method: HttpMethod.post,
        body: {
          'task_id': taskId,
          'title': title,
          'body': body,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'channels': ['aliyun', 'wechat'],
        },
      );
      return resp.data?['success'] == true;
    } catch (e) {
      print('[WechatReminder] scheduleServerPush error: $e');
      return false;
    }
  }

  /// 取消服务端定时推送
  Future<bool> cancelServerPush({required String taskId}) async {
    try {
      final resp = await _client.functions.invoke(
        'schedule-push',
        method: HttpMethod.delete,
        body: {'task_id': taskId},
      );
      return resp.data?['success'] == true;
    } catch (e) {
      print('[WechatReminder] cancelServerPush error: $e');
      return false;
    }
  }
}
