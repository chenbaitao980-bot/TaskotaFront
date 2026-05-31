import 'package:equatable/equatable.dart';
import '../../../data/database/app_database.dart';

class TaskNewState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TaskNewInitial extends TaskNewState {}

class TaskNewLoading extends TaskNewState {}

class TaskNewLoaded extends TaskNewState {
  final List<Project> projects;
  final List<ProjectGroup> groups;
  final List<Task> tasks;
  final Set<String> selectedProjectIds;
  String? get selectedProjectId =>
      selectedProjectIds.length == 1 ? selectedProjectIds.first : null;
  final String? selectedFilter;
  final Map<String, List<ChecklistItem>> checklistItems;
  final Map<String, List<Task>> subTrees;
  final Map<String, Set<String>> expandedNodes;
  final Map<String, int> taskProgress;
  final Map<String, int> projectProgress;
  final Map<String, int> groupProgress;
  final int? dateFrom;
  final int? dateTo;
  final String viewMode; // 'mindmap' or 'list'

  TaskNewLoaded({
    this.projects = const [],
    this.groups = const [],
    this.tasks = const [],
    String? selectedProjectId,
    Set<String> selectedProjectIds = const {},
    this.selectedFilter = 'all',
    this.checklistItems = const {},
    this.subTrees = const {},
    this.expandedNodes = const {},
    this.taskProgress = const {},
    this.projectProgress = const {},
    this.groupProgress = const {},
    this.dateFrom,
    this.dateTo,
    this.viewMode = 'mindmap',
  }) : selectedProjectIds = selectedProjectIds.isNotEmpty
           ? selectedProjectIds
           : (selectedProjectId == null ? const {} : {selectedProjectId});

  TaskNewLoaded copyWith({
    List<Project>? projects,
    List<ProjectGroup>? groups,
    List<Task>? tasks,
    String? selectedProjectId,
    Set<String>? selectedProjectIds,
    String? selectedFilter,
    Map<String, List<ChecklistItem>>? checklistItems,
    Map<String, List<Task>>? subTrees,
    Map<String, Set<String>>? expandedNodes,
    Map<String, int>? taskProgress,
    Map<String, int>? projectProgress,
    Map<String, int>? groupProgress,
    int? dateFrom,
    int? dateTo,
    bool clearDateRange = false,
    String? viewMode,
  }) {
    return TaskNewLoaded(
      projects: projects ?? this.projects,
      groups: groups ?? this.groups,
      tasks: tasks ?? this.tasks,
      selectedProjectIds:
          selectedProjectIds ??
          (selectedProjectId == null
              ? this.selectedProjectIds
              : {selectedProjectId}),
      selectedFilter: selectedFilter ?? this.selectedFilter,
      checklistItems: checklistItems ?? this.checklistItems,
      subTrees: subTrees ?? this.subTrees,
      expandedNodes: expandedNodes ?? this.expandedNodes,
      taskProgress: taskProgress ?? this.taskProgress,
      projectProgress: projectProgress ?? this.projectProgress,
      groupProgress: groupProgress ?? this.groupProgress,
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      viewMode: viewMode ?? this.viewMode,
    );
  }

  @override
  List<Object?> get props => [
    projects,
    groups,
    tasks,
    selectedProjectIds,
    selectedFilter,
    checklistItems,
    subTrees,
    expandedNodes,
    taskProgress,
    projectProgress,
    groupProgress,
    dateFrom,
    dateTo,
    viewMode,
  ];
}

class TaskNewError extends TaskNewState {
  final String message;
  TaskNewError(this.message);
  @override
  List<Object> get props => [message];
}
