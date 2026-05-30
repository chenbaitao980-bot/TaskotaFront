import 'package:flutter_bloc/flutter_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_group_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/checklist_repository.dart';
import '../../../domain/tasks/task_progress_calculator.dart';
import '../../../services/supabase_service.dart';
import '../../../core/utils/file_logger.dart';

class TaskNewBloc extends Bloc<TaskEvent, TaskNewState> {
  final ProjectRepository projectRepository;
  final ProjectGroupRepository? projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final SupabaseService? supabaseService;

  TaskNewBloc({
    required this.projectRepository,
    this.projectGroupRepository,
    required this.taskRepository,
    required this.checklistRepository,
    this.supabaseService,
  }) : super(TaskNewInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<CreateProject>(_onCreateProject);
    on<UpdateProject>(_onUpdateProject);
    on<DeleteProject>(_onDeleteProject);
    on<CreateProjectGroup>(_onCreateProjectGroup);
    on<UpdateProjectGroup>(_onUpdateProjectGroup);
    on<DeleteProjectGroup>(_onDeleteProjectGroup);

    on<LoadTasks>(_onLoadTasks);
    on<CreateTask>(_onCreateTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<ToggleTaskStatus>(_onToggleTaskStatus);

    on<LoadChecklistItems>(_onLoadChecklistItems);
    on<AddChecklistItem>(_onAddChecklistItem);
    on<UpdateChecklistItem>(_onUpdateChecklistItem);
    on<ToggleChecklistItem>(_onToggleChecklistItem);
    on<DeleteChecklistItem>(_onDeleteChecklistItem);
    on<SetChecklistItemObsidianUri>(_onSetChecklistItemObsidianUri);

    on<LoadSubTree>(_onLoadSubTree);
    on<AddSubTask>(_onAddSubTask);
    on<DeleteSubTask>(_onDeleteSubTask);
    on<MoveSubTask>(_onMoveSubTask);
    on<ToggleSubTask>(_onToggleSubTask);
    on<ToggleTreeNode>(_onToggleTreeNode);

    on<MoveTaskToParent>(_onMoveTaskToParent);
    on<ToggleTaskExpand>(_onToggleTaskExpand);
    on<ReorderTaskSiblings>(_onReorderTaskSiblings);
    on<ExpandAllTasks>(_onExpandAllTasks);
    on<CollapseAllTasks>(_onCollapseAllTasks);
    on<SyncFromCloud>(_onSyncFromCloud);
    on<ToggleViewMode>(_onToggleViewMode);
  }

  // --- 项目 ---

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<TaskNewState> emit,
  ) async {
    emit(TaskNewLoading());
    try {
      final projects = await projectRepository.getActive();
      final tasks = await taskRepository.getAll();
      final progress = await _calculateProgress(tasks);

      // 保留子树状态
      Map<String, List<Task>> subTrees = const {};
      Map<String, Set<String>> expandedNodes = const {};
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        subTrees = current.subTrees;
        expandedNodes = current.expandedNodes;
      }

      final groups = await (projectGroupRepository?.getAll() ?? Future.value(<ProjectGroup>[]));
      emit(
        TaskNewLoaded(
          projects: projects,
          groups: groups,
          tasks: tasks,
          subTrees: subTrees,
          expandedNodes: expandedNodes,
          taskProgress: progress.taskProgress,
          projectProgress: progress.projectProgress,
            groupProgress: progress.groupProgress,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onCreateProject(
    CreateProject event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await projectRepository.create(
        name: event.name,
        color: event.color,
        groupId: event.groupId,
      );
      final projects = await projectRepository.getActive();
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        emit(current.copyWith(projects: projects));
      } else {
        emit(TaskNewLoaded(projects: projects));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUpdateProject(
    UpdateProject event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await projectRepository.update(
        event.id,
        name: event.name,
        color: event.color,
        groupId: event.groupId,
        clearGroup: event.clearGroup,
      );
      final projects = await projectRepository.getActive();
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(projects: projects));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 项目分组 ---
  Future<void> _onCreateProjectGroup(
    CreateProjectGroup event,
    Emitter<TaskNewState> emit,
  ) async {
    if (projectGroupRepository == null) return;
    try {
      await projectGroupRepository!.create(name: event.name, color: event.color);
      final groups = await projectGroupRepository!.getAll();
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(groups: groups));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUpdateProjectGroup(
    UpdateProjectGroup event,
    Emitter<TaskNewState> emit,
  ) async {
    if (projectGroupRepository == null) return;
    try {
      await projectGroupRepository!
          .update(event.id, name: event.name, color: event.color);
      final groups = await projectGroupRepository!.getAll();
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(groups: groups));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteProjectGroup(
    DeleteProjectGroup event,
    Emitter<TaskNewState> emit,
  ) async {
    if (projectGroupRepository == null) return;
    try {
      // 可选：先删除组内所有项目（会级联删任务+同步）
      if (event.deleteProjects) {
        final all = await projectRepository.getAll();
        final inGroup = all.where((p) => p.groupId == event.id).toList();
        for (final p in inGroup) {
          if (p.id == 'inbox') continue; // 默认收件箱不可删
          await projectRepository.delete(p.id);
        }
      }
      await projectGroupRepository!.delete(event.id);
      final groups = await projectGroupRepository!.getAll();
      final projects = await projectRepository.getActive();
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(
          groups: groups,
          projects: projects,
          tasks: allTasks,
          taskProgress: progress.taskProgress,
          projectProgress: progress.projectProgress,
          groupProgress: progress.groupProgress,
        ));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteProject(
    DeleteProject event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await projectRepository.delete(event.id);
      final projects = await projectRepository.getActive();
      final tasks = await taskRepository.getAll();
      final progress = await _calculateProgress(tasks);
      if (state is TaskNewLoaded) {
        emit(
          (state as TaskNewLoaded).copyWith(
            projects: projects,
            tasks: tasks,
            taskProgress: progress.taskProgress,
            projectProgress: progress.projectProgress,
            groupProgress: progress.groupProgress,
          ),
        );
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 任务 ---

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskNewState> emit) async {
    // 在 emit loading 前先保留子树状态，避免被 loading 覆盖
    Map<String, List<Task>> preservedSubTrees = const {};
    Map<String, Set<String>> preservedExpanded = const {};
    String preservedViewMode = 'mindmap';
    int? preservedDateFrom;
    int? preservedDateTo;
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      preservedSubTrees = current.subTrees;
      preservedExpanded = current.expandedNodes;
      preservedViewMode = current.viewMode;
      preservedDateFrom = current.dateFrom;
      preservedDateTo = current.dateTo;
    }

    emit(TaskNewLoading());
    try {
      final projects = await projectRepository.getActive();
      final allTasks = await taskRepository.getAll();
      List<Task> tasks;
      if (event.filter == 'today') {
        tasks = await taskRepository.getToday();
      } else if (event.filter == 'important') {
        tasks = await taskRepository.getImportant();
      } else if (event.projectId != null) {
        tasks = await taskRepository.getByProject(event.projectId!);
      } else {
        tasks = allTasks;
      }

      // 日期区间过滤：任务的 [startDate, dueDate] 与 [dateFrom, dateTo] 有交集
      if (event.dateFrom != null && event.dateTo != null) {
        tasks = tasks.where((t) {
          final s = t.startDate ?? t.dueDate;
          final d = t.dueDate ?? t.startDate;
          if (s == null && d == null) return false;
          final taskStart = s ?? d!;
          final taskEnd = d ?? s!;
          return taskStart <= event.dateTo! && taskEnd >= event.dateFrom!;
        }).toList();
      }

      // DEBUG: 诊断子任务消失
      final allChildTasks = allTasks.where((t) => t.parentId != null).toList();
      final childTasks = tasks.where((t) => t.parentId != null).toList();
      flog('[LoadTasks] filter=${event.filter}, projectId=${event.projectId}');
      flog('[LoadTasks] allTasks总数=${allTasks.length}, allChildren=${allChildTasks.length}');
      flog('[LoadTasks] 过滤后tasks=${tasks.length}, filteredChildren=${childTasks.length}');
      for (final c in allChildTasks) {
        final inFiltered = tasks.any((t) => t.id == c.id);
        final parentInFiltered = tasks.any((t) => t.id == c.parentId);
        flog('[LoadTasks]   child: id=${c.id.substring(0, 8)}, title=${c.title}, parentId=${c.parentId?.substring(0, 8)}, projectId=${c.projectId}, deleted=${c.deleted}, inFiltered=$inFiltered, parentInFiltered=$parentInFiltered');
      }

      final progress = await _calculateProgress(allTasks);

      // 默认展开所有有子节点的任务
      final newExpanded = Map<String, Set<String>>.from(preservedExpanded);
      if (!newExpanded.containsKey('main_tree')) {
        final allParentIds = tasks
            .where((t) => tasks.any((c) => c.parentId == t.id))
            .map((t) => t.id)
            .toSet();
        newExpanded['main_tree'] = allParentIds;
      }

      final groups = await (projectGroupRepository?.getAll() ?? Future.value(<ProjectGroup>[]));
      emit(
        TaskNewLoaded(
          projects: projects,
          groups: groups,
          tasks: tasks,
          selectedProjectId: event.projectId,
          selectedFilter: event.filter ?? 'all',
          subTrees: preservedSubTrees,
          expandedNodes: newExpanded,
          taskProgress: progress.taskProgress,
          projectProgress: progress.projectProgress,
          groupProgress: progress.groupProgress,
          dateFrom: event.clearDateRange ? null : (event.dateFrom ?? preservedDateFrom),
          dateTo: event.clearDateRange ? null : (event.dateTo ?? preservedDateTo),
          viewMode: preservedViewMode,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  /// 从云端拉取任务并合并到本地数据库
  Future<void> _onSyncFromCloud(
    SyncFromCloud event,
    Emitter<TaskNewState> emit,
  ) async {
    final svc = supabaseService;
    if (svc == null) {
      print('[Sync] supabaseService 为空，跳过拉取');
      return;
    }
    try {
      final remoteJson = await svc.fetchRemoteLocalTasks();
      if (remoteJson == null || remoteJson.isEmpty) {
        print('[Sync] 云端无可同步任务');
        return;
      }
      print('[Sync] 从云端拉取 ${remoteJson.length} 条任务');
      for (final json in remoteJson) {
        await taskRepository.syncFromJson(json);
        print('[Sync] 已合并任务: ${json['id']} - ${json['title']}');
      }
      add(LoadTasks());
      print('[Sync] 同步完成');
    } catch (e) {
      print('[Sync] 拉取失败: $e');
    }
  }

  /// 将当前所有本地任务同步到 Supabase 云端
  Future<void> _syncTasksToCloud() async {
    final svc = supabaseService;
    if (svc == null) {
      print('[Sync] supabaseService 为空，跳过推送');
      return;
    }
    try {
      final allTasks = await taskRepository.getAll();
      final jsonList = allTasks.map((t) => t.toJson()).toList();
      print('[Sync] 推送 ${jsonList.length} 条任务到云端');
      await svc.syncLocalTasks(jsonList);
      print('[Sync] 推送完成');
    } catch (e) {
      print('[Sync] 推送失败: $e');
    }
  }

  Future<void> _onCreateTask(
    CreateTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      final current = state;
      final newTask = await taskRepository.create(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        priority: event.priority,
        startDate: event.startDate,
        dueDate: event.dueDate,
        parentId: event.parentId,
      );
      flog('[CreateTask] 写入完成: id=${newTask.id.substring(0, 8)}, title=${newTask.title}, parentId=${newTask.parentId?.substring(0, 8)}, projectId=${newTask.projectId}');
      // 回读验证
      final verify = await taskRepository.get(newTask.id);
      if (verify == null) {
        flog('[CreateTask] ⚠️ 回读验证失败！任务 ${newTask.id.substring(0, 8)} 写入后查不到');
      } else {
        flog('[CreateTask] 回读验证OK: parentId=${verify.parentId?.substring(0, 8)}, deleted=${verify.deleted}');
      }
      await _syncTasksToCloud();
      // syncTasksToCloud 后再次验证
      final verify2 = await taskRepository.get(newTask.id);
      if (verify2 == null) {
        flog('[CreateTask] ⚠️ syncTasksToCloud后任务消失！id=${newTask.id.substring(0, 8)}');
      } else if (verify2.parentId != newTask.parentId) {
        flog('[CreateTask] ⚠️ syncTasksToCloud后parentId变化！${newTask.parentId?.substring(0, 8)} → ${verify2.parentId?.substring(0, 8)}');
      }
      if (current is TaskNewLoaded) {
        add(LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ));
      } else {
        add(LoadTasks());
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(
    UpdateTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.update(
        event.id,
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        priority: event.priority,
        startDate: event.startDate,
        dueDate: event.dueDate,
        remindBeforeMinutes: event.remindBeforeMinutes,
        reminderEnabled: event.reminderEnabled,
      );
      await _syncTasksToCloud();
      final current = state as TaskNewLoaded;
      add(
        LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(
    DeleteTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.delete(event.id);
      await _syncTasksToCloud();
      final current = state as TaskNewLoaded;
      add(
        LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleTaskStatus(
    ToggleTaskStatus event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.toggleStatus(event.id);
      await _syncTasksToCloud();
      final current = state as TaskNewLoaded;
      add(
        LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 检查项 ---

  Future<void> _onLoadChecklistItems(
    LoadChecklistItems event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      final items = await checklistRepository.getByTask(event.taskId);
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newMap = Map<String, List<ChecklistItem>>.from(
          current.checklistItems,
        );
        newMap[event.taskId] = items;
        emit(
          current.copyWith(
            checklistItems: newMap,
            taskProgress: progress.taskProgress,
            projectProgress: progress.projectProgress,
            groupProgress: progress.groupProgress,
          ),
        );
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onAddChecklistItem(
    AddChecklistItem event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.create(
        taskId: event.taskId,
        title: event.title,
      );
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUpdateChecklistItem(
    UpdateChecklistItem event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.update(event.id, title: event.title);
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleChecklistItem(
    ToggleChecklistItem event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.toggleStatus(event.id);
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteChecklistItem(
    DeleteChecklistItem event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.delete(event.id);
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onSetChecklistItemObsidianUri(
    SetChecklistItemObsidianUri event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.setObsidianUri(event.id, event.obsidianUri);
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 子任务树 ---

  Future<void> _onLoadSubTree(
    LoadSubTree event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      final descendants = await taskRepository.getDescendants(event.rootTaskId);
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newTrees = Map<String, List<Task>>.from(current.subTrees);
        newTrees[event.rootTaskId] = descendants;

        final directChildren = descendants
            .where((t) => t.parentId == event.rootTaskId)
            .toList();
        final newExpanded = Map<String, Set<String>>.from(
          current.expandedNodes,
        );
        newExpanded[event.rootTaskId] = {for (final c in directChildren) c.id};

        emit(
          current.copyWith(
            subTrees: newTrees,
            expandedNodes: newExpanded,
            taskProgress: progress.taskProgress,
            projectProgress: progress.projectProgress,
            groupProgress: progress.groupProgress,
          ),
        );
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onAddSubTask(
    AddSubTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.create(
        projectId: event.projectId,
        title: event.title,
        parentId: event.parentId,
      );
      add(LoadSubTree(rootTaskId: _findRootId(event.parentId)));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteSubTask(
    DeleteSubTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.delete(event.taskId);
      final descendants = await taskRepository.getDescendants(event.rootTaskId);
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newTrees = Map<String, List<Task>>.from(current.subTrees);
        newTrees[event.rootTaskId] = descendants;
        emit(
          current.copyWith(
            subTrees: newTrees,
            taskProgress: progress.taskProgress,
            projectProgress: progress.projectProgress,
            groupProgress: progress.groupProgress,
          ),
        );
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onMoveSubTask(
    MoveSubTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.moveTask(event.taskId, event.newParentId);
      add(LoadSubTree(rootTaskId: event.rootTaskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleSubTask(
    ToggleSubTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.toggleStatus(event.id);
      add(LoadSubTree(rootTaskId: event.rootTaskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleTreeNode(
    ToggleTreeNode event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newExpanded = Map<String, Set<String>>.from(current.expandedNodes);
      final nodes = Set<String>.from(newExpanded[event.rootTaskId] ?? {});
      if (nodes.contains(event.nodeId)) {
        nodes.remove(event.nodeId);
      } else {
        nodes.add(event.nodeId);
      }
      newExpanded[event.rootTaskId] = nodes;
      emit(current.copyWith(expandedNodes: newExpanded));
    }
  }

  /// 从任意节点 ID 递归找到根节点 ID
  String _findRootId(String taskId) {
    if (state is TaskNewLoaded) {
      final loaded = state as TaskNewLoaded;
      for (final entry in loaded.subTrees.entries) {
        if (entry.key == taskId || entry.value.any((t) => t.id == taskId)) {
          for (final rootKey in loaded.subTrees.keys) {
            if (rootKey == taskId) return rootKey;
            final tree = loaded.subTrees[rootKey] ?? [];
            if (tree.any((t) => t.id == taskId)) return rootKey;
          }
        }
      }
    }
    return taskId;
  }

  Future<TaskProgressSnapshot> _calculateProgress(List<Task> allTasks) async {
    final checklistItems = await checklistRepository.getByTaskIds(
      allTasks.map((task) => task.id).toList(),
    );
    final projects = await projectRepository.getAll();
    return TaskProgressCalculator.calculate(
      tasks: allTasks,
      checklistItems: checklistItems,
      projects: projects,
    );
  }

  // --- 树形拖拽 ---

  Future<void> _onMoveTaskToParent(
    MoveTaskToParent event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      // 循环检测：不能将任务移到自己的后代下
      if (event.newParentId != null && state is TaskNewLoaded) {
        final tasks = (state as TaskNewLoaded).tasks;
        if (_isDescendantOf(event.taskId, event.newParentId!, tasks)) {
          return; // 会形成循环，忽略操作
        }
      }
      await taskRepository.moveTask(event.taskId, event.newParentId);
      final current = state as TaskNewLoaded;
      add(
        LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  /// 检查 targetId 是否是 ancestorId 的后代
  bool _isDescendantOf(String ancestorId, String targetId, List<Task> tasks) {
    String? current = targetId;
    final visited = <String>{};
    while (current != null && visited.add(current)) {
      if (current == ancestorId) return true;
      final task = tasks.where((t) => t.id == current).firstOrNull;
      current = task?.parentId;
    }
    return false;
  }

  Future<void> _onToggleTaskExpand(
    ToggleTaskExpand event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newExpanded = Map<String, Set<String>>.from(current.expandedNodes);
      final mainTree = Set<String>.from(newExpanded['main_tree'] ?? {});
      if (mainTree.contains(event.taskId)) {
        mainTree.remove(event.taskId);
      } else {
        mainTree.add(event.taskId);
      }
      newExpanded['main_tree'] = mainTree;
      emit(current.copyWith(expandedNodes: newExpanded));
    }
  }

  Future<void> _onReorderTaskSiblings(
    ReorderTaskSiblings event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.reorderSubTasks(event.parentId, event.orderedIds);
      final current = state as TaskNewLoaded;
      add(
        LoadTasks(
          projectId: current.selectedProjectId,
          filter: current.selectedFilter,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onExpandAllTasks(
    ExpandAllTasks event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newExpanded = Map<String, Set<String>>.from(current.expandedNodes);
      final allParentIds = current.tasks
          .where((t) => current.tasks.any((c) => c.parentId == t.id))
          .map((t) => t.id)
          .toSet();
      newExpanded['main_tree'] = allParentIds;
      emit(current.copyWith(expandedNodes: newExpanded));
    }
  }

  Future<void> _onCollapseAllTasks(
    CollapseAllTasks event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newExpanded = Map<String, Set<String>>.from(current.expandedNodes);
      newExpanded['main_tree'] = <String>{};
      emit(current.copyWith(expandedNodes: newExpanded));
    }
  }

  void _onToggleViewMode(
    ToggleViewMode event,
    Emitter<TaskNewState> emit,
  ) {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newMode = current.viewMode == 'mindmap' ? 'list' : 'mindmap';
      emit(current.copyWith(viewMode: newMode));
    }
  }
}
