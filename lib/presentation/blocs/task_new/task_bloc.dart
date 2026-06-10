import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import '../../../core/exceptions/quota_exceeded_exception.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/project_group_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/checklist_repository.dart';
import '../../../data/repositories/node_template_repository.dart';
import '../../../models/node_template_payload.dart';
import '../../../domain/tasks/task_progress_calculator.dart';
import '../../../services/supabase_service.dart';
import '../../../core/utils/file_logger.dart';
import '../../../services/local_storage_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/task_sync_service.dart';
import '../../../services/task_attachment_service.dart';

class TaskNewBloc extends Bloc<TaskEvent, TaskNewState> {
  final ProjectRepository projectRepository;
  final ProjectGroupRepository? projectGroupRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;
  final NodeTemplateRepository nodeTemplateRepository;
  final SupabaseService? supabaseService;
  final LocalStorageService _storage = LocalStorageService();

  TaskNewBloc({
    required this.projectRepository,
    this.projectGroupRepository,
    required this.taskRepository,
    required this.checklistRepository,
    required this.nodeTemplateRepository,
    this.supabaseService,
  }) : super(TaskNewInitial()) {
    _storage.init();
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
    on<ReorderChecklistItems>(_onReorderChecklistItems);

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
    on<MergeSubTasksToChecklist>(_onMergeSubTasksToChecklist);
    on<ApplyTemplate>(_onApplyTemplate);
    on<SetSearchQuery>(_onSetSearchQuery);
    on<ArchiveTask>(_onArchiveTask);
    on<UnarchiveTask>(_onUnarchiveTask);
    on<LoadArchivedTasks>(_onLoadArchivedTasks);
  }

  @visibleForTesting
  static Set<String> resolveSubTreeExpandedNodesForRefresh({
    required String rootTaskId,
    required List<Task> descendants,
    required Set<String>? currentExpanded,
  }) {
    if (currentExpanded != null) {
      final descendantIds = descendants.map((t) => t.id).toSet();
      return currentExpanded.where(descendantIds.contains).toSet();
    }
    return descendants
        .where((t) => t.parentId == rootTaskId)
        .map((t) => t.id)
        .toSet();
  }

  // --- 椤圭洰 ---

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is! TaskNewLoaded) emit(TaskNewLoading());
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
        isTemplate: event.isTemplate,
      );
      final projects = event.isTemplate
          ? await projectRepository.getTemplateProjects()
          : await projectRepository.getActive();
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        emit(current.copyWith(projects: projects));
      } else {
        emit(TaskNewLoaded(projects: projects));
      }
    } catch (e) {
      final isQuota = e is QuotaExceededException;
      emit(TaskNewError(e.toString(), isQuotaExceeded: isQuota));
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
    String preservedFilter = 'all';
    String preservedStatusFilter = 'all';
    Set<String> preservedProjectIds = const {};
    int? preservedDateFrom;
    int? preservedDateTo;
    String? preservedSearchKeyword;
    bool preservedShowArchivedView = false;
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      preservedSubTrees = current.subTrees;
      preservedExpanded = current.expandedNodes;
      preservedViewMode = current.viewMode;
      preservedFilter = current.selectedFilter ?? 'all';
      preservedStatusFilter = current.selectedStatusFilter;
      preservedProjectIds = current.selectedProjectIds;
      preservedDateFrom = current.dateFrom;
      preservedDateTo = current.dateTo;
      preservedSearchKeyword = current.searchKeyword;
      preservedShowArchivedView = current.showArchivedView;
    }

    if (state is! TaskNewLoaded) emit(TaskNewLoading());
    try {
      final isTemplateMode = event.filter == 'templates';
      final templateProjects = await projectRepository.getTemplateProjects();
      final projects = isTemplateMode
          ? templateProjects
          : await projectRepository.getActive();
      await _storage.init();
      // 首次加载时从本地/云端恢复筛选状态
      if (state is! TaskNewLoaded) {
        final localPrefs = _storage.getTaskFilterState();
        final cloudPrefs = await supabaseService?.fetchPreferences();
        final prefs = cloudPrefs ?? localPrefs;
        if (prefs != null) {
          preservedFilter = prefs['selectedFilter'] as String? ?? 'all';
          preservedStatusFilter =
              prefs['selectedStatusFilter'] as String? ?? 'all';
          preservedViewMode = prefs['viewMode'] as String? ?? 'mindmap';
          preservedProjectIds = (prefs['projectIds'] as List<dynamic>? ?? [])
              .cast<String>()
              .toSet();
          preservedDateFrom = prefs['dateFrom'] as int?;
          preservedDateTo = prefs['dateTo'] as int?;
        }
      }
      final excludedProjectIds = _storage.excludedProjectIds;
      final templateProjIds = templateProjects.map((p) => p.id).toSet();
      final allTasks = (await taskRepository.getAll())
          .where((t) => !excludedProjectIds.contains(t.projectId))
          .where((t) => isTemplateMode
              ? templateProjIds.contains(t.projectId)
              : !templateProjIds.contains(t.projectId))
          .toList();
      final selectedProjectIds =
          (event.hasProjectSelectionOverride
                  ? event.projectIds
                  : preservedProjectIds)
              .where((id) => !excludedProjectIds.contains(id))
              .toSet();
      final selectedFilter = event.filter ?? preservedFilter;
      final selectedStatusFilter = event.statusFilter ?? preservedStatusFilter;
      final selectedDateFrom = event.clearDateRange
          ? null
          : (event.dateFrom ?? preservedDateFrom);
      final selectedDateTo = event.clearDateRange
          ? null
          : (event.dateTo ?? preservedDateTo);
      final selectedSearchKeyword = event.hasSearchKeyword ? event.searchKeyword : preservedSearchKeyword;
      List<Task> tasks;
      if (selectedFilter == 'today') {
        tasks = (await taskRepository.getToday())
            .where((t) => !excludedProjectIds.contains(t.projectId))
            .toList();
      } else if (selectedFilter == 'important') {
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
      if (selectedDateFrom != null && selectedDateTo != null) {
        tasks = tasks.where((t) {
          final s = t.startDate ?? t.dueDate;
          final d = t.dueDate ?? t.startDate;
          if (s == null && d == null) return false;
          final taskStart = s ?? d!;
          final taskEnd = d ?? s!;
          return taskStart <= selectedDateTo && taskEnd >= selectedDateFrom;
        }).toList();
      }

      // DEBUG: 璇婃柇瀛愪换鍔℃秷澶?
      if (selectedStatusFilter == 'pending') {
        tasks = tasks.where((t) => t.status == 0).toList();
      } else if (selectedStatusFilter == 'completed') {
        tasks = tasks.where((t) => t.status == 2).toList();
      }

      // Search keyword filtering: intersect with DB search results
      if (selectedSearchKeyword != null && selectedSearchKeyword.isNotEmpty) {
        final matchedIds = await taskRepository.searchTaskIds(selectedSearchKeyword);
        tasks = tasks.where((t) => matchedIds.contains(t.id)).toList();
      }

      flog(
        '[LoadTasks] filter=$selectedFilter, projectIds=$selectedProjectIds, searchKeyword=$selectedSearchKeyword, tasks=${tasks.length}/${allTasks.length}',
      );

      final allProjects = isTemplateMode
          ? templateProjects
          : [...projects, ...templateProjects];
      final progress = await _calculateProgress(
        allTasks,
        cachedProjects: allProjects,
      );

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
          selectedFilter: selectedFilter,
          selectedStatusFilter: selectedStatusFilter,
          subTrees: preservedSubTrees,
          expandedNodes: newExpanded,
          taskProgress: progress.taskProgress,
          projectProgress: progress.projectProgress,
          groupProgress: progress.groupProgress,
          dateFrom: selectedDateFrom,
          dateTo: selectedDateTo,
          viewMode: event.focusTaskId != null ? 'mindmap' : preservedViewMode,
          isTemplateMode: isTemplateMode,
          templateProjects: templateProjects,
          focusTaskId: event.focusTaskId,
          focusRequestToken: event.focusRequestToken,
          searchKeyword: selectedSearchKeyword,
          showArchivedView: event.hasProjectSelectionOverride || event.filter != null
              ? false
              : preservedShowArchivedView,
        ),
      );
      _persistFilterState(
        selectedFilter: selectedFilter,
        selectedStatusFilter: selectedStatusFilter,
        viewMode: event.focusTaskId != null ? 'mindmap' : preservedViewMode,
        selectedProjectIds: selectedProjectIds,
        dateFrom: selectedDateFrom,
        dateTo: selectedDateTo,
      );
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _persistFilterState({
    required String selectedFilter,
    required String selectedStatusFilter,
    required String viewMode,
    required Set<String> selectedProjectIds,
    required int? dateFrom,
    required int? dateTo,
  }) async {
    final data = {
      'selectedFilter': selectedFilter,
      'selectedStatusFilter': selectedStatusFilter,
      'viewMode': viewMode,
      'projectIds': selectedProjectIds.toList(),
      'dateFrom': dateFrom,
      'dateTo': dateTo,
    };
    await _storage.saveTaskFilterState(data);
    supabaseService?.syncPreferences(data);
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
      if (state is TaskNewLoaded && (state as TaskNewLoaded).showArchivedView) {
        final currentFilter = (state as TaskNewLoaded).selectedStatusFilter;
        add(LoadArchivedTasks(statusFilter: currentFilter));
      } else {
        add(LoadTasks());
      }
      print('[Sync] user_tasks鍚屾瀹屾垚');
    } catch (e) {
      print('[Sync] 鎷夊彇澶辫触: $e');
    }
  }

  Future<void> _runOptimisticTaskChange(
    Emitter<TaskNewState> emit,
    Future<void> Function() action, {
    TaskNewLoaded Function(TaskNewLoaded snapshot)? adjustSnapshot,
  }) async {
    if (state is! TaskNewLoaded) {
      await action();
      add(LoadTasks());
      return;
    }

    final previous = state as TaskNewLoaded;
    final rollbackSnapshot = await taskRepository.getAllRaw();
    try {
      await action();
      await _emitTaskSnapshot(previous, emit, adjustSnapshot: adjustSnapshot);
      try {
        await TaskSyncService.instance.syncAll(rethrowErrors: true);
      } catch (e) {
        flog('[TaskBloc] syncAll failed (non-fatal): $e');
      }
    } on QuotaExceededException catch (e) {
      emit(TaskNewError(e.toString(), isQuotaExceeded: true));
    } catch (e) {
      await taskRepository.restoreRawTasks(rollbackSnapshot);
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _emitTaskSnapshot(
    TaskNewLoaded previous,
    Emitter<TaskNewState> emit, {
    TaskNewLoaded Function(TaskNewLoaded snapshot)? adjustSnapshot,
  }) async {
    final isTemplate = previous.isTemplateMode;
    final projects = isTemplate
        ? await projectRepository.getTemplateProjects()
        : await projectRepository.getActive();
    await _storage.init();
    final excludedProjectIds = _storage.excludedProjectIds;
    final templateProjIds = isTemplate
        ? projects.map((p) => p.id).toSet()
        : (await projectRepository.getTemplateProjects())
            .map((p) => p.id)
            .toSet();
    final allTasks = (await taskRepository.getAll())
        .where((t) => !excludedProjectIds.contains(t.projectId))
        .where((t) => isTemplate
            ? templateProjIds.contains(t.projectId)
            : !templateProjIds.contains(t.projectId))
        .toList();
    final selectedProjectIds = previous.selectedProjectIds
        .where((id) => !excludedProjectIds.contains(id))
        .toSet();
    final filter = previous.selectedFilter ?? 'all';
    final statusFilter = previous.selectedStatusFilter;

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

    if (statusFilter == 'pending') {
      tasks = tasks.where((t) => t.status == 0).toList();
    } else if (statusFilter == 'completed') {
      tasks = tasks.where((t) => t.status == 2).toList();
    }

    // Search keyword filtering
    if (previous.searchKeyword != null && previous.searchKeyword!.isNotEmpty) {
      final matchedIds = await taskRepository.searchTaskIds(previous.searchKeyword!);
      tasks = tasks.where((t) => matchedIds.contains(t.id)).toList();
    }

    final progress = await _calculateProgress(allTasks);
    final groups =
        await (projectGroupRepository?.getAll() ??
            Future.value(<ProjectGroup>[]));
    final snapshot = previous.copyWith(
      projects: projects,
      groups: groups,
      tasks: tasks,
      selectedProjectIds: selectedProjectIds,
      selectedFilter: filter,
      taskProgress: progress.taskProgress,
      projectProgress: progress.projectProgress,
      groupProgress: progress.groupProgress,
    );
    emit(adjustSnapshot == null ? snapshot : adjustSnapshot(snapshot));
  }

  Future<void> _onCreateTask(
    CreateTask event,
    Emitter<TaskNewState> emit,
  ) async {
    String? createdTaskId;
    await _runOptimisticTaskChange(
      emit,
      () async {
        final newTask = await taskRepository.create(
          projectId: event.projectId,
          title: event.title,
          description: event.description,
          priority: event.priority,
          startDate: event.startDate,
          dueDate: event.dueDate,
          parentId: event.parentId,
          remindBeforeMinutes: event.remindBeforeMinutes,
          reminderEnabled: event.reminderEnabled,
          syncImmediately: true,
        );
        createdTaskId = newTask.id;
        // 新建时附带的图片
        if (event.pendingImages.isNotEmpty) {
          final attachSvc = TaskAttachmentService();
          for (final img in event.pendingImages) {
            try {
              await attachSvc.saveAttachment(newTask.id, img);
            } catch (_) {}
          }
        }
        for (final image in event.templatePayload.images) {
          try {
            await TaskAttachmentService().saveImageBytes(
              newTask.id,
              fileName: image.fileName,
              bytes: image.bytes,
            );
          } catch (_) {}
        }
        for (final title in event.templatePayload.checklistTitles) {
          await checklistRepository.create(taskId: newTask.id, title: title);
        }
        for (final subtask in event.templatePayload.subtasks) {
          await _createTemplateSubtaskTree(
            subtask,
            projectId: event.projectId,
            parentId: newTask.id,
          );
        }
        await _expandAncestorDatesForTaskId(newTask.id, syncImmediately: false);
        for (final shifted in event.shiftedTasks) {
          await taskRepository.update(
            shifted.taskId,
            startDate: shifted.start.millisecondsSinceEpoch,
            dueDate: shifted.end.millisecondsSinceEpoch,
            syncImmediately: false,
          );
          await _expandAncestorDatesForTaskId(
            shifted.taskId,
            syncImmediately: false,
          );
        }
        flog(
          '[CreateTask] local commit: id=${newTask.id.substring(0, 8)}, title=${newTask.title}, parentId=${newTask.parentId?.substring(0, 8)}, projectId=${newTask.projectId}',
        );
      },
      adjustSnapshot: (snapshot) {
        final taskId = createdTaskId;
        if (taskId == null) return snapshot;
        final newExpanded = Map<String, Set<String>>.from(
          snapshot.expandedNodes,
        );
        final mainTree = Set<String>.from(newExpanded['main_tree'] ?? {});
        if (event.parentId != null) mainTree.add(event.parentId!);
        mainTree.addAll(_ancestorIds(taskId, snapshot.tasks));
        newExpanded['main_tree'] = mainTree;
        // 确保新任务不被当前项目过滤排除
        final newProjectIds = snapshot.selectedProjectIds.isEmpty
            ? snapshot.selectedProjectIds
            : <String>{...snapshot.selectedProjectIds, event.projectId};
        return snapshot.copyWith(
          expandedNodes: newExpanded,
          viewMode: 'mindmap',
          selectedProjectIds: newProjectIds,
          focusTaskId: taskId,
          focusRequestToken: DateTime.now().microsecondsSinceEpoch,
        );
      },
    );
  }

  Future<void> _createTemplateSubtaskTree(
    NodeTemplateSubtask template, {
    required String projectId,
    required String parentId,
  }) async {
    final task = await taskRepository.create(
      projectId: projectId,
      title: template.title.trim(),
      description: template.description.trim(),
      priority: 1,
      parentId: parentId,
      syncImmediately: false,
    );
    for (final child in template.children) {
      await _createTemplateSubtaskTree(
        child,
        projectId: projectId,
        parentId: task.id,
      );
    }
  }

  Future<void> _expandAncestorDatesForTaskId(
    String taskId, {
    bool syncImmediately = true,
  }) async {
    final task = await taskRepository.get(taskId);
    if (task == null) return;
    await taskRepository.expandAncestorDates(
      task.parentId,
      task.startDate,
      task.dueDate,
      syncImmediately: syncImmediately,
    );
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

      if (event.startDate != null || event.dueDate != null) {
        final updatedTask = await taskRepository.get(event.id);
        if (updatedTask != null) {
          final childStart = event.startDate ?? updatedTask.startDate;
          final childEnd = event.dueDate ?? updatedTask.dueDate;
          await taskRepository.expandAncestorDates(
            updatedTask.parentId,
            childStart,
            childEnd,
            syncImmediately: false,
          );
        }
      }

      for (final shifted in event.shiftedTasks) {
        await taskRepository.update(
          shifted.taskId,
          startDate: shifted.start.millisecondsSinceEpoch,
          dueDate: shifted.end.millisecondsSinceEpoch,
          syncImmediately: false,
        );
        await _expandAncestorDatesForTaskId(
          shifted.taskId,
          syncImmediately: false,
        );
      }
    });
  }



  Future<void> _onDeleteTask(
    DeleteTask event,
    Emitter<TaskNewState> emit,
  ) async {
    // 删除前取消所有相关通知
    final descendants = await taskRepository.getDescendants(event.id);
    final allIds = <String>[event.id, ...descendants.map((d) => d.id)];
    final notif = NotificationService();
    for (final id in allIds) {
      await notif.cancelReminderForSchedule(id);
    }
    await _runOptimisticTaskChange(
      emit,
      () async {
        await taskRepository.delete(event.id, syncImmediately: false);
        // 立即推送上云，不依赖 syncAll push 循环传播墓碑
        final raw = await taskRepository.getAllRaw();
        final target = raw.where((t) => t.id == event.id).firstOrNull;
        if (target != null) TaskSyncService.instance.push(target);
      },
    );
  }

  Future<void> _onToggleTaskStatus(
    ToggleTaskStatus event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(emit, () async {
      final task = await taskRepository.get(event.id);
      if (task == null) return;
      final nextStatus = task.status == 0 ? 2 : 0;
      // 完成任务时取消通知
      if (nextStatus == 2) {
        final notif = NotificationService();
        await notif.cancelReminderForSchedule(event.id);
        if (event.cascadeChildren) {
          final descendants = await taskRepository.getDescendants(event.id);
          for (final d in descendants) {
            await notif.cancelReminderForSchedule(d.id);
          }
        }
      }
      if (event.cascadeChildren) {
        await taskRepository.setStatusCascade(
          event.id,
          nextStatus,
          includeDescendants: nextStatus == 2,
          syncImmediately: false,
        );
      } else {
        await taskRepository.toggleStatus(event.id, syncImmediately: false);
      }
    });
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

  Future<void> _onReorderChecklistItems(
    ReorderChecklistItems event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await checklistRepository.reorderItems(event.taskId, event.orderedIds);
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

        final newExpanded = Map<String, Set<String>>.from(
          current.expandedNodes,
        );
        newExpanded[event.rootTaskId] = resolveSubTreeExpandedNodesForRefresh(
          rootTaskId: event.rootTaskId,
          descendants: descendants,
          currentExpanded: current.expandedNodes[event.rootTaskId],
        );

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

  Future<TaskProgressSnapshot> _calculateProgress(
    List<Task> allTasks, {
    List<Project>? cachedProjects,
  }) async {
    final checklistItems = await checklistRepository.getByTaskIds(
      allTasks.map((task) => task.id).toList(),
    );
    final projects = cachedProjects ?? await projectRepository.getAll();
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
          if (child.projectId != parent.projectId) {
            await taskRepository.update(
              child.id,
              projectId: parent.projectId,
              syncImmediately: false,
            );
          }
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

  Future<void> _onToggleViewMode(
    ToggleViewMode event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      final newMode = current.viewMode == 'mindmap' ? 'list' : 'mindmap';
      emit(current.copyWith(viewMode: newMode));
      await _persistFilterState(
        selectedFilter: current.selectedFilter ?? 'all',
        selectedStatusFilter: current.selectedStatusFilter,
        viewMode: newMode,
        selectedProjectIds: current.selectedProjectIds,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
      );
    }
  }

  Future<void> _onMergeSubTasksToChecklist(
    MergeSubTasksToChecklist event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      final descendants = await taskRepository.getDescendants(event.taskId);
      final directChildren = descendants
          .where((t) => t.parentId == event.taskId)
          .toList();

      // 获取现有检查项标题用于去重
      final existingItems = await checklistRepository.getByTask(event.taskId);
      final existingTitles = existingItems.map((i) => i.title.trim()).toSet();

      for (final child in directChildren) {
        // 只处理叶子节点
        if (descendants.any((d) => d.parentId == child.id)) continue;
        // 只合并已完成的子任务
        if (child.status != 2) continue;
        // 去重：同名检查项已存在则跳过
        if (existingTitles.contains(child.title.trim())) continue;

        final attachments = await TaskAttachmentService().getAttachments(
          child.id,
        );
        final hasContent =
            attachments.isNotEmpty || child.description.trim().isNotEmpty;
        if (!hasContent) {
          final item = await checklistRepository.create(
            taskId: event.taskId,
            title: child.title,
          );
          // 标记检查项为已完成，与子任务状态一致
          await checklistRepository.toggleStatus(item.id);
          existingTitles.add(child.title.trim());
          await taskRepository.delete(child.id);
        }
      }

      // 在同一 handler 内一次性 emit，避免多次 emit 互相覆盖导致检查项不刷新
      final newDescendants = await taskRepository.getDescendants(event.taskId);
      final newItems = await checklistRepository.getByTask(event.taskId);
      final allTasks = await taskRepository.getAll();
      final progress = await _calculateProgress(allTasks);

      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newTrees = Map<String, List<Task>>.from(current.subTrees);
        newTrees[event.taskId] = newDescendants;
        final newMap = Map<String, List<ChecklistItem>>.from(
          current.checklistItems,
        );
        newMap[event.taskId] = newItems;
        final newExpanded = Map<String, Set<String>>.from(
          current.expandedNodes,
        );
        newExpanded[event.taskId] = resolveSubTreeExpandedNodesForRefresh(
          rootTaskId: event.taskId,
          descendants: newDescendants,
          currentExpanded: current.expandedNodes[event.taskId],
        );
        emit(
          current.copyWith(
            subTrees: newTrees,
            expandedNodes: newExpanded,
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

  Future<void> _onSetSearchQuery(
    SetSearchQuery event,
    Emitter<TaskNewState> emit,
  ) async {
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      if (current.showArchivedView) {
        add(LoadArchivedTasks(
          statusFilter: current.selectedStatusFilter,
          searchKeyword: event.keyword,
          dateFrom: current.dateFrom,
          dateTo: current.dateTo,
        ));
      } else {
        add(LoadTasks(
          projectIds: current.selectedProjectIds,
          filter: current.selectedFilter,
          statusFilter: current.selectedStatusFilter,
          dateFrom: current.dateFrom,
          dateTo: current.dateTo,
          searchKeyword: event.keyword,
          hasSearchKeyword: true,
        ));
      }
    }
  }

  Future<void> _onApplyTemplate(
    ApplyTemplate event,
    Emitter<TaskNewState> emit,
  ) async {
    await _runOptimisticTaskChange(emit, () async {
      final templateTasks = await taskRepository.getAll();
      final tasksInTemplate = templateTasks
          .where((t) => t.projectId == event.templateProjectId)
          .toList();
      if (tasksInTemplate.isEmpty) return;

      final roots = tasksInTemplate
          .where((t) => t.parentId == null)
          .toList();
      if (roots.isEmpty) return;

      final earliestStart = roots
          .where((t) => t.startDate != null)
          .map((t) => t.startDate!)
          .fold<int?>(null, (a, b) => a == null ? b : (b < a ? b : a));
      final offsetMillis = earliestStart != null
          ? event.startTimeMillis - earliestStart
          : 0;

      final idMapping = <String, String>{};
      final cloneChecklistItems = await Future.wait(
        tasksInTemplate.map((t) => checklistRepository.getByTask(t.id)),
      );
      final checklistByTask = <String, List<ChecklistItem>>{};
      for (var i = 0; i < tasksInTemplate.length; i++) {
        checklistByTask[tasksInTemplate[i].id] = cloneChecklistItems[i];
      }

      Future<void> cloneTree(List<Task> siblings, String? parentId) async {
        for (final t in siblings) {
          final newStart = t.startDate != null
              ? t.startDate! + offsetMillis
              : null;
          final newDue = t.dueDate != null
              ? t.dueDate! + offsetMillis
              : null;
          final newTask = await taskRepository.create(
            projectId: event.targetProjectId,
            title: t.title,
            description: t.description,
            priority: t.priority,
            startDate: newStart,
            dueDate: newDue,
            parentId: parentId ?? event.parentId,
            syncImmediately: false,
          );
          idMapping[t.id] = newTask.id;

          final items = checklistByTask[t.id] ?? [];
          for (final item in items) {
            await checklistRepository.create(
              taskId: newTask.id,
              title: item.title,
            );
          }

          final children = tasksInTemplate
              .where((c) => c.parentId == t.id)
              .toList();
          if (children.isNotEmpty) {
            await cloneTree(children, newTask.id);
          }
        }
      }

      await cloneTree(roots, null);
    });
  }

  // --- 归档 ---

  Future<void> _onArchiveTask(
    ArchiveTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      // 拦截：检查所有后代是否都已完成
      final allDone = await taskRepository.allDescendantsCompleted(event.id);
      if (!allDone) {
        emit(TaskNewError('无法归档：该任务还有未完成的子任务，请先完成所有子任务后再归档。'));
        return;
      }
      await taskRepository.archiveTask(event.id);
      // 刷新：归档视图内保持归档视图，普通视图刷新普通列表
      if (state is TaskNewLoaded && (state as TaskNewLoaded).showArchivedView) {
        final currentFilter = (state as TaskNewLoaded).selectedStatusFilter;
        add(LoadArchivedTasks(statusFilter: currentFilter));
      } else {
        add(LoadTasks());
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUnarchiveTask(
    UnarchiveTask event,
    Emitter<TaskNewState> emit,
  ) async {
    try {
      await taskRepository.unarchiveTask(event.id);
      // 刷新归档视图，保留当前状态筛选
      final currentFilter = state is TaskNewLoaded
          ? (state as TaskNewLoaded).selectedStatusFilter
          : 'all';
      add(LoadArchivedTasks(statusFilter: currentFilter));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onLoadArchivedTasks(
    LoadArchivedTasks event,
    Emitter<TaskNewState> emit,
  ) async {
    // 在 await 前捕获快照，防止 async 等待期间状态漂移导致 cast 失败
    final base = state is TaskNewLoaded ? state as TaskNewLoaded : null;
    if (base == null) return;
    try {
      var archivedTasks = await taskRepository.getArchived(
        searchKeyword: event.searchKeyword,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
      );
      if (event.statusFilter == 'pending') {
        archivedTasks = archivedTasks.where((t) => t.status != 2).toList();
      } else if (event.statusFilter == 'completed') {
        archivedTasks = archivedTasks.where((t) => t.status == 2).toList();
      }
      // 定位到最近的任务：归档按 updatedAt desc 排序，第一个即为最近任务
      final recentTaskId = archivedTasks.isNotEmpty ? archivedTasks.first.id : null;
      emit(base.copyWith(
        tasks: archivedTasks,
        showArchivedView: true,
        selectedStatusFilter: event.statusFilter,
        searchKeyword: event.searchKeyword,
        dateFrom: event.dateFrom,
        dateTo: event.dateTo,
        focusTaskId: recentTaskId,
        focusRequestToken: DateTime.now().microsecondsSinceEpoch,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }
}
