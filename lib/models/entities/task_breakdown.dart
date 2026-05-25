import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_breakdown.freezed.dart';
part 'task_breakdown.g.dart';

@freezed
class TaskBreakdown with _$TaskBreakdown {
  const factory TaskBreakdown({
    required String id,
    required String userId,
    String? parentGoalId,
    String? parentTaskId,
    String? parentScheduleId,
    required String title,
    String? description,
    required String level,
    DateTime? startDate,
    DateTime? endDate,
    @Default('pending') String status,
    @Default(0) int progress,
    @Default('P2') String priority,
    @Default(false) bool focusRequired,
    @Default(false) bool isParent,
    List<String>? dependencies,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _TaskBreakdown;

  factory TaskBreakdown.fromJson(Map<String, dynamic> json) =>
      _$TaskBreakdownFromJson(json);
}
