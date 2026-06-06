import 'package:equatable/equatable.dart';
import 'package:file_picker/file_picker.dart';
import '../../../models/node_template_payload.dart';
import '../../../services/subtask_scheduler.dart';

// --- 项目事件 ---
class LoadProjects extends TaskEvent {}

class CreateProject extends TaskEvent {
  final String name;
  final String color;
  final String? groupId;
  final bool isTemplate;
  CreateProject({
    required this.name,
    this.color = '#4772FA',
    this.groupId,
    this.isTemplate = false,
  });
  @override
  List<Object?> get props => [name, color, groupId, isTemplate];
}

class UpdateProject extends TaskEvent {
  final String id;
  final String? name;
  final String? color;
  final String? groupId;
  final bool clearGroup;
  UpdateProject({
    required this.id,
    this.name,
    this.color,
    this.groupId,
    this.clearGroup = false,
  });
  @override
  List<Object?> get props => [id, name, color, groupId, clearGroup];
}

// --- 项目分组事件 ---
class CreateProjectGroup extends TaskEvent {
  final String name;
  final String color;
  CreateProjectGroup({required this.name, this.color = '#4772FA'});
  @override
  List<Object?> get props => [name, color];
}

class UpdateProjectGroup extends TaskEvent {
  final String id;
  final String? name;
  final String? color;
  UpdateProjectGroup({required this.id, this.name, this.color});
  @override
  List<Object?> get props => [id, name, color];
}

class DeleteProjectGroup extends TaskEvent {
  final String id;
  final bool deleteProjects; // 同时删除组内所有项目+任务
  DeleteProjectGroup({required this.id, this.deleteProjects = false});
  @override
  List<Object?> get props => [id, deleteProjects];
}

class DeleteProject extends TaskEvent {
  final String id;
  DeleteProject({required this.id});
  @override
  List<Object> get props => [id];
}

// --- 任务事件 ---
class LoadTasks extends TaskEvent {
  final String? projectId;
  final Set<String> projectIds;
  final bool hasProjectSelectionOverride;
  final String? filter; // 'all', 'today', 'important'
  final String? statusFilter; // 'all', 'pending', 'completed'
  final int?
  dateFrom; // millisecondsSinceEpoch, filter tasks overlapping [dateFrom, dateTo]
  final int? dateTo;
  final bool clearDateRange; // true=清除日期筛选，忽略已保留的日期
  final String? focusTaskId;
  final int? focusRequestToken;
  LoadTasks({
    this.projectId,
    Set<String>? projectIds,
    this.filter,
    this.statusFilter,
    this.dateFrom,
    this.dateTo,
    this.clearDateRange = false,
    this.focusTaskId,
    this.focusRequestToken,
  }) : projectIds = projectIds ?? (projectId == null ? const {} : {projectId}),
       hasProjectSelectionOverride = projectIds != null || projectId != null;
  @override
  List<Object?> get props => [
    projectId,
    projectIds,
    hasProjectSelectionOverride,
    filter,
    statusFilter,
    dateFrom,
    dateTo,
    clearDateRange,
    focusTaskId,
    focusRequestToken,
  ];
}

class CreateTask extends TaskEvent {
  final String projectId;
  final String title;
  final String description;
  final int priority;
  final int? startDate;
  final int? dueDate;
  final String? parentId;
  final List<ScheduledTaskShift> shiftedTasks;
  final List<PlatformFile> pendingImages;
  final NodeTemplatePayload templatePayload;
  final int remindBeforeMinutes;
  final int reminderEnabled;
  CreateTask({
    required this.projectId,
    required this.title,
    this.description = '',
    this.priority = 0,
    this.startDate,
    this.dueDate,
    this.parentId,
    this.shiftedTasks = const [],
    this.pendingImages = const [],
    this.templatePayload = NodeTemplatePayload.empty,
    this.remindBeforeMinutes = 15,
    this.reminderEnabled = 1,
  });
  @override
  List<Object?> get props => [
    projectId,
    title,
    description,
    priority,
    startDate,
    dueDate,
    parentId,
    shiftedTasks,
    pendingImages,
    templatePayload,
    remindBeforeMinutes,
    reminderEnabled,
  ];
}

class UpdateTask extends TaskEvent {
  final String id;
  final String? projectId;
  final String? title;
  final String? description;
  final int? priority;
  final int? startDate;
  final int? dueDate;
  final int? remindBeforeMinutes;
  final int? reminderEnabled;
  final List<ScheduledTaskShift> shiftedTasks;
  UpdateTask({
    required this.id,
    this.projectId,
    this.title,
    this.description,
    this.priority,
    this.startDate,
    this.dueDate,
    this.remindBeforeMinutes,
    this.reminderEnabled,
    this.shiftedTasks = const [],
  });
  @override
  List<Object?> get props => [
    id,
    projectId,
    title,
    description,
    priority,
    startDate,
    dueDate,
    remindBeforeMinutes,
    reminderEnabled,
    shiftedTasks,
  ];
}

class DeleteTask extends TaskEvent {
  final String id;
  DeleteTask({required this.id});
  @override
  List<Object> get props => [id];
}

class ToggleTaskStatus extends TaskEvent {
  final String id;
  final bool cascadeChildren;
  ToggleTaskStatus({required this.id, this.cascadeChildren = false});
  @override
  List<Object> get props => [id, cascadeChildren];
}

// --- 检查项事件 ---
class LoadChecklistItems extends TaskEvent {
  final String taskId;
  LoadChecklistItems({required this.taskId});
  @override
  List<Object> get props => [taskId];
}

class AddChecklistItem extends TaskEvent {
  final String taskId;
  final String title;
  AddChecklistItem({required this.taskId, required this.title});
  @override
  List<Object> get props => [taskId, title];
}

class UpdateChecklistItem extends TaskEvent {
  final String id;
  final String title;
  UpdateChecklistItem({required this.id, required this.title});
  @override
  List<Object> get props => [id, title];
}

class ToggleChecklistItem extends TaskEvent {
  final String id;
  final String taskId;
  ToggleChecklistItem({required this.id, required this.taskId});
  @override
  List<Object> get props => [id, taskId];
}

class DeleteChecklistItem extends TaskEvent {
  final String id;
  final String taskId;
  DeleteChecklistItem({required this.id, required this.taskId});
  @override
  List<Object> get props => [id];
}

class ReorderChecklistItems extends TaskEvent {
  final String taskId;
  final List<String> orderedIds;
  ReorderChecklistItems({required this.taskId, required this.orderedIds});
  @override
  List<Object> get props => [taskId, orderedIds];
}

class SetChecklistItemObsidianUri extends TaskEvent {
  final String id;
  final String taskId;
  final String? obsidianUri;
  SetChecklistItemObsidianUri({
    required this.id,
    required this.taskId,
    this.obsidianUri,
  });
  @override
  List<Object?> get props => [id, taskId, obsidianUri];
}

// --- 子任务树事件 ---
class LoadSubTree extends TaskEvent {
  final String rootTaskId;
  LoadSubTree({required this.rootTaskId});
  @override
  List<Object> get props => [rootTaskId];
}

class AddSubTask extends TaskEvent {
  final String parentId;
  final String title;
  final String projectId;
  AddSubTask({
    required this.parentId,
    required this.title,
    required this.projectId,
  });
  @override
  List<Object> get props => [parentId, title, projectId];
}

class DeleteSubTask extends TaskEvent {
  final String taskId;
  final String rootTaskId;
  DeleteSubTask({required this.taskId, required this.rootTaskId});
  @override
  List<Object> get props => [taskId, rootTaskId];
}

class MoveSubTask extends TaskEvent {
  final String taskId;
  final String? newParentId;
  final String rootTaskId;
  MoveSubTask({
    required this.taskId,
    this.newParentId,
    required this.rootTaskId,
  });
  @override
  List<Object?> get props => [taskId, newParentId, rootTaskId];
}

class ToggleSubTask extends TaskEvent {
  final String id;
  final String rootTaskId;
  ToggleSubTask({required this.id, required this.rootTaskId});
  @override
  List<Object> get props => [id, rootTaskId];
}

class ToggleTreeNode extends TaskEvent {
  final String rootTaskId;
  final String nodeId;
  ToggleTreeNode({required this.rootTaskId, required this.nodeId});
  @override
  List<Object> get props => [rootTaskId, nodeId];
}

// --- 树形拖拽事件 ---
class MoveTaskToParent extends TaskEvent {
  final String taskId;
  final String? newParentId; // null = 移为根任务
  final String? projectId;
  MoveTaskToParent({required this.taskId, this.newParentId, this.projectId});
  @override
  List<Object?> get props => [taskId, newParentId, projectId];
}

class ToggleTaskExpand extends TaskEvent {
  final String taskId;
  ToggleTaskExpand({required this.taskId});
  @override
  List<Object> get props => [taskId];
}

class ReorderTaskSiblings extends TaskEvent {
  final String? parentId; // null = 根级任务
  final List<String> orderedIds;
  ReorderTaskSiblings({this.parentId, required this.orderedIds});
  @override
  List<Object?> get props => [parentId, orderedIds];
}

class ExpandAllTasks extends TaskEvent {}

class CollapseAllTasks extends TaskEvent {}

class ToggleViewMode extends TaskEvent {}

/// 从云端拉取任务并合并到本地
class SyncFromCloud extends TaskEvent {}

class MergeSubTasksToChecklist extends TaskEvent {
  final String taskId;
  MergeSubTasksToChecklist({required this.taskId});
  @override
  List<Object> get props => [taskId];
}

class ApplyTemplate extends TaskEvent {
  final String templateProjectId;
  final String targetProjectId;
  final int startTimeMillis;
  final String? parentId;
  ApplyTemplate({
    required this.templateProjectId,
    required this.targetProjectId,
    required this.startTimeMillis,
    this.parentId,
  });
  @override
  List<Object?> get props => [
    templateProjectId,
    targetProjectId,
    startTimeMillis,
    parentId,
  ];
}

class TaskEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
