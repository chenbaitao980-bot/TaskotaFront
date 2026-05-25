import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/database/app_database.dart';
import '../../../blocs/task_new/task_bloc.dart';
import '../../../blocs/task_new/task_event.dart';
import '../../../blocs/task_new/task_state.dart';
import '../widgets/task_edit_page.dart';
import 'widgets/checklist_section.dart';
import 'widgets/task_info_section.dart';
import 'widgets/subtask_tree_section.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late Task _task;
  List<ChecklistItem> _checklistItems = [];

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadChecklist();
  }

  void _loadChecklist() {
    context.read<TaskNewBloc>().add(LoadChecklistItems(taskId: _task.id));
  }

  String? _getProjectName(BuildContext context) {
    final state = context.read<TaskNewBloc>().state;
    if (state is TaskNewLoaded) {
      final project =
          state.projects.where((p) => p.id == _task.projectId).firstOrNull;
      return project?.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded) {
          final items = state.checklistItems[_task.id] ?? [];
          if (items != _checklistItems) {
            setState(() => _checklistItems = items);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editTask,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outlined),
              onPressed: _deleteTask,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 32),
          children: [
            // 标题和状态
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _task.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleStatus,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _task.status == 2
                            ? AppTheme.success.withValues(alpha: 0.1)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _task.status == 2
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: _task.status == 2
                                ? AppTheme.success
                                : AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _task.status == 2 ? '已完成' : '待完成',
                            style: TextStyle(
                              fontSize: 13,
                              color: _task.status == 2
                                  ? AppTheme.success
                                  : AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 任务信息
            BlocBuilder<TaskNewBloc, TaskNewState>(
              builder: (context, state) {
                return TaskInfoSection(
                  task: _task,
                  projectName: _getProjectName(context),
                );
              },
            ),
            const SizedBox(height: 16),
            // 子任务树
            SubtaskTreeSection(
              task: _task,
              projectId: _task.projectId,
            ),
            const SizedBox(height: 16),
            // 检查项
            ChecklistSection(
              items: _checklistItems,
              taskId: _task.id,
              onToggle: (id) {
                context
                    .read<TaskNewBloc>()
                    .add(ToggleChecklistItem(id: id, taskId: _task.id));
              },
              onDelete: (id) {
                context
                    .read<TaskNewBloc>()
                    .add(DeleteChecklistItem(id: id, taskId: _task.id));
              },
              onEdit: (title) {},
              onAdd: (data) {
                final (taskId, title) = data;
                context
                    .read<TaskNewBloc>()
                    .add(AddChecklistItem(taskId: taskId, title: title));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleStatus() {
    context.read<TaskNewBloc>().add(ToggleTaskStatus(id: _task.id));
    setState(() {
      _task = Task(
        id: _task.id,
        projectId: _task.projectId,
        title: _task.title,
        description: _task.description,
        priority: _task.priority,
        status: _task.status == 0 ? 2 : 0,
        startDate: _task.startDate,
        dueDate: _task.dueDate,
        isAllDay: _task.isAllDay,
        completedTime: _task.status == 0
            ? DateTime.now().millisecondsSinceEpoch
            : _task.completedTime,
        sortOrder: _task.sortOrder,
        createdAt: _task.createdAt,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    });
  }

  Future<void> _editTask() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditPage(
          task: _task,
          projectRepository: context.read<TaskNewBloc>().projectRepository,
        ),
      ),
    );
    if (result != null && mounted) {
      context.read<TaskNewBloc>().add(UpdateTask(
            id: _task.id,
            title: result['title'] as String,
            projectId: result['projectId'] as String,
            description: result['description'] as String,
            priority: result['priority'] as int,
            startDate: result['startDate'] as int?,
            dueDate: result['dueDate'] as int?,
          ));
      setState(() {
        _task = Task(
          id: _task.id,
          projectId: result['projectId'] as String,
          title: result['title'] as String,
          description: result['description'] as String,
          priority: result['priority'] as int,
          status: _task.status,
          startDate: result['startDate'] as int?,
          dueDate: result['dueDate'] as int?,
          isAllDay: _task.isAllDay,
          completedTime: _task.completedTime,
          sortOrder: _task.sortOrder,
          createdAt: _task.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      });
    }
  }

  Future<void> _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${_task.title}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<TaskNewBloc>().add(DeleteTask(id: _task.id));
      Navigator.pop(context);
    }
  }
}
