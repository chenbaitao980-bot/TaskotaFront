import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';
part 'user_profile.g.dart';

@freezed
class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    String? displayName,
    Map<String, dynamic>? explicitProfile,
    Map<String, dynamic>? implicitProfile,
    Map<String, dynamic>? encryptedData,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);
}

@freezed
class ExplicitProfile with _$ExplicitProfile {
  const factory ExplicitProfile({
    String? name,
    String? occupation,
    String? incomeLevel,
    List<String>? primaryGoals,
    String? city,
    String? targetExamCity,
  }) = _ExplicitProfile;

  factory ExplicitProfile.fromJson(Map<String, dynamic> json) =>
      _$ExplicitProfileFromJson(json);
}

@freezed
class ImplicitProfile with _$ImplicitProfile {
  const factory ImplicitProfile({
    Map<String, String>? energyPattern,
    @Default(90) int focusCapacityMinutes,
    @Default(0.75) double avgTaskCompletionRate,
    Map<String, List<int>>? preferredWorkHours,
  }) = _ImplicitProfile;

  factory ImplicitProfile.fromJson(Map<String, dynamic> json) =>
      _$ImplicitProfileFromJson(json);
}
