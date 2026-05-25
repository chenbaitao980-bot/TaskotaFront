import 'package:flutter_bloc/flutter_bloc.dart';
import 'task_event.dart';
import 'task_state.dart';
import '../../../data/database/app_database.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/checklist_repository.dart';

class TaskNewBloc extends Bloc<TaskEvent, TaskNewState> {
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final ChecklistRepository checklistRepository;

  TaskNewBloc({
    required this.projectRepository,
    required this.taskRepository,
    required this.checklistRepository,
  }) : super(TaskNewInitial()) {
    on<LoadProjects>(_onLoadProjects);
    on<CreateProject>(_onCreateProject);
    on<UpdateProject>(_onUpdateProject);
    on<DeleteProject>(_onDeleteProject);

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

    on<LoadSubTree>(_onLoadSubTree);
    on<AddSubTask>(_onAddSubTask);
    on<DeleteSubTask>(_onDeleteSubTask);
    on<MoveSubTask>(_onMoveSubTask);
    on<ToggleSubTask>(_onToggleSubTask);
    on<ToggleTreeNode>(_onToggleTreeNode);
  }

  // --- 项目 ---

  Future<void> _onLoadProjects(
      LoadProjects event, Emitter<TaskNewState> emit) async {
    emit(TaskNewLoading());
    try {
      final projects = await projectRepository.getActive();
      final tasks = await taskRepository.getAll();

      // 保留子树状态
      Map<String, List<Task>> subTrees = const {};
      Map<String, Set<String>> expandedNodes = const {};
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        subTrees = current.subTrees;
        expandedNodes = current.expandedNodes;
      }

      emit(TaskNewLoaded(
        projects: projects,
        tasks: tasks,
        subTrees: subTrees,
        expandedNodes: expandedNodes,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onCreateProject(
      CreateProject event, Emitter<TaskNewState> emit) async {
    try {
      await projectRepository.create(name: event.name, color: event.color);
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
      UpdateProject event, Emitter<TaskNewState> emit) async {
    try {
      await projectRepository.update(event.id,
          name: event.name, color: event.color);
      final projects = await projectRepository.getActive();
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(projects: projects));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteProject(
      DeleteProject event, Emitter<TaskNewState> emit) async {
    try {
      await projectRepository.delete(event.id);
      final projects = await projectRepository.getActive();
      final tasks = await taskRepository.getAll();
      if (state is TaskNewLoaded) {
        emit((state as TaskNewLoaded).copyWith(
          projects: projects,
          tasks: tasks,
        ));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 任务 ---

  Future<void> _onLoadTasks(
      LoadTasks event, Emitter<TaskNewState> emit) async {
    // 在 emit loading 前先保留子树状态，避免被 loading 覆盖
    Map<String, List<Task>> preservedSubTrees = const {};
    Map<String, Set<String>> preservedExpanded = const {};
    if (state is TaskNewLoaded) {
      final current = state as TaskNewLoaded;
      preservedSubTrees = current.subTrees;
      preservedExpanded = current.expandedNodes;
    }

    emit(TaskNewLoading());
    try {
      final projects = await projectRepository.getActive();
      List<Task> tasks;
      if (event.filter == 'today') {
        tasks = await taskRepository.getToday();
      } else if (event.filter == 'important') {
        tasks = await taskRepository.getImportant();
      } else if (event.projectId != null) {
        tasks = await taskRepository.getByProject(event.projectId!);
      } else {
        tasks = await taskRepository.getAll();
      }

      emit(TaskNewLoaded(
        projects: projects,
        tasks: tasks,
        selectedProjectId: event.projectId,
        selectedFilter: event.filter ?? 'all',
        subTrees: preservedSubTrees,
        expandedNodes: preservedExpanded,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onCreateTask(
      CreateTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.create(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
        priority: event.priority,
        startDate: event.startDate,
        dueDate: event.dueDate,
      );
      add(LoadTasks());
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onUpdateTask(
      UpdateTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.update(event.id,
          projectId: event.projectId,
          title: event.title,
          description: event.description,
          priority: event.priority,
          startDate: event.startDate,
          dueDate: event.dueDate);
      final current = state as TaskNewLoaded;
      add(LoadTasks(
        projectId: current.selectedProjectId,
        filter: current.selectedFilter,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteTask(
      DeleteTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.delete(event.id);
      final current = state as TaskNewLoaded;
      add(LoadTasks(
        projectId: current.selectedProjectId,
        filter: current.selectedFilter,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleTaskStatus(
      ToggleTaskStatus event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.toggleStatus(event.id);
      final current = state as TaskNewLoaded;
      add(LoadTasks(
        projectId: current.selectedProjectId,
        filter: current.selectedFilter,
      ));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 检查项 ---

  Future<void> _onLoadChecklistItems(
      LoadChecklistItems event, Emitter<TaskNewState> emit) async {
    try {
      final items = await checklistRepository.getByTask(event.taskId);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newMap = Map<String, List<ChecklistItem>>.from(current.checklistItems);
        newMap[event.taskId] = items;
        emit(current.copyWith(checklistItems: newMap));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onAddChecklistItem(
      AddChecklistItem event, Emitter<TaskNewState> emit) async {
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
      UpdateChecklistItem event, Emitter<TaskNewState> emit) async {
    try {
      await checklistRepository.update(event.id, title: event.title);
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleChecklistItem(
      ToggleChecklistItem event, Emitter<TaskNewState> emit) async {
    try {
      await checklistRepository.toggleStatus(event.id);
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onDeleteChecklistItem(
      DeleteChecklistItem event, Emitter<TaskNewState> emit) async {
    try {
      await checklistRepository.delete(event.id);
      add(LoadChecklistItems(taskId: event.taskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  // --- 子任务树 ---

  Future<void> _onLoadSubTree(
      LoadSubTree event, Emitter<TaskNewState> emit) async {
    try {
      final descendants = await taskRepository.getDescendants(event.rootTaskId);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newTrees = Map<String, List<Task>>.from(current.subTrees);
        newTrees[event.rootTaskId] = descendants;

        final directChildren =
            descendants.where((t) => t.parentId == event.rootTaskId).toList();
        final newExpanded = Map<String, Set<String>>.from(current.expandedNodes);
        newExpanded[event.rootTaskId] = {
          for (final c in directChildren) c.id,
        };

        emit(current.copyWith(subTrees: newTrees, expandedNodes: newExpanded));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onAddSubTask(
      AddSubTask event, Emitter<TaskNewState> emit) async {
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
      DeleteSubTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.delete(event.taskId);
      final descendants = await taskRepository.getDescendants(event.rootTaskId);
      if (state is TaskNewLoaded) {
        final current = state as TaskNewLoaded;
        final newTrees = Map<String, List<Task>>.from(current.subTrees);
        newTrees[event.rootTaskId] = descendants;
        emit(current.copyWith(subTrees: newTrees));
      }
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onMoveSubTask(
      MoveSubTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.moveTask(event.taskId, event.newParentId);
      add(LoadSubTree(rootTaskId: event.rootTaskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleSubTask(
      ToggleSubTask event, Emitter<TaskNewState> emit) async {
    try {
      await taskRepository.toggleStatus(event.id);
      add(LoadSubTree(rootTaskId: event.rootTaskId));
    } catch (e) {
      emit(TaskNewError(e.toString()));
    }
  }

  Future<void> _onToggleTreeNode(
      ToggleTreeNode event, Emitter<TaskNewState> emit) async {
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
        if (entry.key == taskId ||
            entry.value.any((t) => t.id == taskId)) {
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
}
