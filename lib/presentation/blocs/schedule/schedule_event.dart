part of 'schedule_bloc.dart';

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class LoadSchedules extends ScheduleEvent {
  final DateTime? startDate;
  final DateTime? endDate;

  const LoadSchedules({this.startDate, this.endDate});

  @override
  List<Object?> get props => [startDate, endDate];
}

class CreateSchedule extends ScheduleEvent {
  final Schedule schedule;

  const CreateSchedule({required this.schedule});

  @override
  List<Object?> get props => [schedule];
}

class UpdateSchedule extends ScheduleEvent {
  final Schedule schedule;

  const UpdateSchedule({required this.schedule});

  @override
  List<Object?> get props => [schedule];
}

class DeleteSchedule extends ScheduleEvent {
  final String id;

  const DeleteSchedule({required this.id});

  @override
  List<Object?> get props => [id];
}
