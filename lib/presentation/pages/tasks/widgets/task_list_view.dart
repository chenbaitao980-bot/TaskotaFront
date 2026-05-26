import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import 'task_card.dart';

/// 树节点展示数据
class _TreeNodeData {
  final Task task;
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final String? parentId;

  const _TreeNodeData({
    required this.task,
    required this.depth,
    required this.hasChildren,
    required this.isExpanded,
    required this.parentId,
  });
}

class TaskListView extends StatefulWidget {
  final List<Task> tasks;
  final Map<String, String> projectNames;
  final Map<String, int> taskProgress;
  final String? selectedFilter;
  final String? selectedProjectId;
  final Set<String> expandedIds;
  final void Function(String id) onTaskTap;
  final void Function(String id) onTaskToggle;
  final void Function(String id) onTaskDelete;
  final void Function(String taskId, String? newParentId) onMoveToParent;
  final void Function(String taskId) onToggleExpand;

  const TaskListView({
    super.key,
    required this.tasks,
    this.projectNames = const {},
    this.taskProgress = const {},
    this.selectedFilter,
    this.selectedProjectId,
    this.expandedIds = const {},
    required this.onTaskTap,
    required this.onTaskToggle,
    required this.onTaskDelete,
    required this.onMoveToParent,
    required this.onToggleExpand,
  });

  @override
  State<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends State<TaskListView> {
  /// 构建树形扁平列表（DFS序）
  List<_TreeNodeData> _buildFlatTree(
    List<Task> allTasks,
    Set<String> expandedIds,
  ) {
    final result = <_TreeNodeData>[];
    final taskIds = allTasks.map((t) => t.id).toSet();
    final rootTasks = allTasks.where((t) {
      final parentId = t.parentId;
      return parentId == null || !taskIds.contains(parentId);
    }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    for (final root in rootTasks) {
      _addNode(root, 0, allTasks, expandedIds, result);
    }
    return result;
  }

  void _addNode(
    Task task,
    int depth,
    List<Task> allTasks,
    Set<String> expandedIds,
    List<_TreeNodeData> result,
  ) {
    final children = allTasks.where((t) => t.parentId == task.id).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final hasChildren = children.isNotEmpty;
    final isExpanded = expandedIds.contains(task.id);
    result.add(
      _TreeNodeData(
        task: task,
        depth: depth,
        hasChildren: hasChildren,
        isExpanded: isExpanded,
        parentId: task.parentId,
      ),
    );

    if (hasChildren && isExpanded) {
      for (final child in children) {
        _addNode(child, depth + 1, allTasks, expandedIds, result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingTasks = widget.tasks.where((t) => t.status == 0).toList();
    final completedTasks = widget.tasks.where((t) => t.status == 2).toList();

    if (pendingTasks.isEmpty && completedTasks.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        if (pendingTasks.isNotEmpty) ...[
          _buildSectionHeader(context, '待完成', pendingTasks.length),
          // 根级拖放区
          _buildRootDropZone(context),
          ..._buildTreeNodes(pendingTasks),
        ],
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildCompletedSection(context, completedTasks),
        ],
      ],
    );
  }

  /// 根级拖放区：拖到这里移为根任务
  Widget _buildRootDropZone(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        // 找到被拖任务及其父级
        final draggedTask = widget.tasks
            .where((t) => t.id == draggedId)
            .firstOrNull;
        if (draggedTask == null) return;
        if (draggedTask.parentId == null) return; // 已是根任务，不操作
        widget.onMoveToParent(draggedId, null);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;
        // 只对非根任务显示（正在拖的任务 parentId != null 时才高亮）
        final hasNonRootDrag = candidateData.any((id) {
          final t = widget.tasks.where((t) => t.id == id).firstOrNull;
          return t != null && t.parentId != null;
        });
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDragOver && hasNonRootDrag
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : AppTheme.primaryColor.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: isDragOver && hasNonRootDrag
                ? Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : Border.all(
                    color: AppTheme.borderSubtle.withValues(alpha: 0.5),
                    width: 1,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.keyboard_return_rounded,
                size: 16,
                color: isDragOver && hasNonRootDrag
                    ? AppTheme.primaryColor
                    : AppTheme.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                '拖到此处移为根任务',
                style: TextStyle(
                  fontSize: 12,
                  color: isDragOver && hasNonRootDrag
                      ? AppTheme.primaryColor
                      : AppTheme.textHint,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建所有树节点
  List<Widget> _buildTreeNodes(List<Task> pendingTasks) {
    final treeNodes = _buildFlatTree(pendingTasks, widget.expandedIds);
    return treeNodes.map((node) => _buildTreeNode(node)).toList();
  }

  List<Widget> _buildCompletedTreeNodes(List<Task> completedTasks) {
    final treeNodes = _buildFlatTree(completedTasks, widget.expandedIds);
    return treeNodes.map((node) {
      return TaskCard(
        task: node.task,
        projectName: widget.projectNames[node.task.projectId],
        progress: widget.taskProgress[node.task.id] ?? 100,
        depth: node.depth,
        hasChildren: node.hasChildren,
        isExpanded: node.isExpanded,
        onToggleExpand: node.hasChildren
            ? () => widget.onToggleExpand(node.task.id)
            : null,
        showDragHandle: false,
        onTap: () => widget.onTaskTap(node.task.id),
        onToggle: () => widget.onTaskToggle(node.task.id),
        onDelete: () => widget.onTaskDelete(node.task.id),
      );
    }).toList();
  }

  /// 构建单个树节点（Draggable + DragTarget）
  Widget _buildTreeNode(_TreeNodeData node) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        final draggedId = details.data;
        // 不能拖到自己身上
        if (draggedId == node.task.id) return false;
        // 不能拖到自己的子节点（防止循环）：检查 dropTarget 是否是 dragged 的后代
        if (_isDescendant(draggedId, node.task.id)) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        if (draggedId == node.task.id) return;
        widget.onMoveToParent(draggedId, node.task.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isDragOver = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isDragOver
                ? AppTheme.primaryColor.withValues(alpha: 0.08)
                : null,
            border: isDragOver
                ? Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 拖拽手柄（Draggable）
              _DragHandle(taskId: node.task.id, title: node.task.title),
              // 展开/折叠箭头
              if (node.hasChildren)
                GestureDetector(
                  onTap: () => widget.onToggleExpand(node.task.id),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    child: Icon(
                      node.isExpanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),
              // TaskCard 内容（展开箭头、拖拽手柄已在外层，内层关闭）
              Expanded(
                child: TaskCard(
                  task: node.task,
                  projectName: widget.projectNames[node.task.projectId],
                  progress: widget.taskProgress[node.task.id] ?? 0,
                  depth: node.depth,
                  hasChildren: false,
                  isExpanded: false,
                  onToggleExpand: null,
                  showDragHandle: false,
                  onTap: () => widget.onTaskTap(node.task.id),
                  onToggle: () => widget.onTaskToggle(node.task.id),
                  onDelete: () => widget.onTaskDelete(node.task.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 判断 targetId 是否是 ancestorId 的后代
  bool _isDescendant(String ancestorId, String targetId) {
    final allTasks = widget.tasks;
    String? current = targetId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      if (current == ancestorId) return true;
      final task = allTasks.where((t) => t.id == current).firstOrNull;
      current = task?.parentId;
    }
    return false;
  }

  Widget _buildEmptyState(BuildContext context) {
    String message;
    IconData icon;

    if (widget.selectedFilter == 'today') {
      message = '今天没有任务';
      icon = Icons.today_rounded;
    } else if (widget.selectedFilter == 'important') {
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
            style: const TextStyle(color: AppTheme.textHint, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
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
    BuildContext context,
    List<Task> completedTasks,
  ) {
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
            const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: AppTheme.success,
            ),
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
        children: _buildCompletedTreeNodes(completedTasks),
      ),
    );
  }
}

/// 拖拽手柄组件
class _DragHandle extends StatelessWidget {
  final String taskId;
  final String title;

  const _DragHandle({required this.taskId, required this.title});

  @override
  Widget build(BuildContext context) {
    return Draggable<String>(
      data: taskId,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.drag_indicator_rounded,
            size: 20,
            color: AppTheme.textHint,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.drag_indicator_rounded,
          size: 20,
          color: AppTheme.textHint.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
