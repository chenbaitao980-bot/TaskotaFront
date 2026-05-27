// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Schedule _$ScheduleFromJson(Map<String, dynamic> json) {
  return _Schedule.fromJson(json);
}

/// @nodoc
mixin _$Schedule {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  DateTime get startTime => throw _privateConstructorUsedError;
  DateTime get endTime => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  bool get focusRequired => throw _privateConstructorUsedError;
  bool get parallelizable => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  Map<String, dynamic>? get metadata => throw _privateConstructorUsedError;
  String get source => throw _privateConstructorUsedError;
  String? get parentTaskId => throw _privateConstructorUsedError;
  int get remindBeforeMinutes => throw _privateConstructorUsedError;
  bool get reminderEnabled => throw _privateConstructorUsedError;
  bool get isRepeating => throw _privateConstructorUsedError;
  int? get repeatInterval => throw _privateConstructorUsedError;
  String get reminderType => throw _privateConstructorUsedError;
  String get syncStatus => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this Schedule to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ScheduleCopyWith<Schedule> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ScheduleCopyWith<$Res> {
  factory $ScheduleCopyWith(Schedule value, $Res Function(Schedule) then) =
      _$ScheduleCopyWithImpl<$Res, Schedule>;
  @useResult
  $Res call({
    String id,
    String userId,
    String title,
    String? description,
    DateTime startTime,
    DateTime endTime,
    String priority,
    bool focusRequired,
    bool parallelizable,
    String status,
    Map<String, dynamic>? metadata,
    String source,
    String? parentTaskId,
    int remindBeforeMinutes,
    bool reminderEnabled,
    bool isRepeating,
    int? repeatInterval,
    String reminderType,
    String syncStatus,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$ScheduleCopyWithImpl<$Res, $Val extends Schedule>
    implements $ScheduleCopyWith<$Res> {
  _$ScheduleCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = freezed,
    Object? startTime = null,
    Object? endTime = null,
    Object? priority = null,
    Object? focusRequired = null,
    Object? parallelizable = null,
    Object? status = null,
    Object? metadata = freezed,
    Object? source = null,
    Object? parentTaskId = freezed,
    Object? remindBeforeMinutes = null,
    Object? reminderEnabled = null,
    Object? isRepeating = null,
    Object? repeatInterval = freezed,
    Object? reminderType = null,
    Object? syncStatus = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            userId: null == userId
                ? _value.userId
                : userId // ignore: cast_nullable_to_non_nullable
                      as String,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            startTime: null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endTime: null == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as String,
            focusRequired: null == focusRequired
                ? _value.focusRequired
                : focusRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
            parallelizable: null == parallelizable
                ? _value.parallelizable
                : parallelizable // ignore: cast_nullable_to_non_nullable
                      as bool,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            metadata: freezed == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            source: null == source
                ? _value.source
                : source // ignore: cast_nullable_to_non_nullable
                      as String,
            parentTaskId: freezed == parentTaskId
                ? _value.parentTaskId
                : parentTaskId // ignore: cast_nullable_to_non_nullable
                      as String?,
            remindBeforeMinutes: null == remindBeforeMinutes
                ? _value.remindBeforeMinutes
                : remindBeforeMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            reminderEnabled: null == reminderEnabled
                ? _value.reminderEnabled
                : reminderEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            isRepeating: null == isRepeating
                ? _value.isRepeating
                : isRepeating // ignore: cast_nullable_to_non_nullable
                      as bool,
            repeatInterval: freezed == repeatInterval
                ? _value.repeatInterval
                : repeatInterval // ignore: cast_nullable_to_non_nullable
                      as int?,
            reminderType: null == reminderType
                ? _value.reminderType
                : reminderType // ignore: cast_nullable_to_non_nullable
                      as String,
            syncStatus: null == syncStatus
                ? _value.syncStatus
                : syncStatus // ignore: cast_nullable_to_non_nullable
                      as String,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ScheduleImplCopyWith<$Res>
    implements $ScheduleCopyWith<$Res> {
  factory _$$ScheduleImplCopyWith(
    _$ScheduleImpl value,
    $Res Function(_$ScheduleImpl) then,
  ) = __$$ScheduleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String title,
    String? description,
    DateTime startTime,
    DateTime endTime,
    String priority,
    bool focusRequired,
    bool parallelizable,
    String status,
    Map<String, dynamic>? metadata,
    String source,
    String? parentTaskId,
    int remindBeforeMinutes,
    bool reminderEnabled,
    bool isRepeating,
    int? repeatInterval,
    String reminderType,
    String syncStatus,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$ScheduleImplCopyWithImpl<$Res>
    extends _$ScheduleCopyWithImpl<$Res, _$ScheduleImpl>
    implements _$$ScheduleImplCopyWith<$Res> {
  __$$ScheduleImplCopyWithImpl(
    _$ScheduleImpl _value,
    $Res Function(_$ScheduleImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? title = null,
    Object? description = freezed,
    Object? startTime = null,
    Object? endTime = null,
    Object? priority = null,
    Object? focusRequired = null,
    Object? parallelizable = null,
    Object? status = null,
    Object? metadata = freezed,
    Object? source = null,
    Object? parentTaskId = freezed,
    Object? remindBeforeMinutes = null,
    Object? reminderEnabled = null,
    Object? isRepeating = null,
    Object? repeatInterval = freezed,
    Object? reminderType = null,
    Object? syncStatus = null,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$ScheduleImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        startTime: null == startTime
            ? _value.startTime
            : startTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endTime: null == endTime
            ? _value.endTime
            : endTime // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as String,
        focusRequired: null == focusRequired
            ? _value.focusRequired
            : focusRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        parallelizable: null == parallelizable
            ? _value.parallelizable
            : parallelizable // ignore: cast_nullable_to_non_nullable
                  as bool,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        metadata: freezed == metadata
            ? _value._metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        source: null == source
            ? _value.source
            : source // ignore: cast_nullable_to_non_nullable
                  as String,
        parentTaskId: freezed == parentTaskId
            ? _value.parentTaskId
            : parentTaskId // ignore: cast_nullable_to_non_nullable
                  as String?,
        remindBeforeMinutes: null == remindBeforeMinutes
            ? _value.remindBeforeMinutes
            : remindBeforeMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        reminderEnabled: null == reminderEnabled
            ? _value.reminderEnabled
            : reminderEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        isRepeating: null == isRepeating
            ? _value.isRepeating
            : isRepeating // ignore: cast_nullable_to_non_nullable
                  as bool,
        repeatInterval: freezed == repeatInterval
            ? _value.repeatInterval
            : repeatInterval // ignore: cast_nullable_to_non_nullable
                  as int?,
        reminderType: null == reminderType
            ? _value.reminderType
            : reminderType // ignore: cast_nullable_to_non_nullable
                  as String,
        syncStatus: null == syncStatus
            ? _value.syncStatus
            : syncStatus // ignore: cast_nullable_to_non_nullable
                  as String,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ScheduleImpl implements _Schedule {
  const _$ScheduleImpl({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.priority = 'P2',
    this.focusRequired = false,
    this.parallelizable = false,
    this.status = 'in_progress',
    final Map<String, dynamic>? metadata,
    this.source = 'manual',
    this.parentTaskId,
    this.remindBeforeMinutes = 15,
    this.reminderEnabled = true,
    this.isRepeating = false,
    this.repeatInterval,
    this.reminderType = 'once',
    this.syncStatus = 'local',
    required this.createdAt,
    required this.updatedAt,
  }) : _metadata = metadata;

  factory _$ScheduleImpl.fromJson(Map<String, dynamic> json) =>
      _$$ScheduleImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String title;
  @override
  final String? description;
  @override
  final DateTime startTime;
  @override
  final DateTime endTime;
  @override
  @JsonKey()
  final String priority;
  @override
  @JsonKey()
  final bool focusRequired;
  @override
  @JsonKey()
  final bool parallelizable;
  @override
  @JsonKey()
  final String status;
  final Map<String, dynamic>? _metadata;
  @override
  Map<String, dynamic>? get metadata {
    final value = _metadata;
    if (value == null) return null;
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final String source;
  @override
  final String? parentTaskId;
  @override
  @JsonKey()
  final int remindBeforeMinutes;
  @override
  @JsonKey()
  final bool reminderEnabled;
  @override
  @JsonKey()
  final bool isRepeating;
  @override
  final int? repeatInterval;
  @override
  @JsonKey()
  final String reminderType;
  @override
  @JsonKey()
  final String syncStatus;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'Schedule(id: $id, userId: $userId, title: $title, description: $description, startTime: $startTime, endTime: $endTime, priority: $priority, focusRequired: $focusRequired, parallelizable: $parallelizable, status: $status, metadata: $metadata, source: $source, parentTaskId: $parentTaskId, remindBeforeMinutes: $remindBeforeMinutes, reminderEnabled: $reminderEnabled, isRepeating: $isRepeating, repeatInterval: $repeatInterval, reminderType: $reminderType, syncStatus: $syncStatus, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ScheduleImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.focusRequired, focusRequired) ||
                other.focusRequired == focusRequired) &&
            (identical(other.parallelizable, parallelizable) ||
                other.parallelizable == parallelizable) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.source, source) || other.source == source) &&
            (identical(other.parentTaskId, parentTaskId) ||
                other.parentTaskId == parentTaskId) &&
            (identical(other.remindBeforeMinutes, remindBeforeMinutes) ||
                other.remindBeforeMinutes == remindBeforeMinutes) &&
            (identical(other.reminderEnabled, reminderEnabled) ||
                other.reminderEnabled == reminderEnabled) &&
            (identical(other.isRepeating, isRepeating) ||
                other.isRepeating == isRepeating) &&
            (identical(other.repeatInterval, repeatInterval) ||
                other.repeatInterval == repeatInterval) &&
            (identical(other.reminderType, reminderType) ||
                other.reminderType == reminderType) &&
            (identical(other.syncStatus, syncStatus) ||
                other.syncStatus == syncStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    userId,
    title,
    description,
    startTime,
    endTime,
    priority,
    focusRequired,
    parallelizable,
    status,
    const DeepCollectionEquality().hash(_metadata),
    source,
    parentTaskId,
    remindBeforeMinutes,
    reminderEnabled,
    isRepeating,
    repeatInterval,
    reminderType,
    syncStatus,
    createdAt,
    updatedAt,
  ]);

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ScheduleImplCopyWith<_$ScheduleImpl> get copyWith =>
      __$$ScheduleImplCopyWithImpl<_$ScheduleImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ScheduleImplToJson(this);
  }
}

abstract class _Schedule implements Schedule {
  const factory _Schedule({
    required final String id,
    required final String userId,
    required final String title,
    final String? description,
    required final DateTime startTime,
    required final DateTime endTime,
    final String priority,
    final bool focusRequired,
    final bool parallelizable,
    final String status,
    final Map<String, dynamic>? metadata,
    final String source,
    final String? parentTaskId,
    final int remindBeforeMinutes,
    final bool reminderEnabled,
    final bool isRepeating,
    final int? repeatInterval,
    final String reminderType,
    final String syncStatus,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$ScheduleImpl;

  factory _Schedule.fromJson(Map<String, dynamic> json) =
      _$ScheduleImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get title;
  @override
  String? get description;
  @override
  DateTime get startTime;
  @override
  DateTime get endTime;
  @override
  String get priority;
  @override
  bool get focusRequired;
  @override
  bool get parallelizable;
  @override
  String get status;
  @override
  Map<String, dynamic>? get metadata;
  @override
  String get source;
  @override
  String? get parentTaskId;
  @override
  int get remindBeforeMinutes;
  @override
  bool get reminderEnabled;
  @override
  bool get isRepeating;
  @override
  int? get repeatInterval;
  @override
  String get reminderType;
  @override
  String get syncStatus;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of Schedule
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ScheduleImplCopyWith<_$ScheduleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
