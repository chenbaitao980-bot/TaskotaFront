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
      status: json['status'] as String? ?? 'in_progress',
      metadata: json['metadata'] as Map<String, dynamic>?,
      source: json['source'] as String? ?? 'manual',
      parentTaskId: json['parentTaskId'] as String?,
      remindBeforeMinutes: (json['remindBeforeMinutes'] as num?)?.toInt() ?? 15,
      reminderEnabled: json['reminderEnabled'] as bool? ?? true,
      isRepeating: json['isRepeating'] as bool? ?? false,
      repeatInterval: (json['repeatInterval'] as num?)?.toInt(),
      reminderType: json['reminderType'] as String? ?? 'once',
      syncStatus: json['syncStatus'] as String? ?? 'local',
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
      'status': instance.status,
      'metadata': instance.metadata,
      'source': instance.source,
      'parentTaskId': instance.parentTaskId,
      'remindBeforeMinutes': instance.remindBeforeMinutes,
      'reminderEnabled': instance.reminderEnabled,
      'isRepeating': instance.isRepeating,
      'repeatInterval': instance.repeatInterval,
      'reminderType': instance.reminderType,
      'syncStatus': instance.syncStatus,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
