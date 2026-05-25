import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ProjectRepository {
  final AppDatabase _db;
  ProjectRepository(this._db);

  Future<List<Project>> getAll() async {
    return _db.select(_db.projects).get();
  }

  Future<List<Project>> getActive() async {
    return (_db.select(_db.projects)
          ..where((p) => p.archived.equals(0)))
        .get();
  }

  Future<Project?> get(String id) async {
    final result = await (_db.select(_db.projects)
          ..where((p) => p.id.equals(id)))
        .get();
    return result.isNotEmpty ? result.first : null;
  }

  Future<Project> create({
    required String name,
    String color = '#4772FA',
    int sortOrder = 0,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.projects).insert(ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortOrder: Value(sortOrder),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final result = await (_db.select(_db.projects)
          ..where((p) => p.id.equals(id)))
        .get();
    return result.first;
  }

  Future<void> update(String id,
      {String? name, String? color, int? sortOrder, int? archived}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        archived: archived != null ? Value(archived) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete(String id) async {
    final tasks = await (_db.select(_db.tasks)
          ..where((t) => t.projectId.equals(id)))
        .get();
    for (final task in tasks) {
      await (_db.delete(_db.checklistItems)
            ..where((c) => c.taskId.equals(task.id)))
          .go();
    }
    await (_db.delete(_db.tasks)..where((t) => t.projectId.equals(id))).go();
    await (_db.delete(_db.projects)..where((p) => p.id.equals(id))).go();
  }

  Future<void> archive(String id) async {
    await update(id, archived: 1);
  }

  Future<void> unarchive(String id) async {
    await update(id, archived: 0);
  }
}
