import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import 'task_card.dart';

class TaskListView extends StatelessWidget {
  final List<Task> tasks;
  final Map<String, String> projectNames;
  final String? selectedFilter;
  final String? selectedProjectId;
  final void Function(String id) onTaskTap;
  final void Function(String id) onTaskToggle;
  final void Function(String id) onTaskDelete;

  const TaskListView({
    super.key,
    required this.tasks,
    this.projectNames = const {},
    this.selectedFilter,
    this.selectedProjectId,
    required this.onTaskTap,
    required this.onTaskToggle,
    required this.onTaskDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pendingTasks = tasks.where((t) => t.status == 0).toList();
    final completedTasks = tasks.where((t) => t.status == 2).toList();

    if (tasks.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // 未完成任务
        if (pendingTasks.isNotEmpty) ...[
          _buildSectionHeader(context, '待完成', pendingTasks.length),
          ...pendingTasks.map((t) => TaskCard(
                task: t,
                projectName: projectNames[t.projectId],
                onTap: () => onTaskTap(t.id),
                onToggle: () => onTaskToggle(t.id),
                onDelete: () => onTaskDelete(t.id),
              )),
        ],
        // 已完成任务
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompletedSection(context, completedTasks),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    if (selectedFilter == 'today') {
      message = '今天没有任务';
      icon = Icons.today_rounded;
    } else if (selectedFilter == 'important') {
      message = '没有重要任务';
      icon = Icons.star_outline_rounded;
    } else {
      message = '还没有任务\n点击右下角 + 创建';
      icon = Icons.checklist_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textHint),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textHint,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection(
      BuildContext context, List<Task> completedTasks) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 18, color: AppTheme.success),
            const SizedBox(width: 8),
            Text(
              '已完成 (${completedTasks.length})',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        initiallyExpanded: false,
        children: completedTasks.map((t) => TaskCard(
              task: t,
              projectName: projectNames[t.projectId],
              onTap: () => onTaskTap(t.id),
              onToggle: () => onTaskToggle(t.id),
              onDelete: () => onTaskDelete(t.id),
            )).toList(),
      ),
    );
  }
}
