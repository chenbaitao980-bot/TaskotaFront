import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../models/entities/schedule.dart';
import '../../../services/supabase_service.dart';

part 'schedule_event.dart';
part 'schedule_state.dart';

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final SupabaseService _supabaseService;

  ScheduleBloc({required SupabaseService supabaseService})
      : _supabaseService = supabaseService,
        super(ScheduleInitial()) {
    on<LoadSchedules>(_onLoadSchedules);
    on<CreateSchedule>(_onCreateSchedule);
    on<UpdateSchedule>(_onUpdateSchedule);
    on<DeleteSchedule>(_onDeleteSchedule);
  }

  void _onLoadSchedules(LoadSchedules event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    
    try {
      final schedules = await _supabaseService.getSchedules(
        startDate: event.startDate,
        endDate: event.endDate,
      );
      emit(ScheduleLoaded(schedules: schedules));
    } catch (e) {
      emit(ScheduleError(message: e.toString()));
    }
  }

  void _onCreateSchedule(CreateSchedule event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    
    try {
      await _supabaseService.createSchedule(event.schedule);
      add(LoadSchedules());
    } catch (e) {
      emit(ScheduleError(message: e.toString()));
    }
  }

  void _onUpdateSchedule(UpdateSchedule event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    
    try {
      await _supabaseService.updateSchedule(event.schedule);
      add(LoadSchedules());
    } catch (e) {
      emit(ScheduleError(message: e.toString()));
    }
  }

  void _onDeleteSchedule(DeleteSchedule event, Emitter<ScheduleState> emit) async {
    emit(ScheduleLoading());
    
    try {
      await _supabaseService.deleteSchedule(event.id);
      add(LoadSchedules());
    } catch (e) {
      emit(ScheduleError(message: e.toString()));
    }
  }
}
