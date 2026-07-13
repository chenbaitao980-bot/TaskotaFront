class LazyLogTaskDraft {
  final String title;
  final String description;
  final String priority;
  final DateTime? startTime;
  final DateTime? dueTime;

  const LazyLogTaskDraft({
    required this.title,
    this.description = '',
    this.priority = 'P2',
    this.startTime,
    this.dueTime,
  });

  factory LazyLogTaskDraft.fromJson(Map<String, Object?> json) {
    return LazyLogTaskDraft(
      title: _readString(json['title']),
      description: _readString(json['description']),
      priority: _normalizePriority(_readString(json['priority'])),
      startTime: _readDateTime(json['startTime']),
      dueTime: _readDateTime(json['dueTime']),
    );
  }

  LazyLogTaskDraft copyWith({
    String? title,
    String? description,
    String? priority,
    DateTime? startTime,
    DateTime? dueTime,
  }) {
    return LazyLogTaskDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      startTime: startTime ?? this.startTime,
      dueTime: dueTime ?? this.dueTime,
    );
  }
}

class LazyLogScheduleDraft {
  final String title;
  final String description;
  final String priority;
  final DateTime startTime;
  final DateTime endTime;

  const LazyLogScheduleDraft({
    required this.title,
    this.description = '',
    this.priority = 'P2',
    required this.startTime,
    required this.endTime,
  });

  factory LazyLogScheduleDraft.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    final start = _readDateTime(json['startTime']) ?? now;
    final end =
        _readDateTime(json['endTime']) ?? start.add(const Duration(hours: 1));
    return LazyLogScheduleDraft(
      title: _readString(json['title']),
      description: _readString(json['description']),
      priority: _normalizePriority(_readString(json['priority'])),
      startTime: start,
      endTime: end.isAfter(start) ? end : start.add(const Duration(hours: 1)),
    );
  }
}

class LazyLogResult {
  final String summary;
  final List<String> completed;
  final List<String> blockers;
  final List<String> nextActions;
  final List<LazyLogTaskDraft> tasks;
  final List<LazyLogScheduleDraft> schedules;
  final String parentTitle;
  final bool usedFallback;

  const LazyLogResult({
    this.summary = '',
    this.completed = const [],
    this.blockers = const [],
    this.nextActions = const [],
    this.tasks = const [],
    this.schedules = const [],
    this.parentTitle = '',
    this.usedFallback = false,
  });

  bool get isEmpty =>
      summary.trim().isEmpty &&
      completed.isEmpty &&
      blockers.isEmpty &&
      nextActions.isEmpty &&
      tasks.isEmpty &&
      schedules.isEmpty;

  factory LazyLogResult.fromJson(Map<String, Object?> json) {
    return LazyLogResult(
      summary: _readString(json['summary']),
      completed: _readStringList(json['completed']),
      blockers: _readStringList(json['blockers']),
      nextActions: _readStringList(json['nextActions']),
      parentTitle: _readString(json['parentTitle']),
      tasks: _readObjectList(json['tasks'])
          .map(LazyLogTaskDraft.fromJson)
          .where((task) => task.title.trim().isNotEmpty)
          .toList(),
      schedules: _readObjectList(json['schedules'])
          .map(LazyLogScheduleDraft.fromJson)
          .where((schedule) => schedule.title.trim().isNotEmpty)
          .toList(),
    );
  }

  LazyLogResult asFallback() {
    return LazyLogResult(
      summary: summary,
      completed: completed,
      blockers: blockers,
      nextActions: nextActions,
      tasks: tasks,
      schedules: schedules,
      parentTitle: parentTitle,
      usedFallback: true,
    );
  }
}

String _readString(Object? value) => value?.toString().trim() ?? '';

List<String> _readStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final single = _readString(value);
  return single.isEmpty ? const [] : [single];
}

List<Map<String, Object?>> _readObjectList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

DateTime? _readDateTime(Object? value) {
  final raw = _readString(value);
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

String _normalizePriority(String value) {
  final upper = value.toUpperCase();
  if (upper == 'P0' || upper == 'P1' || upper == 'P2' || upper == 'P3') {
    return upper;
  }
  if (value.contains('紧急')) return 'P0';
  if (value.contains('重要')) return 'P1';
  if (value.contains('低')) return 'P3';
  return 'P2';
}
