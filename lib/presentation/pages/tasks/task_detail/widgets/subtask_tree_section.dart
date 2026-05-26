import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../data/database/app_database.dart';
import '../../../../blocs/task_new/task_bloc.dart';
import '../../../../blocs/task_new/task_event.dart';
import '../../../../blocs/task_new/task_state.dart';
import '../../widgets/task_edit_page.dart';

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
      builder: (context, state) {
        if (state is! TaskNewLoaded) return const SizedBox.shrink();
        final rootId = widget.task.id;
        final descendants = state.subTrees[rootId] ?? [];
        final expandedNodes = state.expandedNodes[rootId] ?? {};

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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_tree_outlined,
                      size: 20,
                      color: AppTheme.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '子任务',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (descendants.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${descendants.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showAddSubTaskDialog(context, rootId),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('添加'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (descendants.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      '暂无子任务',
                      style: TextStyle(color: AppTheme.textHint, fontSize: 13),
                    ),
                  ),
                )
              else
                ..._buildTree(
                  descendants,
                  rootId,
                  expandedNodes,
                  rootId,
                  0,
                  context,
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
            padding: EdgeInsets.only(left: 4.0 + depth * 24),
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
                // 标题
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (hasChildren) {
                        context.read<TaskNewBloc>().add(
                          ToggleTreeNode(rootTaskId: rootId, nodeId: child.id),
                        );
                      }
                    },
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
                    const PopupMenuItem(
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
                  icon: const Icon(
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

  void _showAddSubTaskDialog(BuildContext context, String parentId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加子任务'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '子任务名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              context.read<TaskNewBloc>().add(
                AddSubTask(
                  parentId: parentId,
                  title: v.trim(),
                  projectId: widget.projectId,
                ),
              );
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<TaskNewBloc>().add(
                  AddSubTask(
                    parentId: parentId,
                    title: controller.text.trim(),
                    projectId: widget.projectId,
                  ),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _editSubTask(BuildContext context, Task task) {
    final bloc = context.read<TaskNewBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: bloc,
          child: TaskEditPage(
            task: task,
            projectRepository: bloc.projectRepository,
            onAutoSave: (data) {
              bloc.add(
                UpdateTask(
                  id: task.id,
                  title: data['title'] as String,
                  projectId: data['projectId'] as String,
                  description: data['description'] as String,
                  priority: data['priority'] as int,
                  startDate: data['startDate'] as int?,
                  dueDate: data['dueDate'] as int?,
                ),
              );
            },
          ),
        ),
      ),
    ).then((result) {
      if (result != null && mounted) {
        bloc.add(
          UpdateTask(
            id: task.id,
            title: result['title'] as String,
            projectId: result['projectId'] as String,
            description: result['description'] as String,
            priority: result['priority'] as int,
            startDate: result['startDate'] as int?,
            dueDate: result['dueDate'] as int?,
          ),
        );
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
