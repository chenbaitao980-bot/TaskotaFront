class LazyLogDraftStatus {
  static const running = 'running';
  static const pendingReview = 'pending_review';
  static const failed = 'failed';
  static const approved = 'approved';
  static const dismissed = 'dismissed';
}

class LazyLogDraftWrite {
  final String batchId;
  final String sourceInput;
  final String summary;
  final String? projectId;
  final String? parentTaskId;
  final String parentTitle;
  final String title;
  final String description;
  final String priority;
  final List<String> checklist;
  final DateTime start;
  final DateTime end;
  final int sortOrder;

  const LazyLogDraftWrite({
    required this.batchId,
    required this.sourceInput,
    required this.summary,
    this.projectId,
    this.parentTaskId,
    this.parentTitle = '',
    required this.title,
    this.description = '',
    this.priority = 'P2',
    this.checklist = const [],
    required this.start,
    required this.end,
    required this.sortOrder,
  });
}
