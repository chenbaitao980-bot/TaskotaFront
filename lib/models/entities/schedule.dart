import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

@freezed
class Schedule with _$Schedule {
  const factory Schedule({
    required String id,
    required String userId,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    @Default('P2') String priority,
    @Default(false) bool focusRequired,
    @Default(false) bool parallelizable,
    @Default('in_progress') String status,
    Map<String, dynamic>? metadata,
    @Default('manual') String source,
    String? parentTaskId,
    @Default(15) int remindBeforeMinutes,
    @Default(true) bool reminderEnabled,
    @Default(false) bool isRepeating,
    int? repeatInterval,
    @Default('once') String reminderType,
    @Default('local') String syncStatus,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);
}
