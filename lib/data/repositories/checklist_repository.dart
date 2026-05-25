import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ChecklistRepository {
  final AppDatabase _db;
  ChecklistRepository(this._db);

  Future<List<ChecklistItem>> getByTask(String taskId) async {
    return (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.equals(taskId))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  Future<ChecklistItem> create({
    required String taskId,
    required String title,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await getByTask(taskId);
    final sortOrder = existing.length;

    await _db.into(_db.checklistItems).insert(ChecklistItemsCompanion(
      id: Value(id),
      taskId: Value(taskId),
      title: Value(title),
      sortOrder: Value(sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final result = await (_db.select(_db.checklistItems)
          ..where((c) => c.id.equals(id)))
        .get();
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
  }

  Future<void> delete(String id) async {
    await (_db.delete(_db.checklistItems)..where((c) => c.id.equals(id))).go();
  }

  Future<void> toggleStatus(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final result = await (_db.select(_db.checklistItems)
          ..where((c) => c.id.equals(id)))
        .get();
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
  }

  Future<int> getCompletedCount(String taskId) async {
    final result = await (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.equals(taskId) & c.status.equals(1)))
        .get();
    return result.length;
  }

  Future<int> getTotalCount(String taskId) async {
    final result = await (_db.select(_db.checklistItems)
          ..where((c) => c.taskId.equals(taskId)))
        .get();
    return result.length;
  }
}
