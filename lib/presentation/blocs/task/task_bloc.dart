import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../models/entities/task_breakdown.dart';
import '../../../services/supabase_service.dart';

part 'task_event.dart';
part 'task_state.dart';

class TaskBloc extends Bloc<TaskEvent, TaskState> {
  final SupabaseService _supabaseService;

  TaskBloc({required SupabaseService supabaseService})
      : _supabaseService = supabaseService,
        super(TaskInitial()) {
    on<LoadTasks>(_onLoadTasks);
    on<CreateTask>(_onCreateTask);
    on<UpdateTask>(_onUpdateTask);
    on<DeleteTask>(_onDeleteTask);
    on<UpdateTaskProgress>(_onUpdateTaskProgress);
  }

  void _onLoadTasks(LoadTasks event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    
    try {
      final tasks = await _supabaseService.getTasks(
        level: event.level,
        status: event.status,
      );
      emit(TaskLoaded(tasks: tasks));
    } catch (e) {
      emit(TaskError(message: e.toString()));
    }
  }

  void _onCreateTask(CreateTask event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    
    try {
      await _supabaseService.createTask(event.task);
      add(const LoadTasks());
    } catch (e) {
      emit(TaskError(message: e.toString()));
    }
  }

  void _onUpdateTask(UpdateTask event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    
    try {
      await _supabaseService.updateTask(event.task);
      add(const LoadTasks());
    } catch (e) {
      emit(TaskError(message: e.toString()));
    }
  }

  void _onDeleteTask(DeleteTask event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    
    try {
      await _supabaseService.deleteTask(event.id);
      add(const LoadTasks());
    } catch (e) {
      emit(TaskError(message: e.toString()));
    }
  }

  void _onUpdateTaskProgress(UpdateTaskProgress event, Emitter<TaskState> emit) async {
    emit(TaskLoading());
    
    try {
      // TODO: 更新任务进度
      add(const LoadTasks());
    } catch (e) {
      emit(TaskError(message: e.toString()));
    }
  }
}
