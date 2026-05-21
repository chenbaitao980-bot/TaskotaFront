// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ScheduleImpl _$$ScheduleImplFromJson(Map<String, dynamic> json) =>
    _$ScheduleImpl(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      priority: json['priority'] as String? ?? 'P2',
      focusRequired: json['focusRequired'] as bool? ?? false,
      parallelizable: json['parallelizable'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
      source: json['source'] as String? ?? 'manual',
      parentTaskId: json['parentTaskId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ScheduleImplToJson(_$ScheduleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'title': instance.title,
      'description': instance.description,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'priority': instance.priority,
      'focusRequired': instance.focusRequired,
      'parallelizable': instance.parallelizable,
      'metadata': instance.metadata,
      'source': instance.source,
      'parentTaskId': instance.parentTaskId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
