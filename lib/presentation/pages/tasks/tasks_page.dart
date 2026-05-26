import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import 'widgets/project_sidebar.dart';
import 'widgets/task_list_view.dart';
import 'widgets/task_create_sheet.dart';
import 'task_detail/task_detail_page.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskNewBloc>().add(LoadTasks());
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskNewBloc, TaskNewState>(
      builder: (context, state) {
        if (state is TaskNewLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is TaskNewError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败：${state.message}',
                    style: const TextStyle(color: AppTheme.error),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<TaskNewBloc>().add(LoadTasks()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is TaskNewLoaded) {
          final projectNames = <String, String>{
            for (final p in state.projects) p.id: p.name,
          };
          final selectedFilter = state.selectedFilter ?? 'all';

          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: Text(_getTitle(state)),
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              actions: [
                _buildExpandCollapseButton(state),
                IconButton(
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _showCreateProjectDialog(context),
                ),
              ],
            ),
            drawer: ProjectSidebar(
              projects: state.projects,
              selectedProjectId: state.selectedProjectId,
              selectedFilter: selectedFilter,
              projectProgress: state.projectProgress,
              onProjectSelected: (id) {
                Navigator.pop(context);
                context.read<TaskNewBloc>().add(LoadTasks(projectId: id));
              },
              onFilterSelected: (filter) {
                Navigator.pop(context);
                context.read<TaskNewBloc>().add(LoadTasks(filter: filter));
              },
              onCreateProject: () => _showCreateProjectDialog(context),
              onEditProject: (project) =>
                  _showEditProjectDialog(context, project),
              onDeleteProject: (project) =>
                  _confirmDeleteProject(context, project),
            ),
            body: TaskListView(
              tasks: state.tasks,
              projectNames: projectNames,
              taskProgress: state.taskProgress,
              selectedFilter: selectedFilter,
              selectedProjectId: state.selectedProjectId,
              expandedIds: state.expandedNodes['main_tree'] ?? {},
              onTaskTap: (id) => _openTaskDetail(id, state),
              onTaskToggle: (id) =>
                  context.read<TaskNewBloc>().add(ToggleTaskStatus(id: id)),
              onTaskDelete: (id) => _confirmDeleteTask(id),
              onToggleExpand: (id) =>
                  context.read<TaskNewBloc>().add(ToggleTaskExpand(taskId: id)),
              onMoveToParent: (taskId, newParentId) =>
                  context.read<TaskNewBloc>().add(
                    MoveTaskToParent(
                      taskId: taskId,
                      newParentId: newParentId,
                      projectId: state.selectedProjectId,
                    ),
                  ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showCreateTaskSheet(context),
              elevation: 2,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          );
        }

        return const Scaffold(body: Center(child: Text('初始化中...')));
      },
    );
  }

  String _getTitle(TaskNewLoaded state) {
    if (state.selectedFilter == 'today') return '今天';
    if (state.selectedFilter == 'important') return '重要';
    if (state.selectedProjectId != null) {
      final project = state.projects
          .where((p) => p.id == state.selectedProjectId)
          .firstOrNull;
      return project?.name ?? '任务';
    }
    return '所有任务';
  }

  Widget _buildExpandCollapseButton(TaskNewLoaded state) {
    final allParentIds = state.tasks
        .where((t) => state.tasks.any((c) => c.parentId == t.id))
        .map((t) => t.id)
        .toSet();
    final expandedIds = state.expandedNodes['main_tree'] ?? {};
    if (allParentIds.isEmpty) return const SizedBox.shrink();

    final isAllExpanded = expandedIds.containsAll(allParentIds);
    return IconButton(
      icon: Icon(
        isAllExpanded ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
      ),
      tooltip: isAllExpanded ? '全部折叠' : '全部展开',
      onPressed: () {
        if (isAllExpanded) {
          context.read<TaskNewBloc>().add(CollapseAllTasks());
        } else {
          context.read<TaskNewBloc>().add(ExpandAllTasks());
        }
      },
    );
  }

  Future<void> _openTaskDetail(String id, TaskNewLoaded state) async {
    final task = state.tasks.where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<TaskNewBloc>(),
          child: TaskDetailPage(task: task),
        ),
      ),
    );
    // 从详情页返回后刷新列表
    if (mounted) {
      context.read<TaskNewBloc>().add(
        LoadTasks(
          projectId: state.selectedProjectId,
          filter: state.selectedFilter,
        ),
      );
    }
  }

  void _confirmDeleteTask(String id) {
    final currentState = context.read<TaskNewBloc>().state;
    if (currentState is! TaskNewLoaded) return;
    final task = currentState.tasks.where((t) => t.id == id).firstOrNull;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定要删除"${task?.title ?? '此任务'}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<TaskNewBloc>().add(DeleteTask(id: id));
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建项目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '项目名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      context.read<TaskNewBloc>().add(CreateProject(name: name));
    }
  }

  Future<void> _showEditProjectDialog(
    BuildContext context,
    Project project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑项目'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '项目名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      context.read<TaskNewBloc>().add(
        UpdateProject(id: project.id, name: name),
      );
    }
  }

  Future<void> _confirmDeleteProject(
    BuildContext context,
    Project project,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除项目'),
        content: Text('确定要删除"${project.name}"吗？\n该项目下的所有任务也会被删除。'),
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
    if (confirm == true) {
      Navigator.pop(context); // 关闭 Drawer
      context.read<TaskNewBloc>().add(DeleteProject(id: project.id));
    }
  }

  Future<void> _showCreateTaskSheet(BuildContext context) async {
    final repo = context.read<TaskNewBloc>().projectRepository;
    final blocState = context.read<TaskNewBloc>().state;
    final initialProjectId = blocState is TaskNewLoaded
        ? blocState.selectedProjectId
        : null;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskCreateSheet(
        initialProjectId: initialProjectId,
        projectRepository: repo,
        availableParentTasks: blocState is TaskNewLoaded
            ? blocState.tasks.where((t) => t.status == 0).toList()
            : [],
      ),
    );

    if (result != null && context.mounted) {
      context.read<TaskNewBloc>().add(
        CreateTask(
          projectId: (result['projectId'] as String?) ?? 'inbox',
          title: result['title'] as String,
          description: result['description'] as String? ?? '',
          priority: result['priority'] as int? ?? 0,
          startDate: result['startDate'] as int?,
          dueDate: result['dueDate'] as int?,
          parentId: result['parentId'] as String?,
        ),
      );
    }
  }
}
