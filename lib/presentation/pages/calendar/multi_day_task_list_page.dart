import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/database/app_database.dart';
import '../../blocs/task_new/task_bloc.dart';

/// 全部跨天任务列表页（全屏弹窗）
///
/// 从甘特图区域右下角的「查看全部 N 条 ▸」入口进入。
/// 每条以横向长条样式展示，保留优先级颜色、Checkbox 和日期跨度；
/// 点击跳转详情，右键/长按弹出操作菜单。
class MultiDayTaskListPage extends StatelessWidget {
  final List<Task> tasks;
  final Future<void> Function(Task) onOpenTask;
  final Future<void> Function(Task) onContextActions;
  final Color Function(int priority) priorityColor;

  const MultiDayTaskListPage({
    super.key,
    required this.tasks,
    required this.onOpenTask,
    required this.onContextActions,
    required this.priorityColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('全部跨天任务 (${tasks.length})'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text('暂无跨天任务'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _MultiDayTaskItem(
                  task: task,
                  color: priorityColor(task.priority),
                  onTap: () async {
                    await onOpenTask(task);
                  },
                  onContextAction: () async {
                    await onContextActions(task);
                  },
                );
              },
            ),
    );
  }
}

class _MultiDayTaskItem extends StatelessWidget {
  final Task task;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onContextAction;

  const _MultiDayTaskItem({
    required this.task,
    required this.color,
    required this.onTap,
    required this.onContextAction,
  });

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
  }

  String get _dateSpan {
    final s = task.startDate;
    final e = task.dueDate;
    if (s == null && e == null) return '';
    if (s == null) return '- ${_formatDate(e!)}';
    if (e == null) return '${_formatDate(s)} -';
    return '${_formatDate(s)} – ${_formatDate(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 2;
    final barColor = isCompleted ? Colors.grey.shade500 : color;

    return GestureDetector(
      onSecondaryTap: onContextAction,
      onLongPress: onContextAction,
      child: Material(
        color: barColor.withValues(alpha: isCompleted ? 0.62 : 0.9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: IgnorePointer(
                        child: Checkbox(
                          value: isCompleted,
                          onChanged: null,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          side: const BorderSide(color: Colors.white, width: 1.5),
                          checkColor: Colors.grey,
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCompleted
                              ? Colors.white.withValues(alpha: 0.72)
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_dateSpan.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      _dateSpan,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 独立页面入口（不依赖 CalendarPage State），供从其他地方直接 push 使用。
///
/// [tasks] 当前周所有跨天任务（已筛选）。
/// [onReload] 弹窗关闭后需要刷新数据时的回调。
Future<void> showMultiDayTaskListPage({
  required BuildContext context,
  required List<Task> tasks,
  required Future<void> Function(Task) onOpenTask,
  required Future<void> Function(Task) onContextActions,
  required Color Function(int) priorityColor,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider.value(
        value: context.read<TaskNewBloc>(),
        child: MultiDayTaskListPage(
          tasks: tasks,
          onOpenTask: onOpenTask,
          onContextActions: onContextActions,
          priorityColor: priorityColor,
        ),
      ),
    ),
  );
}
