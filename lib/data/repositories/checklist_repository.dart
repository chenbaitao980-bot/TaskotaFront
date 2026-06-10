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

  Future<void> reorderItems(String taskId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.checklistItems,
          ChecklistItemsCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (c) => c.id.equals(orderedIds[i]),
        );
      }
    });
    // 一次批量回读后逐条推送（按 orderedIds 原顺序）
    final rows = await (_db.select(_db.checklistItems)
          ..where((c) => c.id.isIn(orderedIds)))
        .get();
    final byId = {for (final r in rows) r.id: r};
    for (final id in orderedIds) {
      final row = byId[id];
      if (row != null) _syncService?.push(row);
    }
  }

  Future<int> getCompletedCount(String taskId) async {
    final countExp = countAll();
    final query = _db.selectOnly(_db.checklistItems)
      ..addColumns([countExp])
      ..where(_db.checklistItems.taskId.equals(taskId) &
          _db.checklistItems.status.equals(1) &
          _db.checklistItems.deleted.equals(0));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<int> getTotalCount(String taskId) async {
    final countExp = countAll();
    final query = _db.selectOnly(_db.checklistItems)
      ..addColumns([countExp])
      ..where(_db.checklistItems.taskId.equals(taskId) &
          _db.checklistItems.deleted.equals(0));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
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

  /// 批量版 syncFromJson：一次取本地全部行建 Map 做 LWW 判断，
  /// 胜出行统一 batch 写入并整体包事务。LWW 逻辑与 syncFromJson 完全一致。
  Future<void> syncManyFromJson(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    // 同 id 多行去重：保留 updatedAt 最大者（与逐条顺序应用结果一致）
    final byId = <String, Map<String, dynamic>>{};
    for (final json in rows) {
      final id = json['id'] as String;
      final prev = byId[id];
      if (prev == null ||
          (json['updatedAt'] as int? ?? 0) >= (prev['updatedAt'] as int? ?? 0)) {
        byId[id] = json;
      }
    }

    final localRows = await getAllRaw();
    final localMap = {for (final c in localRows) c.id: c};
    final now = DateTime.now().millisecondsSinceEpoch;

    final inserts = <ChecklistItemsCompanion>[];
    final updates = <String, ChecklistItemsCompanion>{};

    for (final json in byId.values) {
      final id = json['id'] as String;
      final existing = localMap[id];
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
        inserts.add(companion);
      } else {
        final remoteUpdated = json['updatedAt'] as int? ?? 0;
        if (remoteUpdated > existing.updatedAt) {
          updates[id] = companion;
        }
      }
    }

    if (inserts.isEmpty && updates.isEmpty) return;
    await _db.transaction(() async {
      await _db.batch((batch) {
        for (final companion in inserts) {
          batch.insert(_db.checklistItems, companion);
        }
        for (final entry in updates.entries) {
          batch.update(
            _db.checklistItems,
            entry.value,
            where: (c) => c.id.equals(entry.key),
          );
        }
      });
    });
  }
}
