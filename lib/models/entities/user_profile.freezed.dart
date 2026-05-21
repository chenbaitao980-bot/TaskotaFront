// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) {
  return _UserProfile.fromJson(json);
}

/// @nodoc
mixin _$UserProfile {
  String get id => throw _privateConstructorUsedError;
  String? get displayName => throw _privateConstructorUsedError;
  Map<String, dynamic>? get explicitProfile =>
      throw _privateConstructorUsedError;
  Map<String, dynamic>? get implicitProfile =>
      throw _privateConstructorUsedError;
  Map<String, dynamic>? get encryptedData => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Serializes this UserProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileCopyWith<UserProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileCopyWith<$Res> {
  factory $UserProfileCopyWith(
    UserProfile value,
    $Res Function(UserProfile) then,
  ) = _$UserProfileCopyWithImpl<$Res, UserProfile>;
  @useResult
  $Res call({
    String id,
    String? displayName,
    Map<String, dynamic>? explicitProfile,
    Map<String, dynamic>? implicitProfile,
    Map<String, dynamic>? encryptedData,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class _$UserProfileCopyWithImpl<$Res, $Val extends UserProfile>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = freezed,
    Object? explicitProfile = freezed,
    Object? implicitProfile = freezed,
    Object? encryptedData = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: freezed == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String?,
            explicitProfile: freezed == explicitProfile
                ? _value.explicitProfile
                : explicitProfile // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            implicitProfile: freezed == implicitProfile
                ? _value.implicitProfile
                : implicitProfile // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
            encryptedData: freezed == encryptedData
                ? _value.encryptedData
                : encryptedData // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>?,
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
abstract class _$$UserProfileImplCopyWith<$Res>
    implements $UserProfileCopyWith<$Res> {
  factory _$$UserProfileImplCopyWith(
    _$UserProfileImpl value,
    $Res Function(_$UserProfileImpl) then,
  ) = __$$UserProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String? displayName,
    Map<String, dynamic>? explicitProfile,
    Map<String, dynamic>? implicitProfile,
    Map<String, dynamic>? encryptedData,
    DateTime createdAt,
    DateTime updatedAt,
  });
}

/// @nodoc
class __$$UserProfileImplCopyWithImpl<$Res>
    extends _$UserProfileCopyWithImpl<$Res, _$UserProfileImpl>
    implements _$$UserProfileImplCopyWith<$Res> {
  __$$UserProfileImplCopyWithImpl(
    _$UserProfileImpl _value,
    $Res Function(_$UserProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? displayName = freezed,
    Object? explicitProfile = freezed,
    Object? implicitProfile = freezed,
    Object? encryptedData = freezed,
    Object? createdAt = null,
    Object? updatedAt = null,
  }) {
    return _then(
      _$UserProfileImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: freezed == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String?,
        explicitProfile: freezed == explicitProfile
            ? _value._explicitProfile
            : explicitProfile // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        implicitProfile: freezed == implicitProfile
            ? _value._implicitProfile
            : implicitProfile // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
        encryptedData: freezed == encryptedData
            ? _value._encryptedData
            : encryptedData // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>?,
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
class _$UserProfileImpl implements _UserProfile {
  const _$UserProfileImpl({
    required this.id,
    this.displayName,
    final Map<String, dynamic>? explicitProfile,
    final Map<String, dynamic>? implicitProfile,
    final Map<String, dynamic>? encryptedData,
    required this.createdAt,
    required this.updatedAt,
  }) : _explicitProfile = explicitProfile,
       _implicitProfile = implicitProfile,
       _encryptedData = encryptedData;

  factory _$UserProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserProfileImplFromJson(json);

  @override
  final String id;
  @override
  final String? displayName;
  final Map<String, dynamic>? _explicitProfile;
  @override
  Map<String, dynamic>? get explicitProfile {
    final value = _explicitProfile;
    if (value == null) return null;
    if (_explicitProfile is EqualUnmodifiableMapView) return _explicitProfile;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final Map<String, dynamic>? _implicitProfile;
  @override
  Map<String, dynamic>? get implicitProfile {
    final value = _implicitProfile;
    if (value == null) return null;
    if (_implicitProfile is EqualUnmodifiableMapView) return _implicitProfile;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final Map<String, dynamic>? _encryptedData;
  @override
  Map<String, dynamic>? get encryptedData {
    final value = _encryptedData;
    if (value == null) return null;
    if (_encryptedData is EqualUnmodifiableMapView) return _encryptedData;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  String toString() {
    return 'UserProfile(id: $id, displayName: $displayName, explicitProfile: $explicitProfile, implicitProfile: $implicitProfile, encryptedData: $encryptedData, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            const DeepCollectionEquality().equals(
              other._explicitProfile,
              _explicitProfile,
            ) &&
            const DeepCollectionEquality().equals(
              other._implicitProfile,
              _implicitProfile,
            ) &&
            const DeepCollectionEquality().equals(
              other._encryptedData,
              _encryptedData,
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
    displayName,
    const DeepCollectionEquality().hash(_explicitProfile),
    const DeepCollectionEquality().hash(_implicitProfile),
    const DeepCollectionEquality().hash(_encryptedData),
    createdAt,
    updatedAt,
  );

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      __$$UserProfileImplCopyWithImpl<_$UserProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserProfileImplToJson(this);
  }
}

abstract class _UserProfile implements UserProfile {
  const factory _UserProfile({
    required final String id,
    final String? displayName,
    final Map<String, dynamic>? explicitProfile,
    final Map<String, dynamic>? implicitProfile,
    final Map<String, dynamic>? encryptedData,
    required final DateTime createdAt,
    required final DateTime updatedAt,
  }) = _$UserProfileImpl;

  factory _UserProfile.fromJson(Map<String, dynamic> json) =
      _$UserProfileImpl.fromJson;

  @override
  String get id;
  @override
  String? get displayName;
  @override
  Map<String, dynamic>? get explicitProfile;
  @override
  Map<String, dynamic>? get implicitProfile;
  @override
  Map<String, dynamic>? get encryptedData;
  @override
  DateTime get createdAt;
  @override
  DateTime get updatedAt;

  /// Create a copy of UserProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileImplCopyWith<_$UserProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ExplicitProfile _$ExplicitProfileFromJson(Map<String, dynamic> json) {
  return _ExplicitProfile.fromJson(json);
}

/// @nodoc
mixin _$ExplicitProfile {
  String? get name => throw _privateConstructorUsedError;
  String? get occupation => throw _privateConstructorUsedError;
  String? get incomeLevel => throw _privateConstructorUsedError;
  List<String>? get primaryGoals => throw _privateConstructorUsedError;
  String? get city => throw _privateConstructorUsedError;
  String? get targetExamCity => throw _privateConstructorUsedError;

  /// Serializes this ExplicitProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ExplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ExplicitProfileCopyWith<ExplicitProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ExplicitProfileCopyWith<$Res> {
  factory $ExplicitProfileCopyWith(
    ExplicitProfile value,
    $Res Function(ExplicitProfile) then,
  ) = _$ExplicitProfileCopyWithImpl<$Res, ExplicitProfile>;
  @useResult
  $Res call({
    String? name,
    String? occupation,
    String? incomeLevel,
    List<String>? primaryGoals,
    String? city,
    String? targetExamCity,
  });
}

/// @nodoc
class _$ExplicitProfileCopyWithImpl<$Res, $Val extends ExplicitProfile>
    implements $ExplicitProfileCopyWith<$Res> {
  _$ExplicitProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ExplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? occupation = freezed,
    Object? incomeLevel = freezed,
    Object? primaryGoals = freezed,
    Object? city = freezed,
    Object? targetExamCity = freezed,
  }) {
    return _then(
      _value.copyWith(
            name: freezed == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String?,
            occupation: freezed == occupation
                ? _value.occupation
                : occupation // ignore: cast_nullable_to_non_nullable
                      as String?,
            incomeLevel: freezed == incomeLevel
                ? _value.incomeLevel
                : incomeLevel // ignore: cast_nullable_to_non_nullable
                      as String?,
            primaryGoals: freezed == primaryGoals
                ? _value.primaryGoals
                : primaryGoals // ignore: cast_nullable_to_non_nullable
                      as List<String>?,
            city: freezed == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String?,
            targetExamCity: freezed == targetExamCity
                ? _value.targetExamCity
                : targetExamCity // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ExplicitProfileImplCopyWith<$Res>
    implements $ExplicitProfileCopyWith<$Res> {
  factory _$$ExplicitProfileImplCopyWith(
    _$ExplicitProfileImpl value,
    $Res Function(_$ExplicitProfileImpl) then,
  ) = __$$ExplicitProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? name,
    String? occupation,
    String? incomeLevel,
    List<String>? primaryGoals,
    String? city,
    String? targetExamCity,
  });
}

/// @nodoc
class __$$ExplicitProfileImplCopyWithImpl<$Res>
    extends _$ExplicitProfileCopyWithImpl<$Res, _$ExplicitProfileImpl>
    implements _$$ExplicitProfileImplCopyWith<$Res> {
  __$$ExplicitProfileImplCopyWithImpl(
    _$ExplicitProfileImpl _value,
    $Res Function(_$ExplicitProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ExplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = freezed,
    Object? occupation = freezed,
    Object? incomeLevel = freezed,
    Object? primaryGoals = freezed,
    Object? city = freezed,
    Object? targetExamCity = freezed,
  }) {
    return _then(
      _$ExplicitProfileImpl(
        name: freezed == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String?,
        occupation: freezed == occupation
            ? _value.occupation
            : occupation // ignore: cast_nullable_to_non_nullable
                  as String?,
        incomeLevel: freezed == incomeLevel
            ? _value.incomeLevel
            : incomeLevel // ignore: cast_nullable_to_non_nullable
                  as String?,
        primaryGoals: freezed == primaryGoals
            ? _value._primaryGoals
            : primaryGoals // ignore: cast_nullable_to_non_nullable
                  as List<String>?,
        city: freezed == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String?,
        targetExamCity: freezed == targetExamCity
            ? _value.targetExamCity
            : targetExamCity // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ExplicitProfileImpl implements _ExplicitProfile {
  const _$ExplicitProfileImpl({
    this.name,
    this.occupation,
    this.incomeLevel,
    final List<String>? primaryGoals,
    this.city,
    this.targetExamCity,
  }) : _primaryGoals = primaryGoals;

  factory _$ExplicitProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$ExplicitProfileImplFromJson(json);

  @override
  final String? name;
  @override
  final String? occupation;
  @override
  final String? incomeLevel;
  final List<String>? _primaryGoals;
  @override
  List<String>? get primaryGoals {
    final value = _primaryGoals;
    if (value == null) return null;
    if (_primaryGoals is EqualUnmodifiableListView) return _primaryGoals;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? city;
  @override
  final String? targetExamCity;

  @override
  String toString() {
    return 'ExplicitProfile(name: $name, occupation: $occupation, incomeLevel: $incomeLevel, primaryGoals: $primaryGoals, city: $city, targetExamCity: $targetExamCity)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ExplicitProfileImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.occupation, occupation) ||
                other.occupation == occupation) &&
            (identical(other.incomeLevel, incomeLevel) ||
                other.incomeLevel == incomeLevel) &&
            const DeepCollectionEquality().equals(
              other._primaryGoals,
              _primaryGoals,
            ) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.targetExamCity, targetExamCity) ||
                other.targetExamCity == targetExamCity));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    occupation,
    incomeLevel,
    const DeepCollectionEquality().hash(_primaryGoals),
    city,
    targetExamCity,
  );

  /// Create a copy of ExplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ExplicitProfileImplCopyWith<_$ExplicitProfileImpl> get copyWith =>
      __$$ExplicitProfileImplCopyWithImpl<_$ExplicitProfileImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ExplicitProfileImplToJson(this);
  }
}

abstract class _ExplicitProfile implements ExplicitProfile {
  const factory _ExplicitProfile({
    final String? name,
    final String? occupation,
    final String? incomeLevel,
    final List<String>? primaryGoals,
    final String? city,
    final String? targetExamCity,
  }) = _$ExplicitProfileImpl;

  factory _ExplicitProfile.fromJson(Map<String, dynamic> json) =
      _$ExplicitProfileImpl.fromJson;

  @override
  String? get name;
  @override
  String? get occupation;
  @override
  String? get incomeLevel;
  @override
  List<String>? get primaryGoals;
  @override
  String? get city;
  @override
  String? get targetExamCity;

  /// Create a copy of ExplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ExplicitProfileImplCopyWith<_$ExplicitProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ImplicitProfile _$ImplicitProfileFromJson(Map<String, dynamic> json) {
  return _ImplicitProfile.fromJson(json);
}

/// @nodoc
mixin _$ImplicitProfile {
  Map<String, String>? get energyPattern => throw _privateConstructorUsedError;
  int get focusCapacityMinutes => throw _privateConstructorUsedError;
  double get avgTaskCompletionRate => throw _privateConstructorUsedError;
  Map<String, List<int>>? get preferredWorkHours =>
      throw _privateConstructorUsedError;

  /// Serializes this ImplicitProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ImplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ImplicitProfileCopyWith<ImplicitProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ImplicitProfileCopyWith<$Res> {
  factory $ImplicitProfileCopyWith(
    ImplicitProfile value,
    $Res Function(ImplicitProfile) then,
  ) = _$ImplicitProfileCopyWithImpl<$Res, ImplicitProfile>;
  @useResult
  $Res call({
    Map<String, String>? energyPattern,
    int focusCapacityMinutes,
    double avgTaskCompletionRate,
    Map<String, List<int>>? preferredWorkHours,
  });
}

/// @nodoc
class _$ImplicitProfileCopyWithImpl<$Res, $Val extends ImplicitProfile>
    implements $ImplicitProfileCopyWith<$Res> {
  _$ImplicitProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ImplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? energyPattern = freezed,
    Object? focusCapacityMinutes = null,
    Object? avgTaskCompletionRate = null,
    Object? preferredWorkHours = freezed,
  }) {
    return _then(
      _value.copyWith(
            energyPattern: freezed == energyPattern
                ? _value.energyPattern
                : energyPattern // ignore: cast_nullable_to_non_nullable
                      as Map<String, String>?,
            focusCapacityMinutes: null == focusCapacityMinutes
                ? _value.focusCapacityMinutes
                : focusCapacityMinutes // ignore: cast_nullable_to_non_nullable
                      as int,
            avgTaskCompletionRate: null == avgTaskCompletionRate
                ? _value.avgTaskCompletionRate
                : avgTaskCompletionRate // ignore: cast_nullable_to_non_nullable
                      as double,
            preferredWorkHours: freezed == preferredWorkHours
                ? _value.preferredWorkHours
                : preferredWorkHours // ignore: cast_nullable_to_non_nullable
                      as Map<String, List<int>>?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ImplicitProfileImplCopyWith<$Res>
    implements $ImplicitProfileCopyWith<$Res> {
  factory _$$ImplicitProfileImplCopyWith(
    _$ImplicitProfileImpl value,
    $Res Function(_$ImplicitProfileImpl) then,
  ) = __$$ImplicitProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Map<String, String>? energyPattern,
    int focusCapacityMinutes,
    double avgTaskCompletionRate,
    Map<String, List<int>>? preferredWorkHours,
  });
}

/// @nodoc
class __$$ImplicitProfileImplCopyWithImpl<$Res>
    extends _$ImplicitProfileCopyWithImpl<$Res, _$ImplicitProfileImpl>
    implements _$$ImplicitProfileImplCopyWith<$Res> {
  __$$ImplicitProfileImplCopyWithImpl(
    _$ImplicitProfileImpl _value,
    $Res Function(_$ImplicitProfileImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ImplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? energyPattern = freezed,
    Object? focusCapacityMinutes = null,
    Object? avgTaskCompletionRate = null,
    Object? preferredWorkHours = freezed,
  }) {
    return _then(
      _$ImplicitProfileImpl(
        energyPattern: freezed == energyPattern
            ? _value._energyPattern
            : energyPattern // ignore: cast_nullable_to_non_nullable
                  as Map<String, String>?,
        focusCapacityMinutes: null == focusCapacityMinutes
            ? _value.focusCapacityMinutes
            : focusCapacityMinutes // ignore: cast_nullable_to_non_nullable
                  as int,
        avgTaskCompletionRate: null == avgTaskCompletionRate
            ? _value.avgTaskCompletionRate
            : avgTaskCompletionRate // ignore: cast_nullable_to_non_nullable
                  as double,
        preferredWorkHours: freezed == preferredWorkHours
            ? _value._preferredWorkHours
            : preferredWorkHours // ignore: cast_nullable_to_non_nullable
                  as Map<String, List<int>>?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ImplicitProfileImpl implements _ImplicitProfile {
  const _$ImplicitProfileImpl({
    final Map<String, String>? energyPattern,
    this.focusCapacityMinutes = 90,
    this.avgTaskCompletionRate = 0.75,
    final Map<String, List<int>>? preferredWorkHours,
  }) : _energyPattern = energyPattern,
       _preferredWorkHours = preferredWorkHours;

  factory _$ImplicitProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$ImplicitProfileImplFromJson(json);

  final Map<String, String>? _energyPattern;
  @override
  Map<String, String>? get energyPattern {
    final value = _energyPattern;
    if (value == null) return null;
    if (_energyPattern is EqualUnmodifiableMapView) return _energyPattern;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey()
  final int focusCapacityMinutes;
  @override
  @JsonKey()
  final double avgTaskCompletionRate;
  final Map<String, List<int>>? _preferredWorkHours;
  @override
  Map<String, List<int>>? get preferredWorkHours {
    final value = _preferredWorkHours;
    if (value == null) return null;
    if (_preferredWorkHours is EqualUnmodifiableMapView)
      return _preferredWorkHours;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  String toString() {
    return 'ImplicitProfile(energyPattern: $energyPattern, focusCapacityMinutes: $focusCapacityMinutes, avgTaskCompletionRate: $avgTaskCompletionRate, preferredWorkHours: $preferredWorkHours)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ImplicitProfileImpl &&
            const DeepCollectionEquality().equals(
              other._energyPattern,
              _energyPattern,
            ) &&
            (identical(other.focusCapacityMinutes, focusCapacityMinutes) ||
                other.focusCapacityMinutes == focusCapacityMinutes) &&
            (identical(other.avgTaskCompletionRate, avgTaskCompletionRate) ||
                other.avgTaskCompletionRate == avgTaskCompletionRate) &&
            const DeepCollectionEquality().equals(
              other._preferredWorkHours,
              _preferredWorkHours,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_energyPattern),
    focusCapacityMinutes,
    avgTaskCompletionRate,
    const DeepCollectionEquality().hash(_preferredWorkHours),
  );

  /// Create a copy of ImplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ImplicitProfileImplCopyWith<_$ImplicitProfileImpl> get copyWith =>
      __$$ImplicitProfileImplCopyWithImpl<_$ImplicitProfileImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ImplicitProfileImplToJson(this);
  }
}

abstract class _ImplicitProfile implements ImplicitProfile {
  const factory _ImplicitProfile({
    final Map<String, String>? energyPattern,
    final int focusCapacityMinutes,
    final double avgTaskCompletionRate,
    final Map<String, List<int>>? preferredWorkHours,
  }) = _$ImplicitProfileImpl;

  factory _ImplicitProfile.fromJson(Map<String, dynamic> json) =
      _$ImplicitProfileImpl.fromJson;

  @override
  Map<String, String>? get energyPattern;
  @override
  int get focusCapacityMinutes;
  @override
  double get avgTaskCompletionRate;
  @override
  Map<String, List<int>>? get preferredWorkHours;

  /// Create a copy of ImplicitProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ImplicitProfileImplCopyWith<_$ImplicitProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
