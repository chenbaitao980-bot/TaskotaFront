import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../services/project_sync_service.dart';

class ProjectRepository {
  final AppDatabase _db;
  final ProjectSyncService? _syncService;
  ProjectRepository(this._db, {ProjectSyncService? syncService})
      : _syncService = syncService;

  Future<List<Project>> getAll() async {
    return (_db.select(_db.projects)..where((p) => p.deleted.equals(0))).get();
  }

  /// 不过滤墓石（用于全量对账上推）
  Future<List<Project>> getAllRaw() => _db.select(_db.projects).get();

  Future<List<Project>> getActive() async {
    return (_db.select(_db.projects)
          ..where((p) => p.archived.equals(0) & p.deleted.equals(0)))
        .get();
  }

  Future<Project?> get(String id) async {
    final result = await (_db.select(_db.projects)
          ..where((p) => p.id.equals(id) & p.deleted.equals(0)))
        .get();
    return result.isNotEmpty ? result.first : null;
  }

  Future<Project> create({
    required String name,
    String color = '#4772FA',
    int sortOrder = 0,
    String? groupId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.projects).insert(ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortOrder: Value(sortOrder),
      groupId: groupId != null ? Value(groupId) : const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final result = await (_db.select(_db.projects)
          ..where((p) => p.id.equals(id)))
        .get();
    _syncService?.pushProject(result.first);
    return result.first;
  }

  Future<void> update(String id,
      {String? name,
      String? color,
      int? sortOrder,
      int? archived,
      String? groupId,
      bool clearGroup = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        archived: archived != null ? Value(archived) : const Value.absent(),
        groupId: clearGroup
            ? const Value(null)
            : (groupId != null ? Value(groupId) : const Value.absent()),
        updatedAt: Value(now),
      ),
    );
    final updated = await get(id);
    if (updated != null) _syncService?.pushProject(updated);
  }

  Future<void> delete(String id) async {
    // 软删除：级联软删项目下的 tasks/checklist，再软删项目自身，推送墓石
    final now = DateTime.now().millisecondsSinceEpoch;
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(id)))
        .get();
    await _db.transaction(() async {
      for (final task in tasks) {
        await (_db.update(_db.checklistItems)
              ..where((c) => c.taskId.equals(task.id)))
            .write(ChecklistItemsCompanion(
          deleted: const Value(1),
          updatedAt: Value(now),
        ));
      }
      await (_db.update(_db.tasks)..where((t) => t.projectId.equals(id))).write(
        TasksCompanion(deleted: const Value(1), updatedAt: Value(now)),
      );
      await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(deleted: const Value(1), updatedAt: Value(now)),
      );
    });
    final row = await (_db.select(_db.projects)..where((p) => p.id.equals(id)))
        .get();
    if (row.isNotEmpty) _syncService?.pushProject(row.first);
  }

  Future<void> archive(String id) async {
    await update(id, archived: 1);
  }

  Future<void> unarchive(String id) async {
    await update(id, archived: 0);
  }
}
