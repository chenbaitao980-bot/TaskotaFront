// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_breakdown.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TaskBreakdown _$TaskBreakdownFromJson(Map<String, dynamic> json) {
  return _TaskBreakdown.fromJson(json);
}

/// @nodoc
mixin _$TaskBreakdown {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String? get parentGoalId => throw _privateConstructorUsedError;
  String? get parentScheduleId => throw _privateConstructorUsedError;
  String get title => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get level => throw _privateConstructorUsedError;
  DateTime? get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  int get progress => throw _privateConstructorUsedError;
  String get priority => throw _privateConstructorUsedError;
  bool get focusRequired => throw _privateConstructorUsedError;
  List<String>? get dependencies => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this TaskBreakdown to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TaskBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TaskBreakdownCopyWith<TaskBreakdown> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TaskBreakdownCopyWith<$Res> {
  factory $TaskBreakdownCopyWith(
    TaskBreakdown value,
    $Res Function(TaskBreakdown) then,
  ) = _$TaskBreakdownCopyWithImpl<$Res, TaskBreakdown>;
  @useResult
  $Res call({
    String id,
    String userId,
    String? parentGoalId,
    String? parentScheduleId,
    String title,
    String? description,
    String level,
    DateTime? startDate,
    DateTime? endDate,
    String status,
    int progress,
    String priority,
    bool focusRequired,
    List<String>? dependencies,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$TaskBreakdownCopyWithImpl<$Res, $Val extends TaskBreakdown>
    implements $TaskBreakdownCopyWith<$Res> {
  _$TaskBreakdownCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TaskBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? parentGoalId = freezed,
    Object? parentScheduleId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? level = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? status = null,
    Object? progress = null,
    Object? priority = null,
    Object? focusRequired = null,
    Object? dependencies = freezed,
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
            parentGoalId: freezed == parentGoalId
                ? _value.parentGoalId
                : parentGoalId // ignore: cast_nullable_to_non_nullable
                      as String?,
            parentScheduleId: freezed == parentScheduleId
                ? _value.parentScheduleId
                : parentScheduleId // ignore: cast_nullable_to_non_nullable
                      as String?,
            title: null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            level: null == level
                ? _value.level
                : level // ignore: cast_nullable_to_non_nullable
                      as String,
            startDate: freezed == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            endDate: freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                      as DateTime?,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            progress: null == progress
                ? _value.progress
                : progress // ignore: cast_nullable_to_non_nullable
                      as int,
            priority: null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                      as String,
            focusRequired: null == focusRequired
                ? _value.focusRequired
                : focusRequired // ignore: cast_nullable_to_non_nullable
                      as bool,
            dependencies: freezed == dependencies
                ? _value.dependencies
                : dependencies // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
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
abstract class _$$TaskBreakdownImplCopyWith<$Res>
    implements $TaskBreakdownCopyWith<$Res> {
  factory _$$TaskBreakdownImplCopyWith(
    _$TaskBreakdownImpl value,
    $Res Function(_$TaskBreakdownImpl) then,
  ) = __$$TaskBreakdownImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String? parentGoalId,
    String? parentScheduleId,
    String title,
    String? description,
    String level,
    DateTime? startDate,
    DateTime? endDate,
    String status,
    int progress,
    String priority,
    bool focusRequired,
    List<String>? dependencies,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$TaskBreakdownImplCopyWithImpl<$Res>
    extends _$TaskBreakdownCopyWithImpl<$Res, _$TaskBreakdownImpl>
    implements _$$TaskBreakdownImplCopyWith<$Res> {
  __$$TaskBreakdownImplCopyWithImpl(
    _$TaskBreakdownImpl _value,
    $Res Function(_$TaskBreakdownImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TaskBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? parentGoalId = freezed,
    Object? parentScheduleId = freezed,
    Object? title = null,
    Object? description = freezed,
    Object? level = null,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? status = null,
    Object? progress = null,
    Object? priority = null,
    Object? focusRequired = null,
    Object? dependencies = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$TaskBreakdownImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        parentGoalId: freezed == parentGoalId
            ? _value.parentGoalId
            : parentGoalId // ignore: cast_nullable_to_non_nullable
                  as String?,
        parentScheduleId: freezed == parentScheduleId
            ? _value.parentScheduleId
            : parentScheduleId // ignore: cast_nullable_to_non_nullable
                  as String?,
        title: null == title
            ? _value.title
            : title // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        level: null == level
            ? _value.level
            : level // ignore: cast_nullable_to_non_nullable
                  as String,
        startDate: freezed == startDate
            ? _value.startDate
            : startDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        endDate: freezed == endDate
            ? _value.endDate
            : endDate // ignore: cast_nullable_to_non_nullable
                  as DateTime?,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        progress: null == progress
            ? _value.progress
            : progress // ignore: cast_nullable_to_non_nullable
                  as int,
        priority: null == priority
            ? _value.priority
            : priority // ignore: cast_nullable_to_non_nullable
                  as String,
        focusRequired: null == focusRequired
            ? _value.focusRequired
            : focusRequired // ignore: cast_nullable_to_non_nullable
                  as bool,
        dependencies: freezed == dependencies
            ? _value._dependencies
            : dependencies // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
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
class _$TaskBreakdownImpl implements _TaskBreakdown {
  const _$TaskBreakdownImpl({
    required this.id,
    required this.userId,
    this.parentGoalId,
    this.parentScheduleId,
    required this.title,
    this.description,
    required this.level,
    this.startDate,
    this.endDate,
    this.status = 'pending',
    this.progress = 0,
    this.priority = 'P2',
    this.focusRequired = false,
    final List<String>? dependencies,
    required this.createdAt,
    required this.updatedAt,
  }) : _dependencies = dependencies;

  factory _$TaskBreakdownImpl.fromJson(Map<String, dynamic> json) =>
      _$$TaskBreakdownImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String? parentGoalId;
  @override
  final String? parentScheduleId;
  @override
  final String title;
  @override
  final String? description;
  @override
  final String level;
  @override
  final DateTime? startDate;
  @override
  final DateTime? endDate;
  @override
  @JsonKey()
  final String status;
  @override
  @JsonKey()
  final int progress;
  @override
  @JsonKey()
  final String priority;
  @override
  @JsonKey()
  final bool focusRequired;
  final List<String>? _dependencies;
  @override
  List<String>? get dependencies {
    final value = _dependencies;
    if (value == null) return null;
    if (_dependencies is EqualUnmodifiableListView) return _dependencies;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'TaskBreakdown(id: $id, userId: $userId, parentGoalId: $parentGoalId, parentScheduleId: $parentScheduleId, title: $title, description: $description, level: $level, startDate: $startDate, endDate: $endDate, status: $status, progress: $progress, priority: $priority, focusRequired: $focusRequired, dependencies: $dependencies, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TaskBreakdownImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.parentGoalId, parentGoalId) ||
                other.parentGoalId == parentGoalId) &&
            (identical(other.parentScheduleId, parentScheduleId) ||
                other.parentScheduleId == parentScheduleId) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.level, level) || other.level == level) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.progress, progress) ||
                other.progress == progress) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.focusRequired, focusRequired) ||
                other.focusRequired == focusRequired) &&
            const DeepCollectionEquality().equals(
              other._dependencies,
              _dependencies,
            ) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    parentGoalId,
    parentScheduleId,
    title,
    description,
    level,
    startDate,
    endDate,
    status,
    progress,
    priority,
    focusRequired,
    const DeepCollectionEquality().hash(_dependencies),
    createdAt,
    updatedAt,
  );

  /// Create a copy of TaskBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TaskBreakdownImplCopyWith<_$TaskBreakdownImpl> get copyWith =>
      __$$TaskBreakdownImplCopyWithImpl<_$TaskBreakdownImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TaskBreakdownImplToJson(this);
  }
}

abstract class _TaskBreakdown implements TaskBreakdown {
  const factory _TaskBreakdown({
    required final String id,
    required final String userId,
    final String? parentGoalId,
    final String? parentScheduleId,
    required final String title,
    final String? description,
    required final String level,
    final DateTime? startDate,
    final DateTime? endDate,
    final String status,
    final int progress,
    final String priority,
    final bool focusRequired,
    final List<String>? dependencies,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$TaskBreakdownImpl;

  factory _TaskBreakdown.fromJson(Map<String, dynamic> json) =
      _$TaskBreakdownImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String? get parentGoalId;
  @override
  String? get parentScheduleId;
  @override
  String get title;
  @override
  String? get description;
  @override
  String get level;
  @override
  DateTime? get startDate;
  @override
  DateTime? get endDate;
  @override
  String get status;
  @override
  int get progress;
  @override
  String get priority;
  @override
  bool get focusRequired;
  @override
  List<String>? get dependencies;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of TaskBreakdown
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TaskBreakdownImplCopyWith<_$TaskBreakdownImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
