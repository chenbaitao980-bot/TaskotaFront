// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserProfileImpl _$$UserProfileImplFromJson(Map<String, dynamic> json) =>
    _$UserProfileImpl(
      id: json['id'] as String,
      displayName: json['displayName'] as String?,
      explicitProfile: json['explicitProfile'] as Map<String, dynamic>?,
      implicitProfile: json['implicitProfile'] as Map<String, dynamic>?,
      encryptedData: json['encryptedData'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$UserProfileImplToJson(_$UserProfileImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'displayName': instance.displayName,
      'explicitProfile': instance.explicitProfile,
      'implicitProfile': instance.implicitProfile,
      'encryptedData': instance.encryptedData,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

_$ExplicitProfileImpl _$$ExplicitProfileImplFromJson(
  Map<String, dynamic> json,
) => _$ExplicitProfileImpl(
  name: json['name'] as String?,
  occupation: json['occupation'] as String?,
  incomeLevel: json['incomeLevel'] as String?,
  primaryGoals: (json['primaryGoals'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  city: json['city'] as String?,
  targetExamCity: json['targetExamCity'] as String?,
);

Map<String, dynamic> _$$ExplicitProfileImplToJson(
  _$ExplicitProfileImpl instance,
) => <String, dynamic>{
  'name': instance.name,
  'occupation': instance.occupation,
  'incomeLevel': instance.incomeLevel,
  'primaryGoals': instance.primaryGoals,
  'city': instance.city,
  'targetExamCity': instance.targetExamCity,
};

_$ImplicitProfileImpl _$$ImplicitProfileImplFromJson(
  Map<String, dynamic> json,
) => _$ImplicitProfileImpl(
  energyPattern: (json['energyPattern'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
  focusCapacityMinutes: (json['focusCapacityMinutes'] as num?)?.toInt() ?? 90,
  avgTaskCompletionRate:
      (json['avgTaskCompletionRate'] as num?)?.toDouble() ?? 0.75,
  preferredWorkHours: (json['preferredWorkHours'] as Map<String, dynamic>?)
      ?.map(
        (k, e) => MapEntry(
          k,
          (e as List<dynamic>).map((e) => (e as num).toInt()).toList(),
        ),
      ),
);

Map<String, dynamic> _$$ImplicitProfileImplToJson(
  _$ImplicitProfileImpl instance,
) => <String, dynamic>{
  'energyPattern': instance.energyPattern,
  'focusCapacityMinutes': instance.focusCapacityMinutes,
  'avgTaskCompletionRate': instance.avgTaskCompletionRate,
  'preferredWorkHours': instance.preferredWorkHours,
};
