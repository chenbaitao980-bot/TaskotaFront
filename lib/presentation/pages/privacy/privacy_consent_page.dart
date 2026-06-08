import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/snackbar_helper.dart';

class PrivacyConsentPage extends StatefulWidget {
  final VoidCallback onAccepted;

  const PrivacyConsentPage({super.key, required this.onAccepted});

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();

  static const _prefKey = 'privacy_policy_accepted';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  bool _loading = false;

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrivacyConsentPage._prefKey, true);
      if (mounted) widget.onAccepted();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, '操作失败，请重试');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.task_alt_rounded,
                size: 72,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                'Taskora',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '智能任务管理',
                style: TextStyle(fontSize: 15, color: AppTheme.textHint),
              ),
              const Spacer(flex: 2),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.borderSubtle,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '隐私保护提示',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '欢迎使用 Taskora！在您使用前，请仔细阅读并了解：',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 我们会收集您的账号信息用于登录和同步\n'
                      '• 您的任务数据会加密存储在云端服务器\n'
                      '• AI 拆解功能会将任务内容发送至 AI 服务处理\n'
                      '• 我们不会向第三方出售您的个人数据',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.8,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        text: '详细信息请阅读 ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                        children: [
                          TextSpan(
                            text: '用户协议',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showFullTerms(context),
                          ),
                          const TextSpan(text: ' 和 '),
                          TextSpan(
                            text: '隐私政策',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showFullPolicy(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _loading ? null : _accept,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '同意并继续',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _loading ? null : () => _showDisagreeDialog(context),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '不同意',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '隐私政策',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  privacyPolicyText,
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '用户协议',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  termsOfServiceText,
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisagreeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('提示', style: TextStyle(fontSize: 16)),
        content: const Text(
          '如果您不同意隐私政策，将无法使用 Taskora 的功能。\n\n您可以稍后再做决定。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }
}

const String privacyPolicyText = '''
隐私政策

生效日期：2026年6月1日

Taskora（以下简称"本产品"）重视您的隐私保护。本隐私政策说明我们如何收集、使用和保护您的个人信息。

1. 我们收集的信息

为提供任务管理、日程提醒、AI 拆解、附件和云同步功能，本产品可能收集或处理以下信息：

• 账号信息：邮箱、手机号、登录状态、用户 ID
• 用户主动输入内容：任务标题、任务描述、项目、清单、日程、提醒时间、附件
• AI 处理内容：用户主动提交给 AI 拆解的任务标题和描述
• 设备信息：操作系统版本、设备型号（用于适配和问题排查）
• 同步数据：任务、项目、清单、附件元数据、更新时间

2. 信息使用目的

• 提供核心功能：任务管理、云端同步、提醒通知
• AI 任务拆解：将任务信息发送至 AI 服务（DeepSeek）进行智能分析
• 改善服务：分析使用情况以优化产品体验

3. 第三方 SDK

本产品使用以下第三方服务：

• Supabase：云端数据存储与用户认证，数据存储于海外服务器
• DeepSeek：AI 任务分析与拆解
• Flutter Local Notifications / Alarm：本地通知和闹钟提醒
• Google Fonts：字体服务

4. 信息存储与安全

• 本地数据存储在设备本地数据库中
• 云端数据通过 HTTPS 加密传输，存储于 Supabase 服务器
• 我们采取合理的技术措施保护您的数据安全

5. 您的权利

• 您可以随时查看、修改或删除您的任务和个人资料
• 您可以通过注销账号删除云端数据
• 您可以拒绝 AI 拆解功能的使用

6. 联系我们

如有隐私相关问题，请通过应用内"帮助与反馈"联系我们。

本隐私政策可能会更新，请定期查阅。继续使用本产品即表示您同意更新后的政策。
''';

const String termsOfServiceText = '''
用户协议

生效日期：2026年6月1日

欢迎使用 Taskora（以下简称"本产品"）。使用本产品前，请仔细阅读本协议。

1. 服务说明

本产品是一款任务管理工具，提供任务创建、日程安排、AI 拆解、云端同步等功能。

2. 用户责任

• 您应合法使用本产品，不得利用本产品从事违法活动
• 您对账号下的所有行为负责
• 您不得干扰或破坏本产品的正常运行

3. 知识产权

本产品的所有权利归开发者所有，包括但不限于软件、界面设计、图标等。

4. 免责声明

• 本产品按"现状"提供，不保证完全无中断或无错误
• AI 拆解结果仅供参考，不构成专业建议
• 因不可抗力导致的数据丢失，开发者不承担责任

5. 协议变更

我们保留修改本协议的权利。重大变更时将通过应用内通知告知您。

6. 联系方式

如有问题，请通过应用内"帮助与反馈"联系我们。
''';
