import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../blocs/task_new/task_bloc.dart';
import '../../../blocs/task_new/task_event.dart';
import '../../../widgets/calendar_date_picker.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final String? projectName;
  final int progress;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  // 树形结构属性
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;
  final bool showDragHandle;

  const TaskCard({
    super.key,
    required this.task,
    this.projectName,
    this.progress = 0,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggleExpand,
    this.showDragHandle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 2;
    final progressPercent = progress.clamp(0, 100).toInt();
    final priorityColor = _priorityColorByInt(task.priority);

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
      child: GestureDetector(
        onSecondaryTapUp: (details) => _showContextMenu(context, details.globalPosition),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                // 缩进空白（由外层树形线负责，此处保留以兼容独立使用场景）
                if (depth > 0) SizedBox(width: depth * 24.0),

                // 拖拽手柄
                if (showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: AppTheme.textHint.withValues(alpha: 0.5),
                    ),
                  ),

                // 展开/折叠箭头
                if (hasChildren)
                  GestureDetector(
                    onTap: onToggleExpand,
                    child: Container(
                      width: 24, height: 24,
                      alignment: Alignment.center,
                      child: Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.textHint,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 24),

                // 优先级胶囊（下拉切换）
                _PriorityPill(
                  priority: task.priority,
                  color: isCompleted ? AppTheme.textHint : priorityColor,
                  label: _priorityShortLabel(task.priority),
                  onSelected: (p) {
                    context.read<TaskNewBloc>().add(
                          UpdateTask(id: task.id, priority: p),
                        );
                  },
                ),
                const SizedBox(width: 8),

                // 复选框
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 22, height: 22,
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
                      if (projectName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            projectName!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? AppTheme.textHint
                                  : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressPercent / 100,
                                minHeight: 4,
                                backgroundColor: AppTheme.borderSubtle
                                    .withValues(alpha: 0.6),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isCompleted
                                      ? AppTheme.success
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              '$progressPercent%',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textHint,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 截止日期（点击编辑日期）
                if (task.dueDate != null)
                  GestureDetector(
                    onTap: () => _editDate(context, task),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isOverdue(task.dueDate!)
                            ? AppTheme.error.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDate(task.dueDate!),
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOverdue(task.dueDate!)
                              ? AppTheme.error
                              : AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18),
              SizedBox(width: 8),
              Text('编辑'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'archive',
          child: Row(
            children: [
              Icon(Icons.archive_outlined, size: 18),
              SizedBox(width: 8),
              Text('归档'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('删除', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'edit') onTap();
      if (value == 'archive') {
        context.read<TaskNewBloc>().add(ArchiveTask(id: task.id));
      }
      if (value == 'delete') onDelete();
    });
  }

  String _priorityShortLabel(int p) {
    switch (p) {
      case 5: return '高';
      case 3: return '中';
      case 1: return '低';
      default: return '无';
    }
  }

  Future<void> _editDate(BuildContext context, Task task) async {
    final now = DateTime.now();
    final current = task.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(task.dueDate!)
        : now;
    final picked = await showCalendarDatePicker(
      context: context,
      initialDate: current,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null || !context.mounted) return;
    final updated = DateTime(
      picked.year, picked.month, picked.day,
      current.hour, current.minute,
    );
    context.read<TaskNewBloc>().add(UpdateTask(
      id: task.id,
      startDate: task.startDate,
      dueDate: updated.millisecondsSinceEpoch,
    ));
  }

  Color _priorityColorByInt(int priority) {
    switch (priority) {
      case 5: return AppTheme.priorityP0;
      case 3: return AppTheme.priorityP1;
      case 1: return AppTheme.priorityP3;
      default: return AppTheme.borderSubtle;
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

class _PriorityPill extends StatelessWidget {
  final int priority;
  final Color color;
  final String label;
  final ValueChanged<int> onSelected;

  const _PriorityPill({
    required this.priority,
    required this.color,
    required this.label,
    required this.onSelected,
  });

  static final _options = [
    (0, '无', AppTheme.textHint),
    (1, '低', AppTheme.priorityP3),
    (3, '中', AppTheme.priorityP1),
    (5, '高', AppTheme.priorityP0),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '优先级',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (_) => _options.map((o) {
        return PopupMenuItem<int>(
          value: o.$1,
          height: 36,
          child: Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: o.$3,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(o.$2, style: const TextStyle(fontSize: 13)),
              if (priority == o.$1) ...[
                const Spacer(),
                Icon(Icons.check, size: 14, color: AppTheme.primaryColor),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}
