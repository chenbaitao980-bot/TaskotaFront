enum SubscriptionPlan {
  free,
  vipMonthly,
  vipYearly;

  String get value {
    switch (this) {
      case free:
        return 'free';
      case vipMonthly:
        return 'vip_monthly';
      case vipYearly:
        return 'vip_yearly';
    }
  }

  static SubscriptionPlan fromValue(String? v) {
    switch (v) {
      case 'vip_monthly':
        return vipMonthly;
      case 'vip_yearly':
        return vipYearly;
      default:
        return free;
    }
  }

  bool get isVipTier => this != free;
}

enum SubscriptionStatus {
  active,
  expired,
  cancelled;

  static SubscriptionStatus fromValue(String? v) {
    switch (v) {
      case 'expired':
        return expired;
      case 'cancelled':
        return cancelled;
      default:
        return active;
    }
  }
}

class UserSubscription {
  final String? id;
  final String userId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final String? paymentChannel;
  final String? transactionId;
  final bool autoRenew;

  const UserSubscription({
    this.id,
    required this.userId,
    this.plan = SubscriptionPlan.free,
    this.status = SubscriptionStatus.active,
    this.startedAt,
    this.expiresAt,
    this.paymentChannel,
    this.transactionId,
    this.autoRenew = false,
  });

  bool get isVip =>
      plan.isVipTier &&
      status == SubscriptionStatus.active &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory UserSubscription.free(String userId) =>
      UserSubscription(userId: userId);

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      plan: SubscriptionPlan.fromValue(json['plan'] as String?),
      status: SubscriptionStatus.fromValue(json['status'] as String?),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      paymentChannel: json['payment_channel'] as String?,
      transactionId: json['transaction_id'] as String?,
      autoRenew: json['auto_renew'] as bool? ?? false,
    );
  }
}
