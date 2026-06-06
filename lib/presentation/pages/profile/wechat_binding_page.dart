import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../services/wechat_reminder_service.dart';

class WechatBindingPage extends StatefulWidget {
  const WechatBindingPage({super.key});

  @override
  State<WechatBindingPage> createState() => _WechatBindingPageState();
}

class _WechatBindingPageState extends State<WechatBindingPage> {
  final _service = WechatReminderService();
  WechatBindingStatus? _status;
  bool _loading = true;
  bool _busy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _loading = false;
    });
    if (!status.bound) {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final status = await _service.getStatus();
      if (!mounted) return;
      if (status.bound) {
        _pollTimer?.cancel();
        setState(() => _status = status);
        showAppSnackBar(context, '微信绑定成功！');
      }
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _busy = true);
    final ok = await _service.toggleEnabled(value);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _status = WechatBindingStatus(
          bound: true,
          enabled: value,
          uid: _status?.uid,
          boundAt: _status?.boundAt,
        );
      });
    } else {
      showAppSnackBar(context, '操作失败，请重试');
    }
    setState(() => _busy = false);
  }

  Future<void> _unbind() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('解绑微信提醒'),
        content: const Text('解绑后将不再收到微信任务提醒，确定解绑？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定解绑'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final ok = await _service.unbind();
    if (!mounted) return;
    if (ok) {
      setState(() => _status = const WechatBindingStatus());
      showAppSnackBar(context, '已解绑');
      _startPolling();
    } else {
      showAppSnackBar(context, '解绑失败，请重试');
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('微信提醒')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _status?.bound == true
              ? _buildBoundView()
              : _buildUnboundView(),
    );
  }

  Widget _buildUnboundView() {
    final qrUrl = _service.getBindQrCodeUrl();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Icon(Icons.qr_code_2, size: 48, color: AppTheme.primaryColor),
          const SizedBox(height: 16),
          Text(
            '扫码绑定微信提醒',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '用微信扫描下方二维码，关注后即可接收任务提醒',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          if (qrUrl.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadowLight,
              ),
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            )
          else
            Text(
              '请先登录后再绑定',
              style: TextStyle(color: AppTheme.error),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '等待扫码绑定...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textHint,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '绑定后，任务开始前将通过微信推送提醒\n'
            '推送服务由 WxPusher 提供',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoundView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadowLight,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已绑定微信',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          if (_status?.boundAt != null)
                            Text(
                              '绑定于 ${_formatDate(_status!.boundAt!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textHint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('启用微信提醒'),
                  subtitle: Text(
                    _status?.enabled == true ? '任务提醒将推送到微信' : '已暂停微信推送',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  value: _status?.enabled ?? false,
                  activeThumbColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                  onChanged: _busy ? null : _toggleEnabled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _busy ? null : _unbind,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: BorderSide(color: AppTheme.error.withAlpha(128)),
              ),
              child: const Text('解绑微信'),
            ),
          ),
          const Spacer(),
          Text(
            '解绑后将不再收到微信任务提醒\n可随时重新扫码绑定',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}
