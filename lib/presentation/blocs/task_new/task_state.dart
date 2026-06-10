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
  final String selectedStatusFilter;
  final Map<String, List<ChecklistItem>> checklistItems;
  final Map<String, List<Task>> subTrees;
  final Map<String, Set<String>> expandedNodes;
  final Map<String, int> taskProgress;
  final Map<String, int> projectProgress;
  final Map<String, int> groupProgress;
  final int? dateFrom;
  final int? dateTo;
  final String viewMode; // 'mindmap' or 'list'
  final String? syncRollbackMessage;
  final bool isTemplateMode;
  final List<Project> templateProjects;
  final String? focusTaskId;
  final int? focusRequestToken;
  final String? searchKeyword;
  final bool showArchivedView;

  TaskNewLoaded({
    this.projects = const [],
    this.groups = const [],
    this.tasks = const [],
    String? selectedProjectId,
    Set<String> selectedProjectIds = const {},
    this.selectedFilter = 'all',
    this.selectedStatusFilter = 'all',
    this.checklistItems = const {},
    this.subTrees = const {},
    this.expandedNodes = const {},
    this.taskProgress = const {},
    this.projectProgress = const {},
    this.groupProgress = const {},
    this.dateFrom,
    this.dateTo,
    this.viewMode = 'mindmap',
    this.syncRollbackMessage,
    this.isTemplateMode = false,
    this.templateProjects = const [],
    this.focusTaskId,
    this.focusRequestToken,
    this.searchKeyword,
    this.showArchivedView = false,
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
    String? selectedStatusFilter,
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
    String? syncRollbackMessage,
    bool clearSyncRollbackMessage = true,
    bool? isTemplateMode,
    List<Project>? templateProjects,
    String? focusTaskId,
    int? focusRequestToken,
    String? searchKeyword,
    bool? showArchivedView,
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
      selectedStatusFilter: selectedStatusFilter ?? this.selectedStatusFilter,
      checklistItems: checklistItems ?? this.checklistItems,
      subTrees: subTrees ?? this.subTrees,
      expandedNodes: expandedNodes ?? this.expandedNodes,
      taskProgress: taskProgress ?? this.taskProgress,
      projectProgress: projectProgress ?? this.projectProgress,
      groupProgress: groupProgress ?? this.groupProgress,
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      viewMode: viewMode ?? this.viewMode,
      syncRollbackMessage: clearSyncRollbackMessage
          ? syncRollbackMessage
          : (syncRollbackMessage ?? this.syncRollbackMessage),
      isTemplateMode: isTemplateMode ?? this.isTemplateMode,
      templateProjects: templateProjects ?? this.templateProjects,
      focusTaskId: focusTaskId ?? this.focusTaskId,
      focusRequestToken: focusRequestToken ?? this.focusRequestToken,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      showArchivedView: showArchivedView ?? this.showArchivedView,
    );
  }

  @override
  List<Object?> get props => [
    projects,
    groups,
    tasks,
    selectedProjectIds,
    selectedFilter,
    selectedStatusFilter,
    checklistItems,
    subTrees,
    expandedNodes,
    taskProgress,
    projectProgress,
    groupProgress,
    dateFrom,
    dateTo,
    viewMode,
    syncRollbackMessage,
    isTemplateMode,
    templateProjects,
    focusTaskId,
    focusRequestToken,
    searchKeyword,
    showArchivedView,
  ];
}

class TaskNewError extends TaskNewState {
  final String message;
  final bool isQuotaExceeded;
  TaskNewError(this.message, {this.isQuotaExceeded = false});
  @override
  List<Object> get props => [message, isQuotaExceeded];
}
