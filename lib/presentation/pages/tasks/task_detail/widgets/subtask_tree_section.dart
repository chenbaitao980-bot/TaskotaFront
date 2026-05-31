import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../../services/subtask_scheduler.dart';
import '../../../../blocs/task_new/task_bloc.dart';
import '../../../../blocs/task_new/task_event.dart';
import '../../../../blocs/task_new/task_state.dart';
import '../../widgets/task_create_sheet.dart';
import '../task_detail_page.dart';

class SubtaskTreeSection extends StatefulWidget {
  final Task task;
  final String projectId;

  const SubtaskTreeSection({
    super.key,
    required this.task,
    required this.projectId,
  });

  @override
  State<SubtaskTreeSection> createState() => _SubtaskTreeSectionState();
}

class _SubtaskTreeSectionState extends State<SubtaskTreeSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTree();
    });
  }

  void _loadTree() {
    context.read<TaskNewBloc>().add(LoadSubTree(rootTaskId: widget.task.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskNewBloc, TaskNewState>(
      buildWhen: (prev, curr) {
        if (prev is! TaskNewLoaded || curr is! TaskNewLoaded) return true;
        final rootId = widget.task.id;
        return prev.subTrees[rootId] != curr.subTrees[rootId] ||
            prev.expandedNodes[rootId] != curr.expandedNodes[rootId];
      },
      builder: (context, state) {
        if (state is! TaskNewLoaded) return const SizedBox.shrink();
        final rootId = widget.task.id;
        final descendants = state.subTrees[rootId] ?? [];
        final expandedNodes = state.expandedNodes[rootId] ?? {};

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 紧凑头部
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '子任务 (${descendants.length})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showAddSubTaskDialog(context, rootId),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      color: AppTheme.primaryColor,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: '添加子任务',
                    ),
                  ],
                ),
              ),
              if (descendants.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                  child: Text(
                    '暂无子任务',
                    style: TextStyle(color: AppTheme.textHint, fontSize: 11),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: _buildTree(
                          descendants,
                          rootId,
                          expandedNodes,
                          rootId,
                          0,
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildTree(
    List<Task> allTasks,
    String rootId,
    Set<String> expandedNodes,
    String parentId,
    int depth,
    BuildContext context,
  ) {
    final children = allTasks.where((t) => t.parentId == parentId).toList();
    children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final widgets = <Widget>[];
    for (final child in children) {
      final hasChildren = allTasks.any((t) => t.parentId == child.id);
      final isExpanded = expandedNodes.contains(child.id);

      widgets.add(
        _buildNodeRow(
          child: child,
          depth: depth,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          rootId: rootId,
          allTasks: allTasks,
        ),
      );

      if (isExpanded && hasChildren) {
        widgets.addAll(
          _buildTree(
            allTasks,
            rootId,
            expandedNodes,
            child.id,
            depth + 1,
            context,
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildNodeRow({
    required Task child,
    required int depth,
    required bool hasChildren,
    required bool isExpanded,
    required String rootId,
    required List<Task> allTasks,
  }) {
    final isCompleted = child.status == 2;

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        final draggedId = details.data;
        if (draggedId == child.id) return;
        context.read<TaskNewBloc>().add(
          MoveSubTask(
            taskId: draggedId,
            newParentId: child.id,
            rootTaskId: rootId,
          ),
        );
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
          ),
          child: Padding(
            padding: EdgeInsets.only(left: 4.0 + depth * 16),
            child: Row(
              children: [
                // 拖拽手柄（仅此处可拖拽）
                Draggable<String>(
                  data: child.id,
                  onDragStarted: () {},
                  onDragEnd: (_) {},
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        child.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
                      color: AppTheme.textHint,
                    ),
                  ),
                ),
                // 展开/折叠
                if (hasChildren)
                  GestureDetector(
                    onTap: () => context.read<TaskNewBloc>().add(
                      ToggleTreeNode(rootTaskId: rootId, nodeId: child.id),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: AppTheme.textHint,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 26),
                // 复选框
                GestureDetector(
                  onTap: () => context.read<TaskNewBloc>().add(
                    ToggleSubTask(id: child.id, rootTaskId: rootId),
                  ),
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppTheme.success
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? AppTheme.success
                            : AppTheme.textHint,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ),
                // 标题（点击直接进入子任务编辑页）
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _editSubTask(context, child),
                    child: Text(
                      child.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: isCompleted
                            ? AppTheme.textHint
                            : AppTheme.textPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
                // 操作菜单
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'add_child') {
                      _showAddSubTaskDialog(context, child.id);
                    } else if (action == 'edit') {
                      _editSubTask(context, child);
                    } else if (action == 'delete') {
                      _deleteSubTask(context, child, rootId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_child',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, size: 16),
                          SizedBox(width: 8),
                          Text('添加子任务'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('编辑'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: AppTheme.error,
                          ),
                          SizedBox(width: 8),
                          Text('删除', style: TextStyle(color: AppTheme.error)),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_horiz,
                    size: 16,
                    color: AppTheme.textHint,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 复用 TaskCreateSheet：自带开始/截止时间 + 子任务时间冲突检测
  Future<void> _showAddSubTaskDialog(
    BuildContext context,
    String parentId,
  ) async {
    final bloc = context.read<TaskNewBloc>();
    final blocState = bloc.state;
    final availableParents = blocState is TaskNewLoaded
        ? blocState.tasks.where((t) => t.status == 0).toList()
        : const <Task>[];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskCreateSheet(
        initialProjectId: widget.projectId,
        projectRepository: bloc.projectRepository,
        taskRepository: bloc.taskRepository,
        initialParentId: parentId,
        availableParentTasks: availableParents,
      ),
    );

    if (result == null || !mounted) return;
    bloc.add(
      CreateTask(
        projectId: (result['projectId'] as String?) ?? widget.projectId,
        title: result['title'] as String,
        description: result['description'] as String? ?? '',
        priority: result['priority'] as int? ?? 1,
        startDate: result['startDate'] as int?,
        dueDate: result['dueDate'] as int?,
        parentId: (result['parentId'] as String?) ?? parentId,
        shiftedTasks:
            (result['shiftedTasks'] as List<ScheduledTaskShift>?) ?? const [],
      ),
    );
    // 刷新当前根任务子树
    bloc.add(LoadSubTree(rootTaskId: widget.task.id));
  }

  void _editSubTask(BuildContext context, Task task) {
    final bloc = context.read<TaskNewBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: TaskDetailPage(task: task),
        ),
      ),
    ).then((_) {
      if (mounted) {
        // 回到父任务后刷新子树，反映子任务的更新
        bloc.add(LoadSubTree(rootTaskId: widget.task.id));
      }
      // 无论编辑保存还是删除，都刷新树
      if (mounted) _loadTree();
    });
  }

  void _deleteSubTask(BuildContext context, Task task, String rootId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除子任务'),
        content: Text('确定要删除"${task.title}"及其所有子任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskNewBloc>().add(
                DeleteSubTask(taskId: task.id, rootTaskId: rootId),
              );
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
