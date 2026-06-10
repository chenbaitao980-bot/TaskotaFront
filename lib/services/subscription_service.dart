import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/file_logger.dart';
import '../models/entities/user_subscription.dart';
import 'member_config_service.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._();
  static SubscriptionService get instance => _instance;
  SubscriptionService._();

  UserSubscription? _cached;
  RealtimeChannel? _realtimeChannel;
  bool _isWhitelisted = false;

  String? get _currentUserEmail {
    try {
      return Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  bool get isVip {
    if (_isWhitelisted) return true;
    return _cached?.isVip ?? false;
  }

  UserSubscription get current =>
      _cached ?? UserSubscription.free(_currentUserId ?? '');

  String? get _currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// 获取当前会员类型的配置
  MemberTypeConfig? get currentMemberConfig {
    if (!isVip) return null;
    if (_isWhitelisted && (_cached == null || !_cached!.isVip)) return null; // 白名单用户走默认允许
    if (_cached == null) return null;
    return MemberConfigService.instance.getMemberTypeByPlan(_cached!.plan.value);
  }

  /// 启动时仅加载本地缓存（首屏 isVip 够用）；网络 refresh 由首帧后/登录后调用。
  Future<void> init() async {
    await _loadFromCache();
  }

  static const _refreshTimeout = Duration(seconds: 3);

  Future<void> refresh() async {
    final userId = _currentUserId;
    if (userId == null) return;

    // 订阅与白名单两个查询并行，各自独立超时/容错
    await Future.wait([
      _refreshSubscription(userId),
      _refreshWhitelist(),
    ]);
  }

  Future<void> _refreshSubscription(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_subscriptions')
          .select()
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(_refreshTimeout);

      if (response != null) {
        _cached = UserSubscription.fromJson(response);
      } else {
        _cached = UserSubscription.free(userId);
      }
      await _saveToCache();
      flog('[Subscription] refreshed: plan=${_cached!.plan.value}, isVip=$isVip');
    } catch (e) {
      flog('[Subscription] refresh failed: $e');
    }
  }

  Future<void> _refreshWhitelist() async {
    // 查询白名单（独立 try-catch，失败不影响订阅查询结果）
    try {
      final email = _currentUserEmail;
      if (email != null) {
        final whitelistResp = await Supabase.instance.client
            .from('vip_whitelist')
            .select('email')
            .eq('email', email)
            .maybeSingle()
            .timeout(_refreshTimeout);
        _isWhitelisted = whitelistResp != null;
        flog('[Subscription] whitelist check: email=$email, isWhitelisted=$_isWhitelisted');
      }
    } catch (e) {
      flog('[Subscription] whitelist check failed: $e');
    }
  }

  void startRealtime() {
    final userId = _currentUserId;
    if (userId == null) return;

    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('user_subscriptions_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            flog('[Subscription] realtime update: ${payload.eventType}');
            refresh();
          },
        )
        .subscribe();
  }

  void stopRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
  }

  // --- 权限检查 ---

  bool canUseAiDecompose() {
    if (!isVip) return false;
    final config = currentMemberConfig;
    if (config == null) return true; // 默认允许 VIP 使用
    return config.aiDecompose;
  }

  bool canExportData() {
    if (!isVip) return false;
    final config = currentMemberConfig;
    if (config == null) return true; // 默认允许 VIP 使用
    return config.dataExport;
  }

  Future<bool> canCreateProject(int currentActiveCount) async {
    if (isVip) {
      final config = currentMemberConfig;
      if (config == null) return true; // 默认允许 VIP 创建
      if (config.maxProjects == -1) return true; // 无限制
      return currentActiveCount < config.maxProjects;
    }
    return currentActiveCount < AppConstants.freeMaxProjects;
  }

  Future<bool> canCreateTask(int currentTaskCountInProject) async {
    if (isVip) {
      final config = currentMemberConfig;
      if (config == null) return true; // 默认允许 VIP 创建
      if (config.maxTasks == -1) return true; // 无限制
      return currentTaskCountInProject < config.maxTasks;
    }
    return currentTaskCountInProject < AppConstants.freeMaxTasksPerProject;
  }

  // --- 本地缓存 ---

  static const _keyPlan = 'subscription_plan';
  static const _keyExpiresAt = 'subscription_expires_at';
  static const _keyStatus = 'subscription_status';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planStr = prefs.getString(_keyPlan);
      final statusStr = prefs.getString(_keyStatus);
      final expiresStr = prefs.getString(_keyExpiresAt);

      final userId = _currentUserId ?? '';
      _cached = UserSubscription(
        userId: userId,
        plan: SubscriptionPlan.fromValue(planStr),
        status: SubscriptionStatus.fromValue(statusStr),
        expiresAt:
            expiresStr != null ? DateTime.tryParse(expiresStr) : null,
      );
    } catch (e) {
      flog('[Subscription] loadFromCache failed: $e');
    }
  }

  Future<void> _saveToCache() async {
    if (_cached == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlan, _cached!.plan.value);
      await prefs.setString(_keyStatus, _cached!.status.name);
      if (_cached!.expiresAt != null) {
        await prefs.setString(
            _keyExpiresAt, _cached!.expiresAt!.toIso8601String());
      } else {
        await prefs.remove(_keyExpiresAt);
      }
    } catch (e) {
      flog('[Subscription] saveToCache failed: $e');
    }
  }

  void clearCache() async {
    _cached = null;
    _isWhitelisted = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyPlan);
      await prefs.remove(_keyExpiresAt);
      await prefs.remove(_keyStatus);
    } catch (_) {}
  }
}
