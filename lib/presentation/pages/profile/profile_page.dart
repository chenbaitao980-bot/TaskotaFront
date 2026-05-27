import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/local_storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 16),
            _buildStatsSection(context),
            const SizedBox(height: 16),
            _buildSettingsSection(),
            const SizedBox(height: 16),
            _buildMenuSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    if (!_ready) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: SwitchListTile(
          title: const Text('AI 排程跳过周末',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          subtitle: const Text('开启后，AI 拆分子任务时不把任务排到周六/周日',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          value: _skipWeekends,
          activeThumbColor: AppTheme.primaryColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onChanged: (v) async {
            setState(() => _skipWeekends = v);
            await _storage.setSkipWeekends(v);
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Avatar with glow
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: const CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: Icon(Icons.person_rounded, size: 48, color: AppTheme.textHint),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '用户昵称',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'user@example.com',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 16),
            label: const Text(
              '编辑资料',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('总任务', '128', Icons.assignment_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('完成率', '78%', Icons.trending_up_rounded)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('连续', '15天', Icons.local_fire_department_rounded)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.jetBrainsMonoTextTheme().headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            _buildMenuItem(Icons.settings_rounded, '设置', () {}, showTop: true),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.notifications_rounded, '提醒设置', () {}),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.palette_outlined, '主题', () {}),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.help_outline_rounded, '帮助与反馈', () {}),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.info_outline_rounded, '关于', () {}),
            const Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.logout_rounded, '退出登录', () {}, isDestructive: true, showBottom: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool showTop = false,
    bool showBottom = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: showTop ? const Radius.circular(16) : Radius.zero,
          bottom: showBottom ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDestructive ? AppTheme.error : AppTheme.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDestructive ? AppTheme.error : AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: AppTheme.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
