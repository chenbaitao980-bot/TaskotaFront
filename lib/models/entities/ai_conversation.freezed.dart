// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ai_conversation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AiConversation _$AiConversationFromJson(Map<String, dynamic> json) {
  return _AiConversation.fromJson(json);
}

/// @nodoc
mixin _$AiConversation {
  String get id => throw _privateConstructorUsedError;
  String get userId => throw _privateConstructorUsedError;
  String get userInput => throw _privateConstructorUsedError;
  Map<String, dynamic>? get aiResponse => throw _privateConstructorUsedError;
  Map<String, dynamic>? get context => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this AiConversation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AiConversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AiConversationCopyWith<AiConversation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AiConversationCopyWith<$Res> {
  factory $AiConversationCopyWith(
    AiConversation value,
    $Res Function(AiConversation) then,
  ) = _$AiConversationCopyWithImpl<$Res, AiConversation>;
  @useResult
  $Res call({
    String id,
    String userId,
    String userInput,
    Map<String, dynamic>? aiResponse,
    Map<String, dynamic>? context,
    DateTime createdAt,
  });
}

/// @nodoc
class _$AiConversationCopyWithImpl<$Res, $Val extends AiConversation>
    implements $AiConversationCopyWith<$Res> {
  _$AiConversationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AiConversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? userInput = null,
    Object? aiResponse = freezed,
    Object? context = freezed,
    Object? createdAt = null,
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
            userInput: null == userInput
                ? _value.userInput
                : userInput // ignore: cast_nullable_to_non_nullable
                      as String,
            aiResponse: freezed == aiResponse
                ? _value.aiResponse
                : aiResponse // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            context: freezed == context
                ? _value.context
                : context // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AiConversationImplCopyWith<$Res>
    implements $AiConversationCopyWith<$Res> {
  factory _$$AiConversationImplCopyWith(
    _$AiConversationImpl value,
    $Res Function(_$AiConversationImpl) then,
  ) = __$$AiConversationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String userId,
    String userInput,
    Map<String, dynamic>? aiResponse,
    Map<String, dynamic>? context,
    DateTime createdAt,
  });
}

/// @nodoc
class __$$AiConversationImplCopyWithImpl<$Res>
    extends _$AiConversationCopyWithImpl<$Res, _$AiConversationImpl>
    implements _$$AiConversationImplCopyWith<$Res> {
  __$$AiConversationImplCopyWithImpl(
    _$AiConversationImpl _value,
    $Res Function(_$AiConversationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AiConversation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? userId = null,
    Object? userInput = null,
    Object? aiResponse = freezed,
    Object? context = freezed,
    Object? createdAt = null,
  }) {
    return _then(
      _$AiConversationImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        userId: null == userId
            ? _value.userId
            : userId // ignore: cast_nullable_to_non_nullable
                  as String,
        userInput: null == userInput
            ? _value.userInput
            : userInput // ignore: cast_nullable_to_non_nullable
                  as String,
        aiResponse: freezed == aiResponse
            ? _value._aiResponse
            : aiResponse // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        context: freezed == context
            ? _value._context
            : context // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AiConversationImpl implements _AiConversation {
  const _$AiConversationImpl({
    required this.id,
    required this.userId,
    required this.userInput,
    final Map<String, dynamic>? aiResponse,
    final Map<String, dynamic>? context,
    required this.createdAt,
  }) : _aiResponse = aiResponse,
       _context = context;

  factory _$AiConversationImpl.fromJson(Map<String, dynamic> json) =>
      _$$AiConversationImplFromJson(json);

  @override
  final String id;
  @override
  final String userId;
  @override
  final String userInput;
  final Map<String, dynamic>? _aiResponse;
  @override
  Map<String, dynamic>? get aiResponse {
    final value = _aiResponse;
    if (value == null) return null;
    if (_aiResponse is EqualUnmodifiableMapView) return _aiResponse;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final Map<String, dynamic>? _context;
  @override
  Map<String, dynamic>? get context {
    final value = _context;
    if (value == null) return null;
    if (_context is EqualUnmodifiableMapView) return _context;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'AiConversation(id: $id, userId: $userId, userInput: $userInput, aiResponse: $aiResponse, context: $context, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AiConversationImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.userId, userId) || other.userId == userId) &&
            (identical(other.userInput, userInput) ||
                other.userInput == userInput) &&
            const DeepCollectionEquality().equals(
              other._aiResponse,
              _aiResponse,
            ) &&
            const DeepCollectionEquality().equals(other._context, _context) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    userId,
    userInput,
    const DeepCollectionEquality().hash(_aiResponse),
    const DeepCollectionEquality().hash(_context),
    createdAt,
  );

  /// Create a copy of AiConversation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AiConversationImplCopyWith<_$AiConversationImpl> get copyWith =>
      __$$AiConversationImplCopyWithImpl<_$AiConversationImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AiConversationImplToJson(this);
  }
}

abstract class _AiConversation implements AiConversation {
  const factory _AiConversation({
    required final String id,
    required final String userId,
    required final String userInput,
    final Map<String, dynamic>? aiResponse,
    final Map<String, dynamic>? context,
    required final DateTime createdAt,
  }) = _$AiConversationImpl;

  factory _AiConversation.fromJson(Map<String, dynamic> json) =
      _$AiConversationImpl.fromJson;

  @override
  String get id;
  @override
  String get userId;
  @override
  String get userInput;
  @override
  Map<String, dynamic>? get aiResponse;
  @override
  Map<String, dynamic>? get context;
  @override
  DateTime get createdAt;

  /// Create a copy of AiConversation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AiConversationImplCopyWith<_$AiConversationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
