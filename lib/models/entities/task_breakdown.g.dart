// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_breakdown.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TaskBreakdownImpl _$$TaskBreakdownImplFromJson(Map<String, dynamic> json) =>
    _$TaskBreakdownImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      parentGoalId: json['parentGoalId'] as String?,
      parentScheduleId: json['parentScheduleId'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      level: json['level'] as String,
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      status: json['status'] as String? ?? 'pending',
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      priority: json['priority'] as String? ?? 'P2',
      focusRequired: json['focusRequired'] as bool? ?? false,
      dependencies: (json['dependencies'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$TaskBreakdownImplToJson(_$TaskBreakdownImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'parentGoalId': instance.parentGoalId,
      'parentScheduleId': instance.parentScheduleId,
      'title': instance.title,
      'description': instance.description,
      'level': instance.level,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'status': instance.status,
      'progress': instance.progress,
      'priority': instance.priority,
      'focusRequired': instance.focusRequired,
      'dependencies': instance.dependencies,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
