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
import '../../../services/local_storage_service.dart';
import '../../../services/task_sync_service.dart';

class TaskNewBloc extends Bloc<TaskEvent, TaskNewState> {
  final ProjectRepository projectRepository;
  final ProjectGroupRepository? projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final SupabaseService? supabaseService;
  final LocalStorageService _storage = LocalStorageService();

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

  // --- 椤圭洰 ---

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<TaskNewState> emit,
  ) async {
    emit(TaskNewLoading());
    try {
      final projects = await projectRepository.getActive();
      final tasks = await taskRepository.getAll();
      final progress = await _calculateProgress(tasks);

      // 淇濈暀瀛愭爲鐘舵€?
      Map<String, List<Task>> subTrees = const {};
      Map<String, Set<String>> expandedNodes = const {};
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        subTrees = current.subTrees;
        expandedNodes = current.expandedNodes;
      }

      final groups =
          await (projectGroupRepository?.getAll() ??
              Future.value(<ProjectGroup>[]));
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

  // --- 椤圭洰鍒嗙粍 ---
  Future<void> _onCreateProjectGroup(
    CreateProjectGroup event,
    Emitter<TaskNewState> emit,
  ) async {
    if (projectGroupRepository == null) return;
    try {
      await projectGroupRepository!.create(
        name: event.name,
        color: event.color,
      );
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
      await projectGroupRepository!.update(
        event.id,
        name: event.name,
        color: event.color,
      );
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
      // 鍙€夛細鍏堝垹闄ょ粍鍐呮墍鏈夐」鐩紙浼氱骇鑱斿垹浠诲姟+鍚屾锛?
      if (event.deleteProjects) {
        final all = await projectRepository.getAll();
        final inGroup = all.where((p) => p.groupId == event.id).toList();
        for (final p in inGroup) {
          if (p.id == 'inbox') continue; // 榛樿鏀朵欢绠变笉鍙垹
          await projectRepository.delete(p.id);
        }
      }
      await projectGroupRepository!.delete(event.id);
      final groups = await projectGroupRepository!.getAll();
      final projects = await projectRepository.getActive();
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);
      if (state is TaskNewLoaded) {
        emit(
          (state as TaskNewLoaded).copyWith(
            groups: groups,
            projects: projects,
            tasks: allTasks,
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

  // --- 浠诲姟 ---

  Future<void> _onLoadTasks(LoadTasks event, Emitter<TaskNewState> emit) async {
    // 鍦?emit loading 鍓嶅厛淇濈暀瀛愭爲鐘舵€侊紝閬垮厤琚?loading 瑕嗙洊
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
      await _storage.init();
      final excludedProjectIds = _storage.excludedProjectIds;
      final allTasks = (await taskRepository.getAll())
          .where((t) => !excludedProjectIds.contains(t.projectId))
          .toList();
      final selectedProjectIds = event.projectIds
          .where((id) => !excludedProjectIds.contains(id))
          .toSet();
      List<Task> tasks;
      if (event.filter == 'today') {
        tasks = (await taskRepository.getToday())
            .where((t) => !excludedProjectIds.contains(t.projectId))
            .toList();
      } else if (event.filter == 'important') {
        tasks = (await taskRepository.getImportant())
            .where((t) => !excludedProjectIds.contains(t.projectId))
            .toList();
      } else if (selectedProjectIds.isNotEmpty) {
        tasks = allTasks
            .where((t) => selectedProjectIds.contains(t.projectId))
            .toList();
      } else {
        tasks = allTasks;
      }

      // 鏃ユ湡鍖洪棿杩囨护锛氫换鍔＄殑 [startDate, dueDate] 涓?[dateFrom, dateTo] 鏈変氦闆?
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

      // DEBUG: 璇婃柇瀛愪换鍔℃秷澶?
      final allChildTasks = allTasks.where((t) => t.parentId != null).toList();
      final childTasks = tasks.where((t) => t.parentId != null).toList();
      flog(
        '[LoadTasks] filter=${event.filter}, projectIds=$selectedProjectIds',
      );
      flog(
        '[LoadTasks] allTasks鎬绘暟=${allTasks.length}, allChildren=${allChildTasks.length}',
      );
      flog(
        '[LoadTasks] 杩囨护鍚巘asks=${tasks.length}, filteredChildren=${childTasks.length}',
      );
      for (final c in allChildTasks) {
        final inFiltered = tasks.any((t) => t.id == c.id);
        final parentInFiltered = tasks.any((t) => t.id == c.parentId);
        flog(
          '[LoadTasks]   child: id=${c.id.substring(0, 8)}, title=${c.title}, parentId=${c.parentId?.substring(0, 8)}, projectId=${c.projectId}, deleted=${c.deleted}, inFiltered=$inFiltered, parentInFiltered=$parentInFiltered',
        );
      }

      final progress = await _calculateProgress(allTasks);

      // 榛樿灞曞紑鎵€鏈夋湁瀛愯妭鐐圭殑浠诲姟
      final newExpanded = Map<String, Set<String>>.from(preservedExpanded);
      if (!newExpanded.containsKey('main_tree')) {
        final allParentIds = tasks
            .where((t) => tasks.any((c) => c.parentId == t.id))
            .map((t) => t.id)
            .toSet();
        newExpanded['main_tree'] = allParentIds;
      }
      if (event.focusTaskId != null) {
        final mainTree = Set<String>.from(newExpanded['main_tree'] ?? {});
        mainTree.addAll(_ancestorIds(event.focusTaskId!, allTasks));
        newExpanded['main_tree'] = mainTree;
      }

      final groups =
          await (projectGroupRepository?.getAll() ??
              Future.value(<ProjectGroup>[]));
      emit(
        TaskNewLoaded(
          projects: projects,
          groups: groups,
          tasks: tasks,
          selectedProjectIds: selectedProjectIds,
          selectedFilter: event.filter ?? 'all',
          subTrees: preservedSubTrees,
          expandedNodes: newExpanded,
          taskProgress: progress.taskProgress,
          projectProgress: progress.projectProgress,
          groupProgress: progress.groupProgress,
          dateFrom: event.clearDateRange
              ? null
              : (event.dateFrom ?? preservedDateFrom),
          dateTo: event.clearDateRange
              ? null
              : (event.dateTo ?? preservedDateTo),
          viewMode: event.focusTaskId != null ? 'mindmap' : preservedViewMode,
          focusTaskId: event.focusTaskId,
          focusRequestToken: event.focusRequestToken,
        ),
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Set<String> _ancestorIds(String taskId, List<Task> tasks) {
    final byId = {for (final task in tasks) task.id: task};
    final ancestors = <String>{};
    String? parentId = byId[taskId]?.parentId;
    while (parentId != null && ancestors.add(parentId)) {
      parentId = byId[parentId]?.parentId;
    }
    return ancestors;
  }

  /// 浠庝簯绔媺鍙栦换鍔″苟鍚堝苟鍒版湰鍦版暟鎹簱
  Future<void> _onSyncFromCloud(
    SyncFromCloud event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await TaskSyncService.instance.syncAll();
      add(LoadTasks());
      print('[Sync] user_tasks 鍚屾瀹屾垚');
    } catch (e) {
      print('[Sync] 鎷夊彇澶辫触: $e');
    }
  }

  Future<void> _runOptimisticTaskChange(
    Emitter<TaskNewState> emit,
    Future<void> Function() action,
  ) async {
    if (state is! TaskNewLoaded) {
      await action();
      add(LoadTasks());
      return;
    }

    final previous = state as TaskNewLoaded;
    final rollbackSnapshot = await taskRepository.getAllRaw();
    try {
      await action();
      await _emitTaskSnapshot(previous, emit);
      try {
        await TaskSyncService.instance.syncAll(rethrowErrors: true);
      } catch (_) {
        await taskRepository.restoreRawTasks(rollbackSnapshot);
        emit(previous.copyWith(syncRollbackMessage: '鍚屾澶辫触锛屽凡鍥為€€鏈鎿嶄綔'));
      }
    } catch (e) {
      await taskRepository.restoreRawTasks(rollbackSnapshot);
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _emitTaskSnapshot(
    TaskNewLoaded previous,
    Emitter<TaskNewState> emit,
  ) async {
    final projects = await projectRepository.getActive();
    await _storage.init();
    final excludedProjectIds = _storage.excludedProjectIds;
    final allTasks = (await taskRepository.getAll())
        .where((t) => !excludedProjectIds.contains(t.projectId))
        .toList();
    final selectedProjectIds = previous.selectedProjectIds
        .where((id) => !excludedProjectIds.contains(id))
        .toSet();
    final filter = previous.selectedFilter ?? 'all';

    List<Task> tasks;
    if (filter == 'today') {
      tasks = (await taskRepository.getToday())
          .where((t) => !excludedProjectIds.contains(t.projectId))
          .toList();
    } else if (filter == 'important') {
      tasks = (await taskRepository.getImportant())
          .where((t) => !excludedProjectIds.contains(t.projectId))
          .toList();
    } else if (selectedProjectIds.isNotEmpty) {
      tasks = allTasks
          .where((t) => selectedProjectIds.contains(t.projectId))
          .toList();
    } else {
      tasks = allTasks;
    }

    if (previous.dateFrom != null && previous.dateTo != null) {
      tasks = tasks.where((t) {
        final s = t.startDate ?? t.dueDate;
        final d = t.dueDate ?? t.startDate;
        if (s == null && d == null) return false;
        final taskStart = s ?? d!;
        final taskEnd = d ?? s!;
        return taskStart <= previous.dateTo! && taskEnd >= previous.dateFrom!;
      }).toList();
    }

    final progress = await _calculateProgress(allTasks);
    final groups =
        await (projectGroupRepository?.getAll() ??
            Future.value(<ProjectGroup>[]));
    emit(
      previous.copyWith(
        projects: projects,
        groups: groups,
        tasks: tasks,
        selectedProjectIds: selectedProjectIds,
        selectedFilter: filter,
        taskProgress: progress.taskProgress,
        projectProgress: progress.projectProgress,
        groupProgress: progress.groupProgress,
      ),
    );
  }

  Future<void> _onCreateTask(
    CreateTask event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(emit, () async {
      final newTask = await taskRepository.create(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        priority: event.priority,
        startDate: event.startDate,
        dueDate: event.dueDate,
        parentId: event.parentId,
        syncImmediately: false,
      );
      for (final shifted in event.shiftedTasks) {
        await taskRepository.update(
          shifted.taskId,
          startDate: shifted.start.millisecondsSinceEpoch,
          dueDate: shifted.end.millisecondsSinceEpoch,
          syncImmediately: false,
        );
      }
      flog(
        '[CreateTask] local commit: id=${newTask.id.substring(0, 8)}, title=${newTask.title}, parentId=${newTask.parentId?.substring(0, 8)}, projectId=${newTask.projectId}',
      );
    });
  }

  Future<void> _onUpdateTask(
    UpdateTask event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(emit, () async {
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
        syncImmediately: false,
      );

      if ((event.startDate != null || event.dueDate != null) &&
          state is TaskNewLoaded) {
        final tasks = (state as TaskNewLoaded).tasks;
        final updatedTask = tasks.where((t) => t.id == event.id).firstOrNull;
        if (updatedTask != null) {
          final childStart = event.startDate ?? updatedTask.startDate;
          final childEnd = event.dueDate ?? updatedTask.dueDate;
          await _expandAncestorDates(
            updatedTask.parentId,
            childStart,
            childEnd,
            tasks,
            syncImmediately: false,
          );
        }
      }
    });
  }

  Future<void> _expandAncestorDates(
    String? parentId,
    int? childStart,
    int? childEnd,
    List<Task> tasks, {
    bool syncImmediately = true,
  }) async {
    String? currentParentId = parentId;
    while (currentParentId != null) {
      final parent = tasks.where((t) => t.id == currentParentId).firstOrNull;
      if (parent == null) break;

      int? ns = parent.startDate;
      int? nd = parent.dueDate;
      if (childStart != null)
        ns = (ns == null || childStart < ns) ? childStart : ns;
      if (childEnd != null) nd = (nd == null || childEnd > nd) ? childEnd : nd;

      if (ns != parent.startDate || nd != parent.dueDate) {
        await taskRepository.update(
          parent.id,
          startDate: ns,
          dueDate: nd,
          syncImmediately: syncImmediately,
        );
      }
      currentParentId = parent.parentId;
    }
  }

  Future<void> _onDeleteTask(
    DeleteTask event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(
      emit,
      () => taskRepository.delete(event.id, syncImmediately: false),
    );
  }

  Future<void> _onToggleTaskStatus(
    ToggleTaskStatus event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(
      emit,
      () => taskRepository.toggleStatus(event.id, syncImmediately: false),
    );
  }
  // --- 妫€鏌ラ」 ---

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

  // --- 瀛愪换鍔℃爲 ---

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

  /// 浠庝换鎰忚妭鐐?ID 閫掑綊鎵惧埌鏍硅妭鐐?ID
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

  // --- 鏍戝舰鎷栨嫿 ---

  Future<void> _onMoveTaskToParent(
    MoveTaskToParent event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(emit, () async {
      if (event.newParentId != null && state is TaskNewLoaded) {
        final tasks = (state as TaskNewLoaded).tasks;
        if (_isDescendantOf(event.taskId, event.newParentId!, tasks)) {
          return;
        }
      }
      await taskRepository.moveTask(
        event.taskId,
        event.newParentId,
        syncImmediately: false,
      );

      if (event.newParentId != null && state is TaskNewLoaded) {
        final tasks = (state as TaskNewLoaded).tasks;
        final parent = tasks
            .where((t) => t.id == event.newParentId)
            .firstOrNull;
        final child = tasks.where((t) => t.id == event.taskId).firstOrNull;
        if (parent != null && child != null) {
          int? ns = parent.startDate;
          int? nd = parent.dueDate;
          final cs = child.startDate;
          final cd = child.dueDate;
          if (cs != null) ns = (ns == null || cs < ns) ? cs : ns;
          if (cd != null) nd = (nd == null || cd > nd) ? cd : nd;
          if (ns != parent.startDate || nd != parent.dueDate) {
            await taskRepository.update(
              parent.id,
              startDate: ns,
              dueDate: nd,
              syncImmediately: false,
            );
          }
        }
      }
    });
  }

  /// 妫€鏌?targetId 鏄惁鏄?ancestorId 鐨勫悗浠?
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
    await _runOptimisticTaskChange(
      emit,
      () => taskRepository.reorderSubTasks(
        event.parentId,
        event.orderedIds,
        syncImmediately: false,
      ),
    );
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

  void _onToggleViewMode(ToggleViewMode event, Emitter<TaskNewState> emit) {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newMode = current.viewMode == 'mindmap' ? 'list' : 'mindmap';
      emit(current.copyWith(viewMode: newMode));
    }
  }
}
