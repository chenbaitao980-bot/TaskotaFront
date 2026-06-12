import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/database/app_database.dart';
import '../../blocs/task_new/task_bloc.dart';

/// 全部跨天任务列表页（全屏弹窗）
///
/// 从甘特图区域右下角的「查看全部 N 条 ▸」入口进入。
/// 每条以横向长条样式展示，宽度按时间跨度比例区分；
/// 按父子关系 DFS 排序，子任务有缩进；
/// 保留优先级颜色、Checkbox 和日期跨度；
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

  /// 按父子关系 DFS 排序，返回 (task, depth) 列表
  List<(Task, int)> _sortedTasksWithDepth() {
    final taskIds = tasks.map((t) => t.id).toSet();

    // 找组根：在跨天任务集合内找最顶层祖先
    Task groupRoot(Task task) {
      var cur = task;
      final visited = <String>{};
      while (cur.parentId != null &&
          taskIds.contains(cur.parentId!) &&
          visited.add(cur.id)) {
        final parent = tasks.where((t) => t.id == cur.parentId).firstOrNull;
        if (parent == null) break;
        cur = parent;
      }
      return cur;
    }

    // 分组
    final Map<String, Task> rootById = {};
    final Map<String, List<Task>> childrenByRoot = {};
    for (final task in tasks) {
      final root = groupRoot(task);
      rootById[root.id] = root;
      childrenByRoot.putIfAbsent(root.id, () => []);
      if (task.id != root.id) {
        childrenByRoot[root.id]!.add(task);
      }
    }

    // 组间按跨度降序
    int spanMs(Task t) {
      final s = t.startDate;
      final d = t.dueDate;
      if (s == null || d == null) return 0;
      return d - s;
    }

    int effectiveGroupSpan(String rootId) {
      final rootSpan = spanMs(rootById[rootId]!);
      if (rootSpan > 0) return rootSpan;
      final children = childrenByRoot[rootId] ?? [];
      return children.map(spanMs).fold(0, (a, b) => a > b ? a : b);
    }

    final sortedRootIds = rootById.keys.toList()
      ..sort((a, b) => effectiveGroupSpan(b).compareTo(effectiveGroupSpan(a)));

    // DFS 递归，带深度
    List<(Task, int)> dfsChildren(
        List<Task> allChildren, String parentId, int depth) {
      final direct = allChildren
          .where((t) => t.parentId == parentId)
          .toList()
        ..sort((a, b) {
          final so = a.sortOrder.compareTo(b.sortOrder);
          if (so != 0) return so;
          return (a.startDate ?? 0).compareTo(b.startDate ?? 0);
        });
      final result = <(Task, int)>[];
      for (final child in direct) {
        result.add((child, depth));
        result.addAll(dfsChildren(allChildren, child.id, depth + 1));
      }
      return result;
    }

    final result = <(Task, int)>[];
    for (final rootId in sortedRootIds) {
      result.add((rootById[rootId]!, 0));
      result.addAll(dfsChildren(childrenByRoot[rootId]!, rootId, 1));
    }
    return result;
  }

  /// 计算任务天数
  int _taskDays(Task task) {
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null || d == null) return 1;
    final days = (d - s) / (24 * 60 * 60 * 1000);
    return days.ceil().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final sortedWithDepth = _sortedTasksWithDepth();
    final maxDays = sortedWithDepth.isEmpty
        ? 1
        : sortedWithDepth.map((e) => _taskDays(e.$1)).reduce((a, b) => a > b ? a : b);

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
          : LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth - 32; // 减去 padding
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: sortedWithDepth.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final (task, depth) = sortedWithDepth[index];
                    final days = _taskDays(task);
                    // 宽度比例：最少 40%，最多 100%
                    final widthRatio = maxDays <= 1
                        ? 1.0
                        : 0.4 + 0.6 * (days / maxDays);
                    final barWidth = availableWidth * widthRatio;
                    final indent = depth * 20.0; // 子任务缩进

                    return Padding(
                      padding: EdgeInsets.only(left: indent),
                      child: _MultiDayTaskItem(
                        task: task,
                        color: priorityColor(task.priority),
                        barWidth: barWidth,
                        onTap: () async {
                          await onOpenTask(task);
                        },
                        onContextAction: () async {
                          await onContextActions(task);
                        },
                      ),
                    );
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
  final double barWidth;
  final VoidCallback onTap;
  final VoidCallback onContextAction;

  const _MultiDayTaskItem({
    required this.task,
    required this.color,
    required this.barWidth,
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

  int get _days {
    final s = task.startDate;
    final d = task.dueDate;
    if (s == null || d == null) return 0;
    return ((d - s) / (24 * 60 * 60 * 1000)).ceil().clamp(1, 999);
  }

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 2;
    final barColor = isCompleted ? Colors.grey.shade500 : color;

    return GestureDetector(
      onSecondaryTap: onContextAction,
      onLongPress: onContextAction,
      child: SizedBox(
        width: barWidth,
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
                        '$_dateSpan（$_days天）',
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
      ),
    );
  }
}

/// 独立页面入口（不依赖 CalendarPage State），供从其他地方直接 push 使用。
///
/// [tasks] 当前周所有跨天任务（已筛选）。
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
