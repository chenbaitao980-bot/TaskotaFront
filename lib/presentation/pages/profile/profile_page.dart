import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/project_group_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/local_data_service.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/subscription_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../widgets/upgrade_dialog.dart';
import '../../widgets/vip_badge.dart';
import 'about_page.dart';
import 'app_settings_page.dart';
import 'help_feedback_page.dart';
import 'profile_edit_page.dart';
import 'task_export_page.dart';
import 'theme_settings_page.dart';
import 'vip_page.dart';
import '../../../data/database/app_database.dart';

class ProfilePage extends StatefulWidget {
  final AppDatabase? database;
  final TaskRepository? taskRepository;
  final ProjectRepository? projectRepository;
  final ProjectGroupRepository? projectGroupRepository;
  final VoidCallback? onLogout;
  const ProfilePage({
    super.key,
    this.database,
    this.taskRepository,
    this.projectRepository,
    this.projectGroupRepository,
    this.onLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _total = 0;
  int _completionRate = 0;
  int _streak = 0;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final tasks = await widget.taskRepository?.getAll() ?? [];
    final storage = LocalStorageService();
    await storage.init();
    final profile = storage.getExplicitProfile();
    final total = tasks.length;
    final completed = tasks.where((t) => t.status == 2).length;
    final rate = total == 0 ? 0 : (completed * 100 / total).round();
    final streak = _calcStreak(tasks);
    if (!mounted) return;
    setState(() {
      _total = total;
      _completionRate = rate;
      _streak = streak;
      _profile = profile;
    });
  }

  int _calcStreak(List<Task> tasks) {
    final days = <DateTime>{};
    for (final t in tasks) {
      if (t.status != 2 || t.completedTime == null) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(t.completedTime!);
      days.add(DateTime(d.year, d.month, d.day));
    }
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 16),
            _buildStatsSection(context),
            const SizedBox(height: 16),
            _buildMenuSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final displayName = _profileText('name', fallback: '用户昵称');
    final subtitleParts = [
      _profileText('occupation'),
      _profileText('city'),
    ].where((item) => item.isNotEmpty).toList();
    final email = _authIdentity(context);
    final subtitle = subtitleParts.isNotEmpty
        ? subtitleParts.join(' · ')
        : email.isNotEmpty
        ? email
        : '完善资料，让 AI 更懂你的安排';

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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person_rounded,
                size: 48,
                color: AppTheme.textHint,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileEditPage(accountText: email),
                ),
              );
              if (changed == true) await _init();
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: Colors.white,
              size: 16,
            ),
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
          Expanded(
            child: _buildStatCard('总任务', '$_total', Icons.assignment_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              '完成率',
              '$_completionRate%',
              Icons.trending_up_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatCard(
              '连续',
              '$_streak天',
              Icons.local_fire_department_rounded,
            ),
          ),
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
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
            _buildMenuItem(
              Icons.workspace_premium,
              SubscriptionService.instance.isVip ? 'VIP会员' : '开通VIP',
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VipPage()),
                );
              },
              showTop: true,
              trailing: SubscriptionService.instance.isVip
                  ? const VipBadge(size: 14)
                  : null,
            ),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.settings_rounded, '设置', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppSettingsPage(
                    showLocalDataTools: _showLocalDataTools(context),
                    database: widget.database,
                    taskRepository: widget.taskRepository,
                  ),
                ),
              );
            }),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.palette_outlined, '主题', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
              );
            }),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.ios_share_rounded, '导出', () {
              if (!SubscriptionService.instance.canExportData()) {
                UpgradeDialog.show(context,
                    message: '数据导出为VIP专属功能，升级VIP解锁');
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskExportPage(
                    taskRepository: widget.taskRepository,
                    projectRepository: widget.projectRepository,
                    projectGroupRepository: widget.projectGroupRepository,
                  ),
                ),
              );
            },
              trailing: SubscriptionService.instance.isVip
                  ? null
                  : const VipLockIcon(),
            ),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.help_outline_rounded, '帮助与反馈', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpFeedbackPage()),
              );
            }),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(Icons.info_outline_rounded, '关于', () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutPage()),
              );
            }),
            Divider(height: 0.5, indent: 52, color: AppTheme.borderSubtle),
            _buildMenuItem(
              Icons.logout_rounded,
              '退出登录',
              widget.onLogout ??
                  () {
                    context.read<AuthBloc>().add(LoggedOut());
                  },
              isDestructive: true,
              showBottom: true,
            ),
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
    Widget? trailing,
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
                    color: isDestructive
                        ? AppTheme.error
                        : AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) ...[
                trailing,
                const SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
            ],
          ),
        ),
      ),
    );
  }

  String _profileText(String key, {String fallback = ''}) {
    final value = _profile?[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String _authIdentity(BuildContext context) {
    try {
      final state = context.read<AuthBloc>().state;
      if (state is LocalAuthenticated) return state.email;
      if (state is Authenticated) {
        return state.user.email ?? state.user.phone ?? '';
      }
    } catch (_) {}
    return '';
  }

  bool _showLocalDataTools(BuildContext context) {
    try {
      return context.read<AuthBloc>().state is LocalAuthenticated &&
          LocalDataService().isDesktop;
    } catch (_) {
      return false;
    }
  }
}
