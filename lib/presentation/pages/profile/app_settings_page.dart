import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';
import 'theme_settings_page.dart';

class AppSettingsPage extends StatefulWidget {
  const AppSettingsPage({super.key});

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final _storage = LocalStorageService();
  bool _ready = false;
  bool _skipWeekends = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _storage.init();
    if (!mounted) return;
    setState(() {
      _skipWeekends = _storage.skipWeekends;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionCard(
            title: 'AI 排程',
            children: [
              SwitchListTile(
                title: const Text('AI 排程跳过周末'),
                subtitle: Text(
                  '开启后，AI 拆分子任务时不把任务排到周六/周日',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                value: _ready && _skipWeekends,
                activeThumbColor: AppTheme.primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: !_ready
                    ? null
                    : (value) async {
                        setState(() => _skipWeekends = value);
                        await _storage.setSkipWeekends(value);
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '外观',
            children: [
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: '主题',
                subtitle: '切换暖珊瑚、极光蓝、曜石黑配色',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ThemeSettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            title: '通知',
            children: [
              _InfoTile(
                icon: Icons.notifications_active_outlined,
                title: '任务与日程提醒',
                body: '应用会在创建日程或任务提醒时调用系统通知能力；移动端首次使用会请求通知权限。',
              ),
              SizedBox(height: 12),
              _InfoTile(
                icon: Icons.alarm_outlined,
                title: '精确提醒',
                body: 'Android 设备需要系统允许精确闹钟权限；关闭后，提醒可能延迟到系统允许的时间触发。',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const _SectionCard(
            title: '数据',
            children: [
              _InfoTile(
                icon: Icons.storage_outlined,
                title: '本地数据',
                body: '任务、项目、检查项、附件记录和偏好设置保存在本机应用数据目录。',
              ),
              SizedBox(height: 12),
              _InfoTile(
                icon: Icons.cloud_sync_outlined,
                title: '云同步',
                body: '登录后，任务、项目、检查项和附件元数据会通过 Supabase 做跨端同步。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadowLight,
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
