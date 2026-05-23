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
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);
}
