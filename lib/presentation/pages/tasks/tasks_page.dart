import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../services/subtask_scheduler.dart';
import '../../../services/local_storage_service.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import 'widgets/project_sidebar.dart';
import 'widgets/task_list_view.dart';
import 'widgets/mind_map_view.dart';
import 'widgets/task_create_sheet.dart';
import 'task_detail/task_detail_page.dart';
import '../../widgets/calendar_date_picker.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _storage = LocalStorageService();
  Set<String> _excludedProjectIds = {};
  Set<String> _expandedProjectGroupIds = {};
  Set<String> _knownProjectGroupIds = {};
  bool _projectSidebarSortDescending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjectSidebarPrefs();
      context.read<TaskNewBloc>().add(LoadTasks());
    });
  }

  Future<void> _loadProjectSidebarPrefs() async {
    await _storage.init();
    if (!mounted) return;
    setState(() {
      _excludedProjectIds = _storage.excludedProjectIds;
      _projectSidebarSortDescending = _storage.projectSidebarTimeSortDesc;
    });
  }

  void _syncProjectGroupExpansion(List<ProjectGroup> groups) {
    final groupIds = groups.map((g) => g.id).toSet();
    final addedGroupIds = groupIds.difference(_knownProjectGroupIds);
    final removedGroupIds = _knownProjectGroupIds.difference(groupIds);
    if (addedGroupIds.isEmpty && removedGroupIds.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _knownProjectGroupIds = groupIds;
        _expandedProjectGroupIds = {
          ..._expandedProjectGroupIds.difference(removedGroupIds),
          ...addedGroupIds,
        };
      });
    });
  }

  void _toggleProjectGroupExpanded(String groupId, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedProjectGroupIds = {..._expandedProjectGroupIds, groupId};
      } else {
        _expandedProjectGroupIds = {..._expandedProjectGroupIds}
          ..remove(groupId);
      }
    });
  }

  void _expandAllProjectGroups(List<ProjectGroup> groups) {
    setState(() {
      _expandedProjectGroupIds = groups.map((g) => g.id).toSet();
      _knownProjectGroupIds = _expandedProjectGroupIds;
    });
  }

  void _collapseAllProjectGroups() {
    setState(() => _expandedProjectGroupIds = {});
  }

  Future<void> _toggleProjectSidebarSortDirection() async {
    final next = !_projectSidebarSortDescending;
    setState(() => _projectSidebarSortDescending = next);
    await _storage.init();
    await _storage.setProjectSidebarTimeSortDesc(next);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskNewBloc, TaskNewState>(
      listener: (context, state) {
        if (state is TaskNewLoaded && state.syncRollbackMessage != null) {
          showAppSnackBar(context, state.syncRollbackMessage!);
        }
      },
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
                  Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                  const SizedBox(height: 16),
                  Text(
                    '加载失败：${state.message}',
                    style: TextStyle(color: AppTheme.error),
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
          _syncProjectGroupExpansion(state.groups);
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
                IconButton(
                  tooltip: '排除项目',
                  icon: Icon(
                    Icons.visibility_off_outlined,
                    color: _excludedProjectIds.isEmpty
                        ? null
                        : AppTheme.primaryColor,
                  ),
                  onPressed: () => _showExcludedProjectsDialog(context, state),
                ),
                IconButton(
                  tooltip: '筛选项目',
                  icon: Icon(
                    Icons.folder_copy_outlined,
                    color: state.selectedProjectIds.isEmpty
                        ? null
                        : AppTheme.primaryColor,
                  ),
                  onPressed: () => _showProjectFilterDialog(context, state),
                ),
                _buildViewModeButton(state),
                _buildDateFilterButton(state),
                _buildExpandCollapseButton(state),
              ],
            ),
            drawer: ProjectSidebar(
              projects: state.projects,
              groups: state.groups,
              selectedProjectId: state.selectedProjectId,
              selectedFilter: selectedFilter,
              projectProgress: state.projectProgress,
              groupProgress: state.groupProgress,
              expandedGroupIds: _expandedProjectGroupIds,
              sortDescending: _projectSidebarSortDescending,
              onToggleGroupExpanded: _toggleProjectGroupExpanded,
              onExpandAllGroups: () => _expandAllProjectGroups(state.groups),
              onCollapseAllGroups: _collapseAllProjectGroups,
              onToggleSortDirection: _toggleProjectSidebarSortDirection,
              onCreateGroup: () => _showCreateGroupDialog(context),
              onEditGroup: (g) => _showEditGroupDialog(context, g),
              onDeleteGroup: (g) => _confirmDeleteGroup(context, g),
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
            body: state.viewMode == 'mindmap'
                ? MindMapView(
                    tasks: state.tasks,
                    userId: _getUserId(),
                    projectNames: projectNames,
                    projects: state.projects,
                    taskProgress: state.taskProgress,
                    selectedFilter: selectedFilter,
                    selectedProjectId: state.selectedProjectId,
                    focusTaskId: state.focusTaskId,
                    focusRequestToken: state.focusRequestToken,
                    expandedIds: state.expandedNodes['main_tree'] ?? {},
                    onTaskTap: (id) => _openTaskDetail(id, state),
                    onTaskToggle: (id) => context.read<TaskNewBloc>().add(
                      ToggleTaskStatus(id: id),
                    ),
                    onTaskDelete: (id) => _confirmDeleteTask(id),
                    onToggleExpand: (id) => context.read<TaskNewBloc>().add(
                      ToggleTaskExpand(taskId: id),
                    ),
                    onMoveToParent: (taskId, newParentId) =>
                        _handleMoveToParent(
                          taskId,
                          newParentId,
                          state.selectedProjectId,
                        ),
                    onAddSubtask: (parentId) =>
                        _showCreateTaskSheet(context, parentId: parentId),
                  )
                : TaskListView(
                    tasks: state.tasks,
                    projectNames: projectNames,
                    taskProgress: state.taskProgress,
                    selectedFilter: selectedFilter,
                    selectedProjectId: state.selectedProjectId,
                    expandedIds: state.expandedNodes['main_tree'] ?? {},
                    onTaskTap: (id) => _openTaskDetail(id, state),
                    onTaskToggle: (id) => context.read<TaskNewBloc>().add(
                      ToggleTaskStatus(id: id),
                    ),
                    onTaskDelete: (id) => _confirmDeleteTask(id),
                    onToggleExpand: (id) => context.read<TaskNewBloc>().add(
                      ToggleTaskExpand(taskId: id),
                    ),
                    onMoveToParent: (taskId, newParentId) =>
                        _handleMoveToParent(
                          taskId,
                          newParentId,
                          state.selectedProjectId,
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

  String _getUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) return authState.user.id;
    if (authState is LocalAuthenticated) return 'local_${authState.email}';
    return 'anonymous';
  }

  String _getTitle(TaskNewLoaded state) {
    if (state.selectedFilter == 'today') return '今天';
    if (state.selectedFilter == 'important') return '重要';
    if (state.selectedProjectIds.length > 1) {
      return '${state.selectedProjectIds.length} 个项目';
    }
    if (state.selectedProjectId != null) {
      final project = state.projects
          .where((p) => p.id == state.selectedProjectId)
          .firstOrNull;
      return project?.name ?? '任务';
    }
    return '所有任务';
  }

  Widget _buildViewModeButton(TaskNewLoaded state) {
    final isMindMap = state.viewMode == 'mindmap';
    return IconButton(
      icon: Icon(isMindMap ? Icons.account_tree_rounded : Icons.list_rounded),
      tooltip: isMindMap ? '切换到列表' : '切换到思维导图',
      onPressed: () {
        context.read<TaskNewBloc>().add(ToggleViewMode());
      },
    );
  }

  Widget _buildDateFilterButton(TaskNewLoaded state) {
    final hasFilter = state.dateFrom != null && state.dateTo != null;
    return IconButton(
      icon: Icon(
        hasFilter ? Icons.date_range : Icons.date_range_outlined,
        color: hasFilter ? AppTheme.primaryColor : null,
      ),
      tooltip: hasFilter ? '清除日期筛选' : '按日期筛选',
      onPressed: () async {
        if (hasFilter) {
          context.read<TaskNewBloc>().add(
            LoadTasks(
              projectIds: state.selectedProjectIds,
              filter: state.selectedFilter,
              clearDateRange: true,
            ),
          );
          return;
        }
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: now.subtract(const Duration(days: 365)),
          lastDate: now.add(const Duration(days: 365)),
          initialDateRange: DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
          locale: const Locale('zh', 'CN'),
        );
        if (picked != null && mounted) {
          final from = DateTime(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          );
          final to = DateTime(
            picked.end.year,
            picked.end.month,
            picked.end.day,
            23,
            59,
            59,
          );
          context.read<TaskNewBloc>().add(
            LoadTasks(
              projectIds: state.selectedProjectIds,
              filter: state.selectedFilter,
              dateFrom: from.millisecondsSinceEpoch,
              dateTo: to.millisecondsSinceEpoch,
            ),
          );
        }
      },
    );
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
          projectIds: state.selectedProjectIds,
          filter: state.selectedFilter,
        ),
      );
    }
  }

  Future<void> _showExcludedProjectsDialog(
    BuildContext context,
    TaskNewLoaded state,
  ) async {
    final draft = Set<String>.from(_excludedProjectIds);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('排除项目'),
          content: SizedBox(
            width: 360,
            child: state.projects.isEmpty
                ? const Text('暂无项目')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final project in state.projects)
                          CheckboxListTile(
                            value: draft.contains(project.id),
                            title: Text(project.name),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  draft.add(project.id);
                                } else {
                                  draft.remove(project.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('清空'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _storage.init();
    await _storage.setExcludedProjectIds(result);
    if (!mounted) return;
    setState(() => _excludedProjectIds = result);
    context.read<TaskNewBloc>().add(
      LoadTasks(
        projectIds: state.selectedProjectIds.difference(result),
        filter: state.selectedFilter,
      ),
    );
  }

  Future<void> _showProjectFilterDialog(
    BuildContext context,
    TaskNewLoaded state,
  ) async {
    final draft = Set<String>.from(state.selectedProjectIds);
    final availableProjects = state.projects
        .where((project) => !_excludedProjectIds.contains(project.id))
        .toList();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('筛选项目'),
          content: SizedBox(
            width: 360,
            child: availableProjects.isEmpty
                ? const Text('暂无可筛选项目')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CheckboxListTile(
                          value: draft.isEmpty,
                          title: const Text('全部项目'),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (_) => setDialogState(draft.clear),
                        ),
                        for (final project in availableProjects)
                          CheckboxListTile(
                            value: draft.contains(project.id),
                            title: Text(project.name),
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  draft.add(project.id);
                                } else {
                                  draft.remove(project.id);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, <String>{}),
              child: const Text('清空'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, draft),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    context.read<TaskNewBloc>().add(
      LoadTasks(projectIds: result, filter: state.selectedFilter),
    );
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
              Navigator.pop(context);
              _doDeleteAndCheckParent(id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 删除任务并检查其父节点是否因此变为叶节点，若是则提示修改时间。
  Future<void> _doDeleteAndCheckParent(String id) async {
    final s = context.read<TaskNewBloc>().state;
    if (s is! TaskNewLoaded) {
      context.read<TaskNewBloc>().add(DeleteTask(id: id));
      return;
    }
    final child = s.tasks.where((t) => t.id == id).firstOrNull;
    final parentId = child?.parentId;
    Task? parentTask;
    if (parentId != null) {
      final remainingSiblings = s.tasks
          .where((t) => t.parentId == parentId && t.id != id)
          .toList();
      if (remainingSiblings.isEmpty) {
        parentTask = s.tasks.where((t) => t.id == parentId).firstOrNull;
      }
    }
    context.read<TaskNewBloc>().add(DeleteTask(id: id));
    if (parentTask != null && mounted) {
      await _promptParentTimeEdit(parentTask);
    }
  }

  /// 移动/断开子任务并检查旧父节点是否因此变为叶节点，若是则提示修改时间。
  Future<void> _handleMoveToParent(
    String taskId,
    String? newParentId,
    String? projectId,
  ) async {
    final s = context.read<TaskNewBloc>().state;
    Task? oldParentTask;
    if (newParentId == null && s is TaskNewLoaded) {
      // 断开连接：检查旧父节点是否变为叶节点
      final child = s.tasks.where((t) => t.id == taskId).firstOrNull;
      final oldParentId = child?.parentId;
      if (oldParentId != null) {
        final remaining = s.tasks
            .where((t) => t.parentId == oldParentId && t.id != taskId)
            .toList();
        if (remaining.isEmpty) {
          oldParentTask = s.tasks.where((t) => t.id == oldParentId).firstOrNull;
        }
      }
    }
    context.read<TaskNewBloc>().add(
      MoveTaskToParent(
        taskId: taskId,
        newParentId: newParentId,
        projectId: projectId,
      ),
    );
    if (oldParentTask != null && mounted) {
      await _promptParentTimeEdit(oldParentTask);
    }
  }

  /// 弹出提示：父节点已无子任务，询问是否修改其时间范围。
  Future<void> _promptParentTimeEdit(Task parent) async {
    if (!mounted) return;
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('父节点已无子任务'),
        content: Text('「${parent.title}」的子任务已全部移除，是否修改其时间范围？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('跳过'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('修改时间'),
          ),
        ],
      ),
    );
    if (shouldEdit == true && mounted) {
      await _editParentTime(parent);
    }
  }

  /// 弹出开始/结束时间选择框，直接更新父任务时间。
  Future<void> _editParentTime(Task parent) async {
    if (!mounted) return;
    final now = DateTime.now();
    DateTime startDate = parent.startDate != null
        ? DateTime.fromMillisecondsSinceEpoch(parent.startDate!)
        : now;
    DateTime dueDate = parent.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(parent.dueDate!)
        : now.add(const Duration(hours: 1));

    // 用 StatefulBuilder 在 AlertDialog 内显示当前选中值并可二次修改
    final result = await showDialog<({DateTime start, DateTime due})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String fmt(DateTime d) {
            final today = DateTime(now.year, now.month, now.day);
            final target = DateTime(d.year, d.month, d.day);
            final time =
                '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
            if (target == today) return '今天 $time';
            if (target == today.add(const Duration(days: 1))) return '明天 $time';
            return '${d.month}/${d.day} $time';
          }

          return AlertDialog(
            title: Text('修改「${parent.title}」时间'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.play_arrow_rounded, size: 18),
                  title: const Text('开始时间', style: TextStyle(fontSize: 13)),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showCalendarDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 2)),
                        title: '选择开始时间',
                      );
                      if (picked != null) setLocal(() => startDate = picked);
                    },
                    child: Text(
                      fmt(startDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.stop_rounded, size: 18),
                  title: const Text('结束时间', style: TextStyle(fontSize: 13)),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showCalendarDatePicker(
                        context: ctx,
                        initialDate: dueDate,
                        firstDate: now.subtract(const Duration(days: 365)),
                        lastDate: now.add(const Duration(days: 365 * 2)),
                        title: '选择结束时间',
                      );
                      if (picked != null) setLocal(() => dueDate = picked);
                    },
                    child: Text(
                      fmt(dueDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(ctx, (start: startDate, due: dueDate)),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && mounted) {
      context.read<TaskNewBloc>().add(
        UpdateTask(
          id: parent.id,
          startDate: result.start.millisecondsSinceEpoch,
          dueDate: result.due.millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> _showCreateProjectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final taskBloc = context.read<TaskNewBloc>();
    final blocState = taskBloc.state;
    final groups = blocState is TaskNewLoaded
        ? blocState.groups
        : const <ProjectGroup>[];
    String? selectedGroupId;
    final result = await showDialog<({String name, String? groupId})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('新建项目'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: '项目名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: selectedGroupId,
                  decoration: const InputDecoration(
                    labelText: '所属分组（可选）',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('无分组'),
                    ),
                    ...groups.map(
                      (g) => DropdownMenuItem<String?>(
                        value: g.id,
                        child: Text(g.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => selectedGroupId = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final n = controller.text.trim();
                  if (n.isEmpty) return;
                  Navigator.pop(context, (name: n, groupId: selectedGroupId));
                },
                child: const Text('创建'),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) {
      final groupId = result.groupId;
      if (groupId != null) {
        setState(() {
          _expandedProjectGroupIds = {..._expandedProjectGroupIds, groupId};
          _knownProjectGroupIds = {..._knownProjectGroupIds, groupId};
        });
      }
      taskBloc.add(CreateProject(name: result.name, groupId: result.groupId));
    }
  }

  Future<void> _showEditProjectDialog(
    BuildContext context,
    Project project,
  ) async {
    final controller = TextEditingController(text: project.name);
    final blocState = context.read<TaskNewBloc>().state;
    final groups = blocState is TaskNewLoaded
        ? blocState.groups
        : const <ProjectGroup>[];
    String? selectedGroupId = project.groupId;
    final result =
        await showDialog<({String name, String? groupId, bool clearGroup})>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: const Text('编辑项目'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '项目名称',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: '所属分组（可选）',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('无分组'),
                        ),
                        ...groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g.id,
                            child: Text(g.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setLocal(() => selectedGroupId = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      final n = controller.text.trim();
                      if (n.isEmpty) return;
                      Navigator.pop(context, (
                        name: n,
                        groupId: selectedGroupId,
                        clearGroup: selectedGroupId == null,
                      ));
                    },
                    child: const Text('保存'),
                  ),
                ],
              );
            },
          ),
        );
    if (result != null) {
      context.read<TaskNewBloc>().add(
        UpdateProject(
          id: project.id,
          name: result.name,
          groupId: result.groupId,
          clearGroup: result.clearGroup,
        ),
      );
    }
  }

  // ──────── 分组 CRUD ────────
  Future<void> _showCreateGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '分组名称',
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
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<TaskNewBloc>().add(CreateProjectGroup(name: name));
    }
  }

  Future<void> _showEditGroupDialog(
    BuildContext context,
    ProjectGroup group,
  ) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
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
    if (name != null && name.isNotEmpty && context.mounted) {
      context.read<TaskNewBloc>().add(
        UpdateProjectGroup(id: group.id, name: name),
      );
    }
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    ProjectGroup group,
  ) async {
    bool deleteProjects = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('删除分组'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('确定删除分组"${group.name}"？'),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: deleteProjects,
                  onChanged: (v) => setLocal(() => deleteProjects = v ?? false),
                  title: const Text(
                    '同时删除该分组下的所有项目和任务',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '不勾选则项目变为"未分组"',
                    style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                child: Text(deleteProjects ? '删除分组和项目' : '删除分组'),
              ),
            ],
          );
        },
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<TaskNewBloc>().add(
        DeleteProjectGroup(id: group.id, deleteProjects: deleteProjects),
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
      context.read<TaskNewBloc>().add(DeleteProject(id: project.id));
    }
  }

  Future<void> _showCreateTaskSheet(
    BuildContext context, {
    String? parentId,
  }) async {
    final repo = context.read<TaskNewBloc>().projectRepository;
    final blocState = context.read<TaskNewBloc>().state;
    final parentProjectId = blocState is TaskNewLoaded && parentId != null
        ? blocState.tasks
              .where((task) => task.id == parentId)
              .firstOrNull
              ?.projectId
        : null;
    final initialProjectId =
        parentProjectId ??
        (blocState is TaskNewLoaded ? blocState.selectedProjectId : null);

    final taskRepo = context.read<TaskNewBloc>().taskRepository;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskCreateSheet(
        initialProjectId: initialProjectId,
        projectRepository: repo,
        taskRepository: taskRepo,
        initialParentId: parentId,
        availableParentTasks: blocState is TaskNewLoaded
            ? blocState.tasks.where((t) => t.status == 0).toList()
            : [],
      ),
    );

    if (result != null && context.mounted) {
      final resultParentId = result['parentId'] as String?;
      context.read<TaskNewBloc>().add(
        CreateTask(
          projectId:
              (result['projectId'] as String?) ??
              parentProjectId ??
              initialProjectId ??
              'inbox',
          title: result['title'] as String,
          description: result['description'] as String? ?? '',
          priority: result['priority'] as int? ?? 1,
          startDate: result['startDate'] as int?,
          dueDate: result['dueDate'] as int?,
          parentId: resultParentId,
          shiftedTasks:
              (result['shiftedTasks'] as List<ScheduledTaskShift>?) ?? const [],
        ),
      );
      if (resultParentId != null) {
        final currentState = context.read<TaskNewBloc>().state;
        if (currentState is TaskNewLoaded) {
          final expanded = currentState.expandedNodes['main_tree'] ?? {};
          if (!expanded.contains(resultParentId)) {
            context.read<TaskNewBloc>().add(
              ToggleTaskExpand(taskId: resultParentId),
            );
          }
        }
      }
    }
  }
}
