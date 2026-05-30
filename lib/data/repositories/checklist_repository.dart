import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../services/checklist_sync_service.dart';

class ChecklistRepository {
  final AppDatabase _db;
  final ChecklistSyncService? _syncService;
  ChecklistRepository(this._db, {ChecklistSyncService? syncService})
      : _syncService = syncService;

  Future<List<ChecklistItem>> getByTask(String taskId) async {
    return (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.equals(taskId) & c.deleted.equals(0))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  Future<List<ChecklistItem>> getByTaskIds(List<String> taskIds) async {
    if (taskIds.isEmpty) return [];
    return (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.isIn(taskIds) & c.deleted.equals(0))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  /// 不过滤墓石（用于全量对账上推）
  Future<List<ChecklistItem>> getAllRaw() =>
      _db.select(_db.checklistItems).get();

  Future<ChecklistItem?> _getRaw(String id) async {
    final r = await (_db.select(_db.checklistItems)
          ..where((c) => c.id.equals(id)))
        .get();
    return r.isNotEmpty ? r.first : null;
  }

  Future<void> _push(String id) async {
    final row = await _getRaw(id);
    if (row != null) _syncService?.push(row);
  }

  Future<ChecklistItem> create({
    required String taskId,
    required String title,
    String? obsidianUri,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getByTask(taskId);
    final sortOrder = existing.length;

    await _db
        .into(_db.checklistItems)
        .insert(
          ChecklistItemsCompanion(
            id: Value(id),
            taskId: Value(taskId),
            title: Value(title),
            obsidianUri: obsidianUri != null
                ? Value(obsidianUri)
                : const Value.absent(),
            sortOrder: Value(sortOrder),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final result = await (_db.select(
      _db.checklistItems,
    )..where((c) => c.id.equals(id))).get();
    await _push(id);
    return result.first;
  }

  Future<void> update(String id, {String? title}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id))).write(
      ChecklistItemsCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    await _push(id);
  }

  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id))).write(
      ChecklistItemsCompanion(
        deleted: const Value(1),
        updatedAt: Value(now),
      ),
    );
    await _push(id);
  }

  Future<void> setObsidianUri(String id, String? uri) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id))).write(
      ChecklistItemsCompanion(
        obsidianUri: uri != null ? Value(uri) : Value<String?>(null),
        updatedAt: Value(now),
      ),
    );
    await _push(id);
  }

  Future<void> toggleStatus(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await (_db.select(
      _db.checklistItems,
    )..where((c) => c.id.equals(id))).get();
    if (result.isEmpty) return;
    final item = result.first;
    final newStatus = item.status == 0 ? 1 : 0;
    await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id))).write(
      ChecklistItemsCompanion(
        status: Value(newStatus),
        completedTime: newStatus == 1 ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    await _push(id);
  }

  Future<int> getCompletedCount(String taskId) async {
    final result = await (_db.select(
      _db.checklistItems,
    )..where((c) =>
            c.taskId.equals(taskId) &
            c.status.equals(1) &
            c.deleted.equals(0)))
        .get();
    return result.length;
  }

  Future<int> getTotalCount(String taskId) async {
    final result = await (_db.select(
      _db.checklistItems,
    )..where((c) => c.taskId.equals(taskId) & c.deleted.equals(0))).get();
    return result.length;
  }

  /// 从云端同步导入清单项（插入或更新，保留原始 ID，LWW）
  Future<void> syncFromJson(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _getRaw(id);
    final companion = ChecklistItemsCompanion(
      id: Value(id),
      taskId: Value(json['taskId'] as String),
      title: Value(json['title'] as String? ?? ''),
      status: Value(json['status'] as int? ?? 0),
      sortOrder: Value(json['sortOrder'] as int? ?? 0),
      obsidianUri: json['obsidianUri'] != null
          ? Value(json['obsidianUri'] as String)
          : const Value(null),
      completedTime: json['completedTime'] != null
          ? Value(json['completedTime'] as int)
          : const Value(null),
      deleted: Value(json['deleted'] as int? ?? 0),
      createdAt: Value(json['createdAt'] as int? ?? now),
      updatedAt: Value(json['updatedAt'] as int? ?? now),
    );
    if (existing == null) {
      await _db.into(_db.checklistItems).insert(companion);
    } else {
      final remoteUpdated = json['updatedAt'] as int? ?? 0;
      if (remoteUpdated > existing.updatedAt) {
        await (_db.update(_db.checklistItems)..where((c) => c.id.equals(id)))
            .write(companion);
      }
    }
  }
}
