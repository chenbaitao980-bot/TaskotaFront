import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/file_logger.dart';

/// 会员类型配置
class MemberTypeConfig {
  final String id;
  final String name;
  final String plan; // 计划标识（如 vip_monthly, vip_yearly, free），用于与 user_subscriptions.plan 匹配
  final double price;
  final int durationDays;
  final bool aiDecompose;
  final bool dataExport;
  final int maxProjects;
  final int maxTasks;
  final bool autoRenew;
  final int trialDays;
  final int referralBonus;
  final int sortOrder;

  const MemberTypeConfig({
    required this.id,
    required this.name,
    required this.plan,
    required this.price,
    required this.durationDays,
    this.aiDecompose = true,
    this.dataExport = true,
    this.maxProjects = -1,
    this.maxTasks = -1,
    this.autoRenew = false,
    this.trialDays = 0,
    this.referralBonus = 0,
    this.sortOrder = 0,
  });

  factory MemberTypeConfig.fromJson(Map<String, dynamic> json) {
    return MemberTypeConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      plan: json['plan'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      durationDays: json['duration_days'] as int,
      aiDecompose: json['ai_decompose'] as bool? ?? true,
      dataExport: json['data_export'] as bool? ?? true,
      maxProjects: json['max_projects'] as int? ?? -1,
      maxTasks: json['max_tasks'] as int? ?? -1,
      autoRenew: json['auto_renew'] as bool? ?? false,
      trialDays: json['trial_days'] as int? ?? 0,
      referralBonus: json['referral_bonus'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  /// 转换为订单创建所需的价格（分）
  int get priceCents => (price * 100).toInt();

  /// 价格显示字符串
  String get priceDisplay => '¥$price';

  /// 时长显示字符串
  String get durationDisplay {
    if (durationDays >= 365) {
      final years = durationDays ~/ 365;
      return '$years年';
    } else if (durationDays >= 30) {
      final months = durationDays ~/ 30;
      return '$months个月';
    } else {
      return '$durationDays天';
    }
  }
}

/// 折扣码配置
class DiscountCodeConfig {
  final String id;
  final String code;
  final int percent;
  final String? typeId;
  final bool active;
  final int usedCount;
  /// 折扣说明，向用户解释为什么能享受此折扣（如：首次购买专属优惠）
  final String? description;

  const DiscountCodeConfig({
    required this.id,
    required this.code,
    required this.percent,
    this.typeId,
    this.active = true,
    this.usedCount = 0,
    this.description,
  });

  factory DiscountCodeConfig.fromJson(Map<String, dynamic> json) {
    return DiscountCodeConfig(
      id: json['id'] as String,
      code: json['code'] as String,
      percent: json['percent'] as int,
      typeId: json['type_id'] as String?,
      active: json['active'] as bool? ?? true,
      usedCount: json['used_count'] as int? ?? 0,
      description: json['description'] as String?,
    );
  }

  /// 折扣比例（0.0-1.0）
  double get discountRate => percent / 100.0;

  /// 折扣显示字符串（如：八折）
  String get discountDisplay {
    final discount = 10 - percent / 10;
    return '${discount.toStringAsFixed(1)}折';
  }
}

/// 充值梯度配置
class RechargeTierConfig {
  final String id;
  final double amount;
  final double bonus;
  final int sortOrder;

  const RechargeTierConfig({
    required this.id,
    required this.amount,
    this.bonus = 0,
    this.sortOrder = 0,
  });

  factory RechargeTierConfig.fromJson(Map<String, dynamic> json) {
    return RechargeTierConfig(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      bonus: (json['bonus'] as num?)?.toDouble() ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  /// 总金额（充值 + 赠送）
  double get totalAmount => amount + bonus;

  /// 赠送比例
  double get bonusRate => amount > 0 ? bonus / amount : 0;
}

/// 会员配置服务
///
/// 从 Supabase Edge Function 获取会员配置，替换硬编码值。
/// 支持本地缓存，减少网络请求。
class MemberConfigService {
  static final MemberConfigService _instance = MemberConfigService._();
  static MemberConfigService get instance => _instance;
  MemberConfigService._();

  List<MemberTypeConfig> _memberTypes = [];
  List<DiscountCodeConfig> _discountCodes = [];
  List<RechargeTierConfig> _rechargeTiers = [];

  bool _isLoaded = false;

  /// 获取所有会员类型
  List<MemberTypeConfig> get memberTypes => List.unmodifiable(_memberTypes);

  /// 获取所有有效折扣码
  List<DiscountCodeConfig> get discountCodes =>
      List.unmodifiable(_discountCodes.where((c) => c.active));

  /// 获取所有充值梯度
  List<RechargeTierConfig> get rechargeTiers =>
      List.unmodifiable(_rechargeTiers);

  /// 是否已加载配置
  bool get isLoaded => _isLoaded;

  /// 初始化并加载配置：先读本地缓存（离线/弱网立即可用），再后台刷新
  Future<void> init() async {
    await _loadFromCache();
    await refresh();
  }

  static const _queryTimeout = Duration(seconds: 3);

  /// 刷新配置（直接调用 REST API，无需 Edge Function）
  /// 每个查询带 3s 超时降级；成功后写入 SharedPreferences 缓存
  Future<void> refresh() async {
    try {
      final client = Supabase.instance.client;

      // 并发请求三张表（各自超时降级）
      final typesFuture =
          client.from('member_types').select().timeout(_queryTimeout);
      final codesFuture = client
          .from('member_discount_codes')
          .select()
          .eq('active', true)
          .timeout(_queryTimeout);
      final tiersFuture =
          client.from('member_recharge_tiers').select().timeout(_queryTimeout);

      final results = await Future.wait([typesFuture, codesFuture, tiersFuture]);

      _memberTypes = (results[0] as List)
          .map((e) => MemberTypeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _discountCodes = (results[1] as List)
          .map((e) => DiscountCodeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      _rechargeTiers = (results[2] as List)
          .map((e) => RechargeTierConfig.fromJson(e as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
      flog(
          '[MemberConfig] refreshed: ${_memberTypes.length} types, ${_discountCodes.length} discounts, ${_rechargeTiers.length} tiers');

      await _saveToCache(
        types: results[0] as List,
        codes: results[1] as List,
        tiers: results[2] as List,
      );
    } catch (e) {
      flog('[MemberConfig] refresh failed: $e');
    }
  }

  // --- 本地缓存 ---

  static const _keyTypes = 'member_config_types';
  static const _keyCodes = 'member_config_codes';
  static const _keyTiers = 'member_config_tiers';

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typesJson = prefs.getString(_keyTypes);
      final codesJson = prefs.getString(_keyCodes);
      final tiersJson = prefs.getString(_keyTiers);
      if (typesJson == null) return;

      _memberTypes = (jsonDecode(typesJson) as List)
          .map((e) => MemberTypeConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      if (codesJson != null) {
        _discountCodes = (jsonDecode(codesJson) as List)
            .map((e) => DiscountCodeConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (tiersJson != null) {
        _rechargeTiers = (jsonDecode(tiersJson) as List)
            .map((e) => RechargeTierConfig.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      _isLoaded = true;
      flog('[MemberConfig] loaded from cache: ${_memberTypes.length} types');
    } catch (e) {
      flog('[MemberConfig] loadFromCache failed: $e');
    }
  }

  Future<void> _saveToCache({
    required List types,
    required List codes,
    required List tiers,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyTypes, jsonEncode(types));
      await prefs.setString(_keyCodes, jsonEncode(codes));
      await prefs.setString(_keyTiers, jsonEncode(tiers));
    } catch (e) {
      flog('[MemberConfig] saveToCache failed: $e');
    }
  }

  /// 根据 ID 获取会员类型
  MemberTypeConfig? getMemberTypeById(String id) {
    try {
      return _memberTypes.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 根据 plan 值获取会员类型（兼容旧的 plan 值）
  MemberTypeConfig? getMemberTypeByPlan(String plan) {
    // 1. 直接匹配 ID
    final byId = getMemberTypeById(plan);
    if (byId != null) return byId;

    // 2. 匹配 plan 字段（如 'vip_monthly', 'vip_yearly', 'free'）
    try {
      return _memberTypes.firstWhere((t) => t.plan == plan);
    } catch (_) {
      // not found
    }

    // 3. 匹配名称
    try {
      return _memberTypes.firstWhere(
        (t) => t.name.toLowerCase().contains(plan.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }

  /// 验证折扣码
  DiscountCodeConfig? validateDiscountCode(String code, {String? typeId}) {
    try {
      return _discountCodes.firstWhere(
        (c) =>
            c.code.toUpperCase() == code.toUpperCase() &&
            c.active &&
            (c.typeId == null || c.typeId == typeId),
      );
    } catch (_) {
      return null;
    }
  }

  /// 计算折扣后的价格
  double calculateDiscountedPrice(
    double originalPrice,
    DiscountCodeConfig discount,
  ) {
    return originalPrice * discount.discountRate;
  }

  /// 清除缓存
  void clearCache() {
    _memberTypes = [];
    _discountCodes = [];
    _rechargeTiers = [];
    _isLoaded = false;
  }
}
