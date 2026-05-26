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
  final List<Task> tasks;
  final String? selectedProjectId;
  final String? selectedFilter;
  final Map<String, List<ChecklistItem>> checklistItems;
  final Map<String, List<Task>> subTrees;
  final Map<String, Set<String>> expandedNodes;
  final Map<String, int> taskProgress;
  final Map<String, int> projectProgress;

  TaskNewLoaded({
    this.projects = const [],
    this.tasks = const [],
    this.selectedProjectId,
    this.selectedFilter = 'all',
    this.checklistItems = const {},
    this.subTrees = const {},
    this.expandedNodes = const {},
    this.taskProgress = const {},
    this.projectProgress = const {},
  });

  TaskNewLoaded copyWith({
    List<Project>? projects,
    List<Task>? tasks,
    String? selectedProjectId,
    String? selectedFilter,
    Map<String, List<ChecklistItem>>? checklistItems,
    Map<String, List<Task>>? subTrees,
    Map<String, Set<String>>? expandedNodes,
    Map<String, int>? taskProgress,
    Map<String, int>? projectProgress,
  }) {
    return TaskNewLoaded(
      projects: projects ?? this.projects,
      tasks: tasks ?? this.tasks,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      checklistItems: checklistItems ?? this.checklistItems,
      subTrees: subTrees ?? this.subTrees,
      expandedNodes: expandedNodes ?? this.expandedNodes,
      taskProgress: taskProgress ?? this.taskProgress,
      projectProgress: projectProgress ?? this.projectProgress,
    );
  }

  @override
  List<Object?> get props => [
    projects,
    tasks,
    selectedProjectId,
    selectedFilter,
    checklistItems,
    subTrees,
    expandedNodes,
    taskProgress,
    projectProgress,
  ];
}

class TaskNewError extends TaskNewState {
  final String message;
  TaskNewError(this.message);
  @override
  List<Object> get props => [message];
}
