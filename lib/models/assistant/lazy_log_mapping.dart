import 'package:uuid/uuid.dart';

class LazyLogKeywordMapping {
  final String id;
  final List<String> triggers;
  final bool enabled;
  final int? afterHour;
  final int? afterMinute;
  final String? projectId;
  final String? projectHint;

  const LazyLogKeywordMapping({
    required this.id,
    required this.triggers,
    this.enabled = true,
    this.afterHour,
    this.afterMinute,
    this.projectId,
    this.projectHint,
  });

  factory LazyLogKeywordMapping.create({
    required List<String> triggers,
    bool enabled = true,
    int? afterHour,
    int? afterMinute,
    String? projectId,
    String? projectHint,
  }) {
    return LazyLogKeywordMapping(
      id: const Uuid().v4(),
      triggers: triggers,
      enabled: enabled,
      afterHour: afterHour,
      afterMinute: afterMinute,
      projectId: projectId,
      projectHint: projectHint,
    );
  }

  LazyLogKeywordMapping copyWith({
    List<String>? triggers,
    bool? enabled,
    int? afterHour,
    int? afterMinute,
    String? projectId,
    String? projectHint,
    bool clearProject = false,
  }) {
    return LazyLogKeywordMapping(
      id: id,
      triggers: triggers ?? this.triggers,
      enabled: enabled ?? this.enabled,
      afterHour: afterHour ?? this.afterHour,
      afterMinute: afterMinute ?? this.afterMinute,
      projectId: clearProject ? null : (projectId ?? this.projectId),
      projectHint: clearProject ? null : (projectHint ?? this.projectHint),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggers': triggers,
    'enabled': enabled,
    'afterHour': afterHour,
    'afterMinute': afterMinute,
    'projectId': projectId,
    'projectHint': projectHint,
  };

  factory LazyLogKeywordMapping.fromJson(Map<String, dynamic> json) {
    return LazyLogKeywordMapping(
      id: json['id'] as String? ?? '',
      triggers:
          (json['triggers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      enabled: json['enabled'] as bool? ?? true,
      afterHour: json['afterHour'] as int?,
      afterMinute: json['afterMinute'] as int?,
      projectId: json['projectId'] as String?,
      projectHint: json['projectHint'] as String?,
    );
  }

  String get triggersLabel => triggers.join('、');
}
