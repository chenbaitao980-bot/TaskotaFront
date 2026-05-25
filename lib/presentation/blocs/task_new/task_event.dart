import 'package:equatable/equatable.dart';

// --- 项目事件 ---
class LoadProjects extends TaskEvent {}

class CreateProject extends TaskEvent {
  final String name;
  final String color;
  CreateProject({required this.name, this.color = '#4772FA'});
  @override
  List<Object> get props => [name, color];
}

class UpdateProject extends TaskEvent {
  final String id;
  final String? name;
  final String? color;
  UpdateProject({required this.id, this.name, this.color});
  @override
  List<Object?> get props => [id, name, color];
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
  final String? filter; // 'all', 'today', 'important'
  LoadTasks({this.projectId, this.filter});
  @override
  List<Object?> get props => [projectId, filter];
}

class CreateTask extends TaskEvent {
  final String projectId;
  final String title;
  final String description;
  final int priority;
  final int? startDate;
  final int? dueDate;
  CreateTask({
    required this.projectId,
    required this.title,
    this.description = '',
    this.priority = 0,
    this.startDate,
    this.dueDate,
  });
  @override
  List<Object?> get props =>
      [projectId, title, description, priority, startDate, dueDate];
}

class UpdateTask extends TaskEvent {
  final String id;
  final String? projectId;
  final String? title;
  final String? description;
  final int? priority;
  final int? startDate;
  final int? dueDate;
  UpdateTask({
    required this.id,
    this.projectId,
    this.title,
    this.description,
    this.priority,
    this.startDate,
    this.dueDate,
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
  ToggleTaskStatus({required this.id});
  @override
  List<Object> get props => [id];
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
  AddSubTask({required this.parentId, required this.title, required this.projectId});
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
  MoveSubTask({required this.taskId, this.newParentId, required this.rootTaskId});
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

class TaskEvent extends Equatable {
  @override
  List<Object?> get props => [];
}
