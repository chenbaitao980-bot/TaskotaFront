part of 'task_bloc.dart';

abstract class TaskEvent extends Equatable {
  const TaskEvent();

  @override
  List<Object?> get props => [];
}

class LoadTasks extends TaskEvent {
  final String? level;
  final String? status;

  const LoadTasks({this.level, this.status});

  @override
  List<Object?> get props => [level, status];
}

class CreateTask extends TaskEvent {
  final TaskBreakdown task;

  const CreateTask({required this.task});

  @override
  List<Object?> get props => [task];
}

class UpdateTask extends TaskEvent {
  final TaskBreakdown task;

  const UpdateTask({required this.task});

  @override
  List<Object?> get props => [task];
}

class DeleteTask extends TaskEvent {
  final String id;

  const DeleteTask({required this.id});

  @override
  List<Object?> get props => [id];
}

class UpdateTaskProgress extends TaskEvent {
  final String taskId;
  final int progress;

  const UpdateTaskProgress({
    required this.taskId,
    required this.progress,
  });

  @override
  List<Object?> get props => [taskId, progress];
}
