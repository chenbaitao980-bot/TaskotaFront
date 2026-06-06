import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../../core/utils/snackbar_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/battery_optimization_service.dart';
import '../../../services/local_data_service.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import 'theme_settings_page.dart';
import 'wechat_binding_page.dart';

class AppSettingsPage extends StatefulWidget {
  final bool showLocalDataTools;
  final AppDatabase? database;
  final TaskRepository? taskRepository;

  const AppSettingsPage({
    super.key,
    this.showLocalDataTools = false,
    this.database,
    this.taskRepository,
  });

  @override
  State<AppSettingsPage> createState() => _AppSettingsPageState();
}

class _AppSettingsPageState extends State<AppSettingsPage> {
  final _storage = LocalStorageService();
  final _localDataService = LocalDataService();
  bool _ready = false;
  bool _skipWeekends = false;
  bool _dataBusy = false;
  String? _dataDirectory;
  bool? _notifGranted;
  bool? _exactAlarmGranted;
  bool _notifBusy = false;
  bool? _batteryOptIgnored;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _storage.init();
    final dataDirectory = widget.showLocalDataTools
        ? await _localDataService.activeDataDirectoryPath()
        : null;
    bool? notifGranted;
    bool? exactGranted;
    bool? batteryIgnored;
    if (Platform.isAndroid || Platform.isIOS) {
      notifGranted = await NotificationService().checkMobilePermissions();
      exactGranted = await NotificationService().checkExactAlarmPermission();
    }
    if (Platform.isAndroid) {
      batteryIgnored = await BatteryOptimizationService.isIgnoring();
    }
    if (!mounted) return;
    setState(() {
      _skipWeekends = _storage.skipWeekends;
      _dataDirectory = dataDirectory;
      _notifGranted = notifGranted;
      _exactAlarmGranted = exactGranted;
      _batteryOptIgnored = batteryIgnored;
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
          if (widget.showLocalDataTools) ...[
            _buildLocalDataSection(),
            const SizedBox(height: 14),
          ],
          if (Platform.isAndroid || Platform.isIOS)
            _buildMobileNotifSection()
          else
            const _SectionCard(
              title: '通知',
              children: [
                _InfoTile(
                  icon: Icons.notifications_active_outlined,
                  title: '任务与日程提醒',
                  body: '应用会在创建日程或任务提醒时调用系统通知能力。',
                ),
              ],
            ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '微信提醒',
            children: [
              _SettingsRow(
                icon: Icons.chat_outlined,
                title: '微信提醒',
                subtitle: '通过微信接收任务提醒，APP关闭也能收到',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WechatBindingPage(),
                    ),
                  );
                },
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

  Widget _buildMobileNotifSection() {
    final granted = _notifGranted;
    return _SectionCard(
      title: '通知',
      children: [
        Row(
          children: [
            Icon(
              granted == true
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: granted == true ? AppTheme.primaryColor : AppTheme.error,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '通知权限',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    granted == null
                        ? '检查中...'
                        : (granted ? '已授权' : '未授权，提醒功能无法生效'),
                    style: TextStyle(
                      color: granted == true
                          ? AppTheme.textSecondary
                          : AppTheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (granted != true)
              TextButton(
                onPressed: _notifBusy
                    ? null
                    : () async {
                        setState(() => _notifBusy = true);
                        final grantedNow = await NotificationService()
                            .requestMobilePermissions();
                        if (!mounted) return;
                        setState(() {
                          _notifGranted = grantedNow;
                          _notifBusy = false;
                        });
                        if (grantedNow) {
                          showAppSnackBar(context, '通知权限已授权');
                          // 权限刚授权，立即重新调度所有提醒
                          final notif = NotificationService();
                          await notif.rescheduleScheduleReminders(
                            _storage.getSchedules(),
                          );
                          await notif.rescheduleBreakdownTaskReminders(
                            _storage.getTasks(),
                          );
                          if (widget.taskRepository != null) {
                            final tasks = await widget.taskRepository!.getAll();
                            await notif.rescheduleTaskReminders(tasks);
                          }
                        } else {
                          showAppSnackBar(
                            context,
                            '权限未授权，请前往系统设置 > 应用 > Taskora > 通知中手动开启',
                          );
                        }
                      },
                child: _notifBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('请求权限'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _notifBusy
                ? null
                : () async {
                    setState(() => _notifBusy = true);
                    final ok = await NotificationService().showImmediateTestNotification();
                    if (!mounted) return;
                    setState(() => _notifBusy = false);
                    if (ok) {
                      showAppSnackBar(context, '测试通知已发送（1秒后弹出）');
                    } else {
                      final diag = NotificationService().diagnosticSummary;
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('通知诊断'),
                          content: SizedBox(
                            width: double.maxFinite,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                diag.isEmpty ? '无诊断信息' : diag,
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('关闭'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.notifications_active, size: 18),
            label: const Text('发送测试通知'),
          ),
        ),
        if (Platform.isAndroid) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _exactAlarmGranted == true
                    ? Icons.alarm_on_outlined
                    : Icons.alarm_off_outlined,
                color: _exactAlarmGranted == true
                    ? AppTheme.primaryColor
                    : AppTheme.textHint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '精确闹钟（Android 12+）',
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _exactAlarmGranted == true
                          ? '已授权，提醒准时触发'
                          : '未授权，请到系统设置手动开启',
                      style: TextStyle(
                        color: _exactAlarmGranted == true
                            ? AppTheme.textSecondary
                            : AppTheme.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                _batteryOptIgnored == true
                    ? Icons.battery_full_outlined
                    : Icons.battery_alert_outlined,
                color: _batteryOptIgnored == true
                    ? AppTheme.primaryColor
                    : AppTheme.warning,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('电池优化（关键）'),
                    const SizedBox(height: 2),
                    Text(
                      _batteryOptIgnored == true
                          ? '已关闭电池优化，提醒不受影响'
                          : '未关闭，退出APP后提醒可能失效',
                      style: TextStyle(
                        color: _batteryOptIgnored == true
                            ? AppTheme.textSecondary
                            : AppTheme.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_batteryOptIgnored != true)
                TextButton(
                  onPressed: () async {
                    await BatteryOptimizationService.request();
                    await Future.delayed(const Duration(seconds: 1));
                    final ignored = await BatteryOptimizationService.isIgnoring();
                    if (!mounted) return;
                    setState(() => _batteryOptIgnored = ignored);
                    if (ignored) {
                      showAppSnackBar(context, '已关闭电池优化');
                    }
                  },
                  child: const Text('去设置'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocalDataSection() {
    return _SectionCard(
      title: '本地数据',
      children: [
        _SettingsRow(
          icon: Icons.folder_open_outlined,
          title: '保存位置',
          subtitle: _dataDirectory ?? '使用默认应用数据目录',
          onTap: _dataBusy ? () {} : _chooseLocalDataDirectory,
        ),
        const SizedBox(height: 12),
        _SettingsRow(
          icon: Icons.file_upload_outlined,
          title: '导入数据',
          subtitle: '从本地数据备份导入，重启后生效',
          onTap: _dataBusy ? () {} : _importLocalData,
        ),
        const SizedBox(height: 12),
        _SettingsRow(
          icon: Icons.file_download_outlined,
          title: '导出备份',
          subtitle: '导出数据库、附件和本机偏好设置',
          onTap: _dataBusy ? () {} : _exportLocalData,
        ),
      ],
    );
  }

  Future<void> _chooseLocalDataDirectory() async {
    final path = await _localDataService.pickDataDirectory();
    if (path == null || path.trim().isEmpty) return;
    setState(() => _dataBusy = true);
    try {
      await widget.database?.checkpointForBackup();
      await _localDataService.setDataDirectory(path);
      if (!mounted) return;
      setState(() => _dataDirectory = path);
      showAppSnackBar(context, '保存位置已更新，重启后生效');
    } catch (e) {
      if (mounted) showAppSnackBar(context, '保存位置更新失败：$e');
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
  }

  Future<void> _importLocalData() async {
    final path = await _localDataService.pickBackupFile();
    if (path == null) return;
    setState(() => _dataBusy = true);
    try {
      final importedDir = await _localDataService.importBackupToNewDirectory(
        path,
      );
      if (!mounted) return;
      setState(() => _dataDirectory = importedDir);
      showAppSnackBar(context, '数据已导入，重启后生效');
    } catch (e) {
      if (mounted) showAppSnackBar(context, '数据导入失败：$e');
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
  }

  Future<void> _exportLocalData() async {
    setState(() => _dataBusy = true);
    try {
      await widget.database?.checkpointForBackup();
      final path = await _localDataService.exportBackup();
      if (mounted && path != null) {
        showAppSnackBar(context, '备份已导出');
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, '备份导出失败：$e');
    } finally {
      if (mounted) setState(() => _dataBusy = false);
    }
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
