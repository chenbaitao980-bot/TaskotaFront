import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../services/project_sync_service.dart';

class ProjectGroupRepository {
  final AppDatabase _db;
  final ProjectSyncService? _syncService;
  ProjectGroupRepository(this._db, {ProjectSyncService? syncService})
      : _syncService = syncService;

  Future<List<ProjectGroup>> getAll() async {
    return (_db.select(_db.projectGroups)
          ..where((g) => g.deleted.equals(0))
          ..orderBy([(g) => OrderingTerm(expression: g.sortOrder)]))
        .get();
  }

  /// 不过滤墓石（用于全量对账上推）
  Future<List<ProjectGroup>> getAllRaw() =>
      _db.select(_db.projectGroups).get();

  Future<ProjectGroup?> get(String id) async {
    final result = await (_db.select(_db.projectGroups)
          ..where((g) => g.id.equals(id) & g.deleted.equals(0)))
        .get();
    return result.isNotEmpty ? result.first : null;
  }

  Future<ProjectGroup> create({
    required String name,
    String color = '#4772FA',
    int sortOrder = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.projectGroups).insert(ProjectGroupsCompanion(
          id: Value(id),
          name: Value(name),
          color: Value(color),
          sortOrder: Value(sortOrder),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    final g = (await get(id))!;
    _syncService?.pushGroup(g);
    return g;
  }

  Future<void> update(String id,
      {String? name, String? color, int? sortOrder}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.projectGroups)..where((g) => g.id.equals(id))).write(
      ProjectGroupsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    final updated = await get(id);
    if (updated != null) _syncService?.pushGroup(updated);
  }

  /// 删除分组：所属项目的 group_id 改为 null，不级联删除项目
  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // 用事务原子完成本地两步，避免被 Realtime 回调中途抢锁
    await _db.transaction(() async {
      await (_db.update(_db.projects)..where((p) => p.groupId.equals(id))).write(
        ProjectsCompanion(groupId: const Value(null), updatedAt: Value(now)),
      );
      await (_db.update(_db.projectGroups)..where((g) => g.id.equals(id))).write(
        ProjectGroupsCompanion(deleted: const Value(1), updatedAt: Value(now)),
      );
    });
    // 网络 IO 放事务外：推送墓石
    final row = await (_db.select(_db.projectGroups)
          ..where((g) => g.id.equals(id)))
        .get();
    if (row.isNotEmpty) _syncService?.pushGroup(row.first);
  }
}
