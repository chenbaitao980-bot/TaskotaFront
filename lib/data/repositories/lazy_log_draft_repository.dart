import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/assistant/lazy_log_review_models.dart';
import '../database/app_database.dart';

class LazyLogDraftRepository {
  final AppDatabase _db;

  LazyLogDraftRepository(this._db);

  Stream<int> watchRunningCount() {
    return (_db.select(_db.lazyLogDrafts)..where(
          (d) =>
              d.status.equals(LazyLogDraftStatus.running) &
              d.needsReview.equals(1),
        ))
        .watch()
        .map((rows) => rows.length);
  }

  Stream<int> watchPendingReviewCount() {
    return (_db.select(_db.lazyLogDrafts)..where(
          (d) =>
              d.status.equals(LazyLogDraftStatus.pendingReview) &
              d.needsReview.equals(1),
        ))
        .watch()
        .map((rows) => rows.length);
  }

  Stream<int> watchFailedCount() {
    return (_db.select(_db.lazyLogDrafts)..where(
          (d) =>
              d.status.equals(LazyLogDraftStatus.failed) &
              d.needsReview.equals(1),
        ))
        .watch()
        .map((rows) => rows.length);
  }

  Stream<List<LazyLogDraft>> watchReviewable() {
    final query = _db.select(_db.lazyLogDrafts)
      ..where((d) => d.needsReview.equals(1))
      ..orderBy([
        (d) => OrderingTerm(expression: d.createdAt),
        (d) => OrderingTerm(expression: d.sortOrder),
      ]);
    return query.watch();
  }

  Future<List<LazyLogDraft>> getPendingReview({Set<String>? excludeIds}) async {
    final query = _db.select(_db.lazyLogDrafts)
      ..where(
        (d) =>
            d.status.equals(LazyLogDraftStatus.pendingReview) &
            d.needsReview.equals(1),
      )
      ..orderBy([
        (d) => OrderingTerm(expression: d.createdAt),
        (d) => OrderingTerm(expression: d.sortOrder),
      ]);
    final rows = await query.get();
    if (excludeIds == null || excludeIds.isEmpty) return rows;
    return rows.where((row) => !excludeIds.contains(row.id)).toList();
  }

  Future<LazyLogDraft> createRunning({
    required String sourceInput,
    required String batchId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.lazyLogDrafts)
        .insert(
          LazyLogDraftsCompanion(
            id: Value(id),
            batchId: Value(batchId),
            sourceInput: Value(sourceInput),
            status: const Value(LazyLogDraftStatus.running),
            title: const Value('正在整理...'),
            startDate: Value(now),
            dueDate: Value(now + const Duration(hours: 1).inMilliseconds),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return (_db.select(
      _db.lazyLogDrafts,
    )..where((d) => d.id.equals(id))).getSingle();
  }

  Future<void> replaceRunningWithDrafts({
    required String runningId,
    required List<LazyLogDraftWrite> drafts,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await (_db.update(
        _db.lazyLogDrafts,
      )..where((d) => d.id.equals(runningId))).write(
        LazyLogDraftsCompanion(
          status: const Value(LazyLogDraftStatus.dismissed),
          needsReview: const Value(0),
          updatedAt: Value(now),
        ),
      );
      for (final draft in drafts) {
        await _db.into(_db.lazyLogDrafts).insert(_toCompanion(draft, now));
      }
    });
  }

  Future<void> markFailed(String id, String message) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.lazyLogDrafts)..where((d) => d.id.equals(id))).write(
      LazyLogDraftsCompanion(
        status: const Value(LazyLogDraftStatus.failed),
        errorMessage: Value(message),
        title: const Value('整理失败'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> retry(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.lazyLogDrafts)..where((d) => d.id.equals(id))).write(
      LazyLogDraftsCompanion(
        status: const Value(LazyLogDraftStatus.running),
        errorMessage: const Value(null),
        title: const Value('正在整理...'),
        needsReview: const Value(1),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateDraft(
    String id, {
    String? title,
    String? description,
    String? priority,
    String? projectId,
    bool clearProjectId = false,
    String? parentTaskId,
    bool clearParentTaskId = false,
    String? parentTitle,
    List<String>? checklist,
    DateTime? start,
    DateTime? end,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.lazyLogDrafts)..where((d) => d.id.equals(id))).write(
      LazyLogDraftsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        priority: priority != null ? Value(priority) : const Value.absent(),
        projectId: clearProjectId
            ? const Value(null)
            : projectId != null
            ? Value(projectId)
            : const Value.absent(),
        parentTaskId: clearParentTaskId
            ? const Value(null)
            : parentTaskId != null
            ? Value(parentTaskId)
            : const Value.absent(),
        parentTitle: parentTitle != null
            ? Value(parentTitle)
            : const Value.absent(),
        checklistJson: checklist != null
            ? Value(jsonEncode(_cleanChecklist(checklist)))
            : const Value.absent(),
        startDate: start != null
            ? Value(start.millisecondsSinceEpoch)
            : const Value.absent(),
        dueDate: end != null
            ? Value(end.millisecondsSinceEpoch)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> approve(String id, {required String createdTaskId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.lazyLogDrafts)..where((d) => d.id.equals(id))).write(
      LazyLogDraftsCompanion(
        status: const Value(LazyLogDraftStatus.approved),
        needsReview: const Value(0),
        createdTaskId: Value(createdTaskId),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> dismiss(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.lazyLogDrafts)..where((d) => d.id.equals(id))).write(
      LazyLogDraftsCompanion(
        status: const Value(LazyLogDraftStatus.dismissed),
        needsReview: const Value(0),
        updatedAt: Value(now),
      ),
    );
  }

  LazyLogDraftsCompanion _toCompanion(LazyLogDraftWrite draft, int now) {
    final end = draft.end.isAfter(draft.start)
        ? draft.end
        : draft.start.add(const Duration(hours: 1));
    return LazyLogDraftsCompanion(
      id: Value(const Uuid().v4()),
      batchId: Value(draft.batchId),
      sourceInput: Value(draft.sourceInput),
      status: const Value(LazyLogDraftStatus.pendingReview),
      summary: Value(draft.summary),
      projectId: draft.projectId != null
          ? Value(draft.projectId)
          : const Value.absent(),
      parentTaskId: draft.parentTaskId != null
          ? Value(draft.parentTaskId)
          : const Value.absent(),
      parentTitle: Value(draft.parentTitle),
      title: Value(draft.title.trim()),
      description: Value(draft.description.trim()),
      priority: Value(draft.priority),
      checklistJson: Value(jsonEncode(_cleanChecklist(draft.checklist))),
      startDate: Value(draft.start.millisecondsSinceEpoch),
      dueDate: Value(end.millisecondsSinceEpoch),
      sortOrder: Value(draft.sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  static List<String> checklistOf(LazyLogDraft draft) {
    final decoded = jsonDecode(draft.checklistJson);
    if (decoded is! List) return const [];
    return _cleanChecklist(decoded.map((item) => item.toString()));
  }

  static List<String> _cleanChecklist(Iterable<String> values) {
    return values
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
