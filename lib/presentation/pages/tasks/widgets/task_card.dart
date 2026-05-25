import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final String? projectName;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.projectName,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 2;
    final priorityColor = _priorityColor(task.priority);

    return Slidable(
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onToggle(),
            backgroundColor: AppTheme.success,
            foregroundColor: Colors.white,
            icon: isCompleted ? Icons.undo : Icons.check,
            label: isCompleted ? '撤销' : '完成',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: AppTheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '删除',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 优先级色条
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted ? AppTheme.textHint : priorityColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                // 复选框
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? AppTheme.primaryColor
                            : AppTheme.textHint,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和项目名
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isCompleted
                              ? AppTheme.textHint
                              : AppTheme.textPrimary,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (projectName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          projectName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 截止日期
                if (task.dueDate != null)
                  Text(
                    _formatDate(task.dueDate!),
                    style: TextStyle(
                      fontSize: 12,
                      color: _isOverdue(task.dueDate!)
                          ? AppTheme.error
                          : AppTheme.textHint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 5:
        return AppTheme.priorityP0;
      case 3:
        return AppTheme.priorityP1;
      case 1:
        return AppTheme.priorityP3;
      default:
        return AppTheme.borderSubtle;
    }
  }

  bool _isOverdue(int timestamp) {
    final now = DateTime.now();
    final due = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return due.isBefore(now);
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (target == today) return '今天 $time';
    if (target == today.add(const Duration(days: 1))) return '明天 $time';
    if (target == today.subtract(const Duration(days: 1))) return '昨天 $time';
    return '${date.month}/${date.day} $time';
  }
}
