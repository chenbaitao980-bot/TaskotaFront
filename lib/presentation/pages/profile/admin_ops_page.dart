import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../services/supabase_service.dart';

class AdminOpsPage extends StatefulWidget {
  final AppDatabase? database;
  final TaskRepository? taskRepository;
  final ProjectRepository? projectRepository;

  const AdminOpsPage({
    super.key,
    this.database,
    this.taskRepository,
    this.projectRepository,
  });

  @override
  State<AdminOpsPage> createState() => _AdminOpsPageState();
}

class _AdminOpsPageState extends State<AdminOpsPage> {
  late Future<_OpsSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _load();
  }

  Future<_OpsSnapshot> _load() async {
    final user = SupabaseService().currentUser;
    final tasks = await widget.taskRepository?.getAll() ?? const <Task>[];
    final projects =
        await widget.projectRepository?.getActive() ?? const <Project>[];
    final db = widget.database;
    final checklistItems = db == null
        ? const <ChecklistItem>[]
        : await db.select(db.checklistItems).get();
    final attachments = db == null
        ? const <TaskAttachment>[]
        : await db.select(db.taskAttachments).get();
    final completedTasks = tasks.where((t) => t.status == 2).length;
    final deletedChecklistItems = checklistItems
        .where((item) => item.deleted == 1)
        .length;
    return _OpsSnapshot(
      user: user,
      taskCount: tasks.length,
      completedTaskCount: completedTasks,
      projectCount: projects.length,
      checklistCount: checklistItems.where((i) => i.deleted == 0).length,
      attachmentCount: attachments.length,
      deletedChecklistCount: deletedChecklistItems,
      latestTaskUpdatedAt: tasks.fold<int>(
        0,
        (maxValue, task) =>
            task.updatedAt > maxValue ? task.updatedAt : maxValue,
      ),
    );
  }

  void _refresh() {
    setState(() => _snapshotFuture = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgScaffold,
      appBar: AppBar(
        title: const Text('运维后台'),
        backgroundColor: AppTheme.bgScaffold,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '刷新',
          ),
        ],
      ),
      body: FutureBuilder<_OpsSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildUserPanel(data),
              const SizedBox(height: 12),
              _buildMetricGrid(data),
              const SizedBox(height: 12),
              _buildOpsSection(data),
              const SizedBox(height: 12),
              _buildAdminBoundary(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserPanel(_OpsSnapshot data) {
    final user = data.user;
    return _Panel(
      title: '用户查询',
      icon: Icons.manage_accounts_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: '当前用户', value: user?.email ?? user?.phone ?? '未登录'),
          _InfoRow(label: '用户 ID', value: user?.id ?? '-'),
          _InfoRow(
            label: '登录方式',
            value: user?.appMetadata['provider']?.toString() ?? '-',
          ),
          _InfoRow(label: '邮箱确认', value: user?.emailConfirmedAt ?? '-'),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(_OpsSnapshot data) {
    final metrics = [
      ('任务', data.taskCount.toString(), Icons.task_alt_rounded),
      ('已完成', data.completedTaskCount.toString(), Icons.check_circle_rounded),
      ('项目', data.projectCount.toString(), Icons.folder_rounded),
      ('检查项', data.checklistCount.toString(), Icons.checklist_rounded),
      ('附件', data.attachmentCount.toString(), Icons.attachment_rounded),
      ('同步模式', '实时', Icons.sync_rounded),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 96,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final (label, value, icon) = metrics[index];
        return _MetricCard(label: label, value: value, icon: icon);
      },
    );
  }

  Widget _buildOpsSection(_OpsSnapshot data) {
    final latest = data.latestTaskUpdatedAt == 0
        ? '-'
        : DateTime.fromMillisecondsSinceEpoch(
            data.latestTaskUpdatedAt,
          ).toLocal().toString();
    return _Panel(
      title: '上线运维',
      icon: Icons.monitor_heart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: '最新任务更新时间', value: latest),
          _InfoRow(
            label: '软删除检查项',
            value: data.deletedChecklistCount.toString(),
          ),
          _InfoRow(label: '数据口径', value: '当前账号可访问的实时本地库与已登录 Supabase 会话'),
        ],
      ),
    );
  }

  Widget _buildAdminBoundary() {
    return _Panel(
      title: '受控管理能力',
      icon: Icons.admin_panel_settings_rounded,
      child: const Text(
        '全量用户列表、封禁/删除用户、跨用户数据查询、审计日志、备份恢复和密钥轮换需要部署 Supabase Edge Function 或后端服务，以 service_role 在服务端执行。客户端页面不保存 PAT 或 service_role，避免上线泄露。',
        style: TextStyle(fontSize: 13, height: 1.5),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Panel({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpsSnapshot {
  final User? user;
  final int taskCount;
  final int completedTaskCount;
  final int projectCount;
  final int checklistCount;
  final int attachmentCount;
  final int deletedChecklistCount;
  final int latestTaskUpdatedAt;

  const _OpsSnapshot({
    required this.user,
    required this.taskCount,
    required this.completedTaskCount,
    required this.projectCount,
    required this.checklistCount,
    required this.attachmentCount,
    required this.deletedChecklistCount,
    required this.latestTaskUpdatedAt,
  });
}
