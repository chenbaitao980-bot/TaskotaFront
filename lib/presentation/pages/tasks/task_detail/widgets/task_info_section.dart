import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';

class TaskInfoSection extends StatelessWidget {
  final Task task;
  final String? projectName;

  const TaskInfoSection({
    super.key,
    required this.task,
    this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 项目
          if (projectName != null)
            _buildInfoRow(Icons.folder_outlined, projectName!),
          // 优先级
          _buildInfoRow(Icons.flag_outlined, _priorityLabel(task.priority)),
          // 时间范围
          if (task.startDate != null || task.dueDate != null)
            _buildInfoRow(
              Icons.schedule_outlined,
              _formatDateRange(task.startDate, task.dueDate),
            ),
          // 描述
          if (task.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.description_outlined,
                          size: 16, color: AppTheme.textHint),
                      SizedBox(width: 8),
                      Text(
                        '描述',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          // 创建时间
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: AppTheme.textHint),
                const SizedBox(width: 8),
                Text(
                  '创建于 ${_formatDateTime(task.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textHint),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 5:
        return '高优先级';
      case 3:
        return '中优先级';
      case 1:
        return '低优先级';
      default:
        return '无优先级';
    }
  }

  String _formatDateRange(int? start, int? end) {
    if (start == null && end == null) return '';
    final startStr = start != null
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(start))
        : '';
    final endStr = end != null
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(end))
        : '';
    if (startStr == endStr) return startStr;
    if (startStr.isEmpty) return '截止 $endStr';
    if (endStr.isEmpty) return '开始 $startStr';
    return '$startStr → $endStr';
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
