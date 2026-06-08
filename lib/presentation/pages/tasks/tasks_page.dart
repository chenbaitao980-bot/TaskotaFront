import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/utils/snackbar_helper.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database/app_database.dart';
import '../../../services/subtask_scheduler.dart';
import '../../../services/local_storage_service.dart';
import '../../../models/node_template_payload.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/task_new/task_bloc.dart';
import '../../blocs/task_new/task_event.dart';
import '../../blocs/task_new/task_state.dart';
import '../../widgets/upgrade_dialog.dart';
import 'widgets/project_sidebar.dart';
import 'widgets/task_list_view.dart';
import 'widgets/mind_map_view.dart';
import 'node_templates_page.dart';
import 'widgets/task_create_sheet.dart';
import 'task_detail/task_detail_page.dart';
import '../../widgets/calendar_date_picker.dart';
import '../../widgets/project_picker_content.dart';

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

  /// 缓存最近一次 TaskNewLoaded，在后续 Loading/Error 时保持 UI 不闪烁
  TaskNewLoaded? _lastLoaded;

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
        if (state is TaskNewError && state.isQuotaExceeded) {
          UpgradeDialog.show(context, message: state.message);
          context.read<TaskNewBloc>().add(LoadTasks());
        }
      },
      builder: (context, state) {
        // 缓存最近一次成功加载的状态，用于在 Loading/Error 时保持 UI 不闪烁
        if (state is TaskNewLoaded) _lastLoaded = state;
        final effective = state is TaskNewLoaded ? state : _lastLoaded;

        // 真正的首次冷加载（还没有任何数据）
        if (effective == null) {
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 有历史数据时直接渲染，Loading 时在 AppBar 底部显示细线提示
        final isReloading = state is TaskNewLoading;
        _syncProjectGroupExpansion(effective.groups);
        final projectNames = <String, String>{
          for (final p in effective.projects) p.id: p.name,
        };
        final selectedFilter = effective.selectedFilter ?? 'all';

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: Text(_getTitle(effective)),
            bottom: isReloading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(2),
                    child: LinearProgressIndicator(
                      value: null,
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  )
                : null,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            actions: effective.isTemplateMode
                ? [
                    IconButton(
                      tooltip: '搜索',
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final taskId = await showSearch<String?>(
                          context: context,
                          delegate: _TaskSearchDelegate(context.read<TaskNewBloc>()),
                        );
                        if (taskId != null && context.mounted) {
                          // 清除搜索状态
                          context.read<TaskNewBloc>().add(SetSearchQuery(null));
                          final st = context.read<TaskNewBloc>().state;
                          if (st is TaskNewLoaded) {
                            _openTaskDetail(taskId, st);
                          }
                        }
                      },
                    ),
                    IconButton(
                      tooltip: '返回任务',
                      icon: const Icon(Icons.exit_to_app_rounded),
                      onPressed: () => context
                          .read<TaskNewBloc>()
                          .add(LoadTasks(filter: 'all')),
                    ),
                    _buildViewModeButton(effective),
                    _buildExpandCollapseButton(effective),
                  ]
                : [
                    IconButton(
                      tooltip: '搜索',
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final taskId = await showSearch<String?>(
                          context: context,
                          delegate: _TaskSearchDelegate(context.read<TaskNewBloc>()),
                        );
                        if (taskId != null && context.mounted) {
                          // 清除搜索状态
                          context.read<TaskNewBloc>().add(SetSearchQuery(null));
                          final st = context.read<TaskNewBloc>().state;
                          if (st is TaskNewLoaded) {
                            _openTaskDetail(taskId, st);
                          }
                        }
                      },
                    ),
                    _buildStatusFilterButton(effective),
                    // 模板节点功能暂时隐藏
                    // IconButton(
                    //   tooltip: '模板节点',
                    //   icon: const Icon(Icons.dashboard_customize_outlined),
                    //   onPressed: () => _openNodeTemplatesPage(context),
                    // ),
                    IconButton(
                      tooltip: '排除项目',
                      icon: Icon(
                        Icons.visibility_off_outlined,
                        color: _excludedProjectIds.isEmpty
                            ? null
                            : AppTheme.primaryColor,
                      ),
                      onPressed: () =>
                          _showExcludedProjectsDialog(context, effective),
                    ),
                    IconButton(
                      tooltip: '筛选项目',
                      icon: Icon(
                        Icons.folder_copy_outlined,
                        color: effective.selectedProjectIds.isEmpty
                            ? null
                            : AppTheme.primaryColor,
                      ),
                      onPressed: () =>
                          _showProjectFilterDialog(context, effective),
                    ),
                    _buildViewModeButton(effective),
                    _buildDateFilterButton(effective),
                    _buildExpandCollapseButton(effective),
                  ],
          ),
          drawer: ProjectSidebar(
            projects: effective.projects,
            groups: effective.isTemplateMode ? const [] : effective.groups,
            selectedProjectId: effective.selectedProjectId,
            selectedFilter: selectedFilter,
            isTemplateMode: effective.isTemplateMode,
            projectProgress: effective.projectProgress,
            groupProgress: effective.groupProgress,
            expandedGroupIds: _expandedProjectGroupIds,
            sortDescending: _projectSidebarSortDescending,
            onToggleGroupExpanded: _toggleProjectGroupExpanded,
            onExpandAllGroups: () => _expandAllProjectGroups(effective.groups),
            onCollapseAllGroups: _collapseAllProjectGroups,
            onToggleSortDirection: _toggleProjectSidebarSortDirection,
            onCreateGroup: () => _showCreateGroupDialog(context),
            onEditGroup: (g) => _showEditGroupDialog(context, g),
            onDeleteGroup: (g) => _confirmDeleteGroup(context, g),
            onCreateProjectInGroup: (g) => _showCreateProjectDialog(context, preselectedGroupId: g.id),
            onProjectSelected: (id) {
              Navigator.pop(context);
              context.read<TaskNewBloc>().add(LoadTasks(
                projectId: id,
                filter: effective.isTemplateMode ? 'templates' : null,
              ));
            },
            onFilterSelected: (filter) {
              Navigator.pop(context);
              context.read<TaskNewBloc>().add(LoadTasks(
                filter: filter,
                projectId: null,
                projectIds: const {},
              ));
            },
            onCreateProject: () => _showCreateProjectDialog(context),
            onEditProject: (project) =>
                _showEditProjectDialog(context, project),
            onDeleteProject: (project) =>
                _confirmDeleteProject(context, project),
          ),
          body: effective.viewMode == 'mindmap'
              ? MindMapView(
                  tasks: effective.tasks,
                  userId: _getUserId(),
                  projectNames: projectNames,
                  projects: effective.projects,
                  taskProgress: effective.taskProgress,
                  selectedFilter: selectedFilter,
                  selectedProjectId: effective.selectedProjectId,
                  focusTaskId: effective.focusTaskId,
                  focusRequestToken: effective.focusRequestToken,
                  expandedIds: effective.expandedNodes['main_tree'] ?? {},
                  onTaskTap: (id) => _openTaskDetail(id, effective),
                  onTaskToggle: (id) => _handleToggleTaskStatus(id, effective),
                  onTaskDelete: (id) => _confirmDeleteTask(id),
                  onToggleExpand: (id) => context.read<TaskNewBloc>().add(
                    ToggleTaskExpand(taskId: id),
                  ),
                  onMoveToParent: (taskId, newParentId) => _handleMoveToParent(
                    taskId,
                    newParentId,
                    effective.selectedProjectId,
                  ),
                  onAddSubtask: (parentId) =>
                      _showCreateTaskSheet(context, parentId: parentId),
                )
              : TaskListView(
                  tasks: effective.tasks,
                  projectNames: projectNames,
                  taskProgress: effective.taskProgress,
                  selectedFilter: selectedFilter,
                  selectedProjectId: effective.selectedProjectId,
                  expandedIds: effective.expandedNodes['main_tree'] ?? {},
                  onTaskTap: (id) => _openTaskDetail(id, effective),
                  onTaskToggle: (id) => _handleToggleTaskStatus(id, effective),
                  onTaskDelete: (id) => _confirmDeleteTask(id),
                  onToggleExpand: (id) => context.read<TaskNewBloc>().add(
                    ToggleTaskExpand(taskId: id),
                  ),
                  onMoveToParent: (taskId, newParentId) => _handleMoveToParent(
                    taskId,
                    newParentId,
                    effective.selectedProjectId,
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateTaskSheet(context),
            elevation: 2,
            backgroundColor: AppTheme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
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
    if (state.isTemplateMode) return '模板节点';
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

  Widget _buildStatusFilterButton(TaskNewLoaded state) {
    const filters = ['all', 'pending', 'completed'];
    final selected = state.selectedStatusFilter;
    return PopupMenuButton<String>(
      icon: Icon(
        selected == 'all'
            ? Icons.filter_alt_outlined
            : Icons.filter_alt_rounded,
        color: selected == 'all' ? null : AppTheme.primaryColor,
      ),
      tooltip: '任务状态',
      onSelected: (value) {
        context.read<TaskNewBloc>().add(
          LoadTasks(
            projectIds: state.selectedProjectIds,
            filter: state.selectedFilter,
            statusFilter: value,
            dateFrom: state.dateFrom,
            dateTo: state.dateTo,
          ),
        );
      },
      itemBuilder: (context) => filters.map((value) {
        final isSelected = value == selected;
        return PopupMenuItem<String>(
          value: value,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_rounded : Icons.circle_outlined,
                size: 18,
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              ),
              const SizedBox(width: 8),
              Text(_statusFilterLabel(value)),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _statusFilterLabel(String value) {
    switch (value) {
      case 'pending':
        return '未完成';
      case 'completed':
        return '已完成';
      default:
        return '全部';
    }
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
    final parentIdSet = state.tasks.map((t) => t.parentId).whereType<String>().toSet();
    final allParentIds = state.tasks
        .where((t) => parentIdSet.contains(t.id))
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
          statusFilter: state.selectedStatusFilter,
          dateFrom: state.dateFrom,
          dateTo: state.dateTo,
        ),
      );
    }
  }

  Future<void> _handleToggleTaskStatus(String id, TaskNewLoaded state) async {
    final task = state.tasks.where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    var cascade = false;
    if (task.status != 2) {
      final hasChildren = state.tasks.any((t) => t.parentId == id);
      if (hasChildren) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('完成子任务'),
            content: const Text('这个任务包含子任务，是否同时全部完成？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('仅完成父任务'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('全部完成'),
              ),
            ],
          ),
        );
        if (choice == null) return;
        cascade = choice;
      }
    }
    if (!mounted) return;
    context.read<TaskNewBloc>().add(
      ToggleTaskStatus(id: id, cascadeChildren: cascade),
    );
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
                    child: buildProjectPickerContent(
                      projects: state.projects,
                      groups: state.groups,
                      draft: draft,
                      setDialogState: setDialogState,
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
                    child: buildProjectPickerContent(
                      projects: availableProjects,
                      groups: state.groups,
                      draft: draft,
                      setDialogState: setDialogState,
                      extraHeader: CheckboxListTile(
                        value: draft.isEmpty,
                        title: const Text('全部项目'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (_) => setDialogState(draft.clear),
                      ),
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

  Future<void> _showCreateProjectDialog(BuildContext context, {String? preselectedGroupId}) async {
    final controller = TextEditingController();
    final taskBloc = context.read<TaskNewBloc>();
    final blocState = taskBloc.state;
    final groups = blocState is TaskNewLoaded
        ? blocState.groups
        : const <ProjectGroup>[];
    String? selectedGroupId = preselectedGroupId;
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
      final isTemplate = taskBloc.state is TaskNewLoaded &&
          (taskBloc.state as TaskNewLoaded).isTemplateMode;
      taskBloc.add(CreateProject(
        name: result.name,
        groupId: result.groupId,
        isTemplate: isTemplate,
      ));
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
        projectGroupRepository: context
            .read<TaskNewBloc>()
            .projectGroupRepository,
        taskRepository: taskRepo,
        nodeTemplateRepository: context
            .read<TaskNewBloc>()
            .nodeTemplateRepository,
        templateProjects: blocState is TaskNewLoaded
            ? blocState.templateProjects
            : const [],
        initialParentId: parentId,
        isTemplateMode: blocState is TaskNewLoaded &&
            blocState.isTemplateMode,
        availableParentTasks: blocState is TaskNewLoaded
            ? blocState.tasks.where((t) => t.status == 0).toList()
            : [],
      ),
    );

    if (result != null && context.mounted) {
      final templateProjectId = result['templateProjectId'] as String?;
      final targetProjectId = (result['projectId'] as String?) ??
          parentProjectId ??
          initialProjectId ??
          'inbox';
      final resultParentId = result['parentId'] as String?;

      if (templateProjectId != null) {
        context.read<TaskNewBloc>().add(
          ApplyTemplate(
            templateProjectId: templateProjectId,
            targetProjectId: targetProjectId,
            startTimeMillis: result['startDate'] as int? ??
                DateTime.now().millisecondsSinceEpoch,
            parentId: resultParentId,
          ),
        );
      } else {
        context.read<TaskNewBloc>().add(
          CreateTask(
            projectId: targetProjectId,
            title: result['title'] as String,
            description: result['description'] as String? ?? '',
            priority: result['priority'] as int? ?? 1,
            startDate: result['startDate'] as int?,
            dueDate: result['dueDate'] as int?,
            parentId: resultParentId,
            shiftedTasks:
                (result['shiftedTasks'] as List<ScheduledTaskShift>?) ??
                    const [],
            pendingImages:
                (result['pendingImages'] as List<PlatformFile>?) ?? const [],
            templatePayload:
                (result['templatePayload'] as NodeTemplatePayload?) ??
                    NodeTemplatePayload.empty,
            remindBeforeMinutes: result['remindBeforeMinutes'] as int? ?? 15,
            reminderEnabled: result['reminderEnabled'] as int? ?? 1,
          ),
        );
      }
    }
  }

  // 模板节点功能暂时隐藏
  // Future<void> _openNodeTemplatesPage(BuildContext context) async {
  //   final bloc = context.read<TaskNewBloc>();
  //   await Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) =>
  //           NodeTemplatesPage(repository: bloc.nodeTemplateRepository),
  //     ),
  //   );
  // }
}

/// Search delegate for searching tasks by keyword.
class _TaskSearchDelegate extends SearchDelegate<String?> {
  final TaskNewBloc bloc;
  Timer? _debounce;
  String _lastQuery = '';

  _TaskSearchDelegate(this.bloc);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          bloc.add(SetSearchQuery(null));
          showSuggestions(context);
        },
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () {
      bloc.add(SetSearchQuery(null));
      close(context, null);
    },
  );

  @override
  Widget buildSuggestions(BuildContext context) {
    // Debounce: only emit search event after 300ms of no typing
    if (query != _lastQuery) {
      _lastQuery = query;
      _debounce?.cancel();
      if (query.isEmpty) {
        bloc.add(SetSearchQuery(null));
      } else {
        _debounce = Timer(const Duration(milliseconds: 300), () {
          bloc.add(SetSearchQuery(query));
        });
      }
    }

    if (query.isEmpty) {
      return const Center(
        child: Text('输入关键字搜索任务', style: TextStyle(color: Colors.grey)),
      );
    }

    return _buildSearchResults(context);
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    return BlocBuilder<TaskNewBloc, TaskNewState>(
      bloc: bloc,
      builder: (context, state) {
        if (state is TaskNewLoaded) {
          final tasks = state.tasks;
          if (tasks.isEmpty) {
            return const Center(
              child: Text('无匹配结果', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                leading: Icon(
                  task.status == 2
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.status == 2 ? Colors.green : Colors.grey,
                  size: 20,
                ),
                title: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: task.description.isNotEmpty
                    ? Text(
                        task.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  task.status == 2 ? '已完成' : '待处理',
                  style: TextStyle(
                    fontSize: 12,
                    color: task.status == 2 ? Colors.green : Colors.orange,
                  ),
                ),
                onTap: () => close(context, task.id),
              );
            },
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
