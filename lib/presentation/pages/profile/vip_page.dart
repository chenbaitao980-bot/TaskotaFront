import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/file_logger.dart';
import '../../../services/payment_service.dart';
import '../../../services/subscription_service.dart';
import '../../../services/member_config_service.dart';
import '../../../models/entities/user_subscription.dart';

class VipPage extends StatefulWidget {
  const VipPage({super.key});

  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  SubscriptionPlan _selectedPlan = SubscriptionPlan.vipYearly;
  bool _isCreatingOrder = false;
  String _monthlyPrice = '¥9.9/月';
  String _yearlyPrice = '¥68/年';
  String? _monthlyOriginalPrice;
  String? _yearlyOriginalPrice;
  DiscountCodeConfig? _monthlyDiscount;
  DiscountCodeConfig? _yearlyDiscount;

  @override
  void initState() {
    super.initState();
    SubscriptionService.instance.refresh();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    await MemberConfigService.instance.init();
    if (!mounted) return;
    setState(() {
      final monthlyType = MemberConfigService.instance.getMemberTypeByPlan('vip_monthly');
      final yearlyType = MemberConfigService.instance.getMemberTypeByPlan('vip_yearly');
      final codes = MemberConfigService.instance.discountCodes;

      if (monthlyType != null) {
        _monthlyPrice = monthlyType.priceDisplay;
        final d = codes.where((c) => c.typeId == monthlyType.id || c.typeId == null).firstOrNull;
        _monthlyDiscount = d;
        if (d != null) {
          _monthlyOriginalPrice = monthlyType.priceDisplay;
          final discounted = monthlyType.price * (1 - d.percent / 100.0);
          _monthlyPrice = '¥${discounted % 1 == 0 ? discounted.toInt() : discounted.toStringAsFixed(2)}';
        }
      }
      if (yearlyType != null) {
        _yearlyPrice = yearlyType.priceDisplay;
        final d = codes.where((c) => c.typeId == yearlyType.id || c.typeId == null).firstOrNull;
        _yearlyDiscount = d;
        if (d != null) {
          _yearlyOriginalPrice = yearlyType.priceDisplay;
          final discounted = yearlyType.price * (1 - d.percent / 100.0);
          _yearlyPrice = '¥${discounted % 1 == 0 ? discounted.toInt() : discounted.toStringAsFixed(2)}';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = SubscriptionService.instance.current;
    final isVip = sub.isVip;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('VIP会员')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(isVip, sub, theme),
            const SizedBox(height: 24),
            if (!isVip) ...[
              _buildBenefits(theme),
              const SizedBox(height: 24),
              _buildPlanSelector(theme),
              const SizedBox(height: 24),
              _buildPayButton(theme),
            ],
            if (isVip) ...[
              const SizedBox(height: 16),
              _buildBenefits(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(bool isVip, UserSubscription sub, ThemeData theme) {
    return Card(
      elevation: isVip ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: isVip
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFAB00), Color(0xFFFF6D00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : null,
        child: Column(
          children: [
            Icon(
              isVip ? Icons.workspace_premium : Icons.person_outline,
              size: 48,
              color: isVip ? Colors.white : theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              isVip ? 'VIP会员' : '普通用户',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isVip ? Colors.white : null,
              ),
            ),
            if (isVip && sub.expiresAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '到期时间：${_formatDate(sub.expiresAt!)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ],
            if (!isVip) ...[
              const SizedBox(height: 8),
              Text(
                '升级VIP，解锁全部功能',
                style: TextStyle(
                  color: theme.colorScheme.outline,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBenefits(ThemeData theme) {
    final benefits = [
      ('AI智能拆分', 'AI自动将复杂任务拆解为子任务树', Icons.auto_awesome),
      ('数据导出', '导出任务数据为Excel文件', Icons.download),
      ('无限项目', '不限制项目数量（免费版最多3个）', Icons.folder_open),
      ('无限任务', '每个项目不限任务数（免费版最多50个）', Icons.task_alt),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VIP专属权益', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        ...benefits.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFAB00).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(b.$3, color: const Color(0xFFFFAB00), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(b.$2,
                            style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildPlanSelector(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            title: '月度VIP',
            price: _monthlyPrice,
            originalPrice: _monthlyOriginalPrice,
            discount: _monthlyDiscount,
            selected: _selectedPlan == SubscriptionPlan.vipMonthly,
            onTap: () =>
                setState(() => _selectedPlan = SubscriptionPlan.vipMonthly),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PlanCard(
            title: '年度VIP',
            price: _yearlyPrice,
            originalPrice: _yearlyOriginalPrice,
            discount: _yearlyDiscount,
            badge: '推荐',
            selected: _selectedPlan == SubscriptionPlan.vipYearly,
            onTap: () =>
                setState(() => _selectedPlan = SubscriptionPlan.vipYearly),
          ),
        ),
      ],
    );
  }

  Widget _buildPayButton(ThemeData theme) {
    final monthlyType = MemberConfigService.instance.getMemberTypeByPlan('vip_monthly');
    final priceText = monthlyType != null
        ? '¥${monthlyType.price.toStringAsFixed(monthlyType.price.truncateToDouble() == monthlyType.price ? 0 : 1)}'
        : (_selectedPlan == SubscriptionPlan.vipMonthly ? '¥9.9' : '¥68');
    return FilledButton(
      onPressed: _isCreatingOrder ? null : _handlePay,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFFAB00),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isCreatingOrder
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(
              '支付宝扫码支付 $priceText',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }

  Future<void> _handlePay() async {
    setState(() => _isCreatingOrder = true);

    try {
      // 使用配置服务中的 plan 标识创建订单
      final monthlyType = MemberConfigService.instance.getMemberTypeByPlan('vip_monthly');
      final yearlyType = MemberConfigService.instance.getMemberTypeByPlan('vip_yearly');
      String planValue;
      if (_selectedPlan == SubscriptionPlan.vipMonthly) {
        planValue = monthlyType?.plan.isNotEmpty == true
            ? monthlyType!.plan
            : 'vip_monthly';
      } else {
        planValue = yearlyType?.plan.isNotEmpty == true
            ? yearlyType!.plan
            : 'vip_yearly';
      }

      final order = await PaymentService.instance
          .createOrder(planValue);

      if (!mounted) return;
      setState(() => _isCreatingOrder = false);

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => _QrPaymentPage(order: order),
        ),
      );

      if (result == true && mounted) {
        await SubscriptionService.instance.refresh();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('VIP开通成功！'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      }
    } catch (e) {
      flog('[VipPage] createOrder failed: $e');
      if (mounted) {
        setState(() => _isCreatingOrder = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建订单失败：$e')),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// --- 二维码支付页面 ---

class _QrPaymentPage extends StatefulWidget {
  final PaymentOrder order;
  const _QrPaymentPage({required this.order});

  @override
  State<_QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<_QrPaymentPage> {
  StreamSubscription<PaymentStatus>? _pollSub;
  PaymentStatus _status = PaymentStatus.pending;
  int _elapsedSeconds = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  void _startPolling() {
    _pollSub = PaymentService.instance
        .pollOrderStatus(widget.order.outTradeNo)
        .listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
      if (status == PaymentStatus.paid) {
        _countdownTimer?.cancel();
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    });
  }

  @override
  void dispose() {
    _pollSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = 300 - _elapsedSeconds;

    return Scaffold(
      appBar: AppBar(title: const Text('扫码支付')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.order.subject,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${widget.order.amount}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF6D00),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.order.qrCode,
                  version: QrVersions.auto,
                  size: 220,
                  gapless: true,
                ),
              ),
              const SizedBox(height: 20),
              if (_status == PaymentStatus.pending) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 18, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      '请打开支付宝扫描二维码',
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (remaining > 0)
                  Text(
                    '${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')} 后过期',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining < 60
                          ? const Color(0xFFFF6D00)
                          : theme.colorScheme.outline,
                    ),
                  ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(height: 8),
                Text(
                  '等待支付...',
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.outline),
                ),
              ],
              if (_status == PaymentStatus.paid)
                const Column(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 48),
                    SizedBox(height: 8),
                    Text(
                      '支付成功！',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ],
                ),
              if (_status == PaymentStatus.closed ||
                  (_status == PaymentStatus.pending && remaining <= 0))
                Column(
                  children: [
                    Icon(Icons.timer_off,
                        color: theme.colorScheme.error, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      '订单已过期',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('返回重新下单'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 套餐选择卡片 ---

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final String? originalPrice;
  final DiscountCodeConfig? discount;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    this.badge,
    this.originalPrice,
    this.discount,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? const Color(0xFFFFAB00) : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? const Color(0xFFFFAB00).withValues(alpha: 0.06)
              : null,
        ),
        child: Column(
          children: [
            if (badge != null || discount != null)
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6D00),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  if (discount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(discount!.discountDisplay,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            if (badge != null || discount != null) const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 4),
            if (originalPrice != null) ...[
              Text(originalPrice!,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                      decoration: TextDecoration.lineThrough)),
              const SizedBox(height: 2),
              Text(price,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600)),
            ] else
              Text(price,
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.outline)),
            if (discount?.description != null &&
                discount!.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(discount!.description!,
                  style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFFE53935).withValues(alpha: 0.85)),
                  textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
