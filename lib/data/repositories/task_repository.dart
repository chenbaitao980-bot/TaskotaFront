import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class TaskRepository {
  final AppDatabase _db;
  TaskRepository(this._db);

  Future<List<Task>> getAll(
      {String? projectId, int? status, int? priority}) async {
    final query = _db.select(_db.tasks)
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    if (priority != null) {
      query.where((t) => t.priority.equals(priority));
    }
    return query.get();
  }

  Future<List<Task>> getRootTasks({String? projectId, int? status}) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.parentId.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    return query.get();
  }

  Future<List<Task>> getByProject(String projectId, {int? status}) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.projectId.equals(projectId))
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    return query.get();
  }

  Future<List<Task>> getToday() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return (_db.select(_db.tasks)
          ..where((t) => t.dueDate.isBetween(
                Variable(startOfDay.millisecondsSinceEpoch),
                Variable(endOfDay.millisecondsSinceEpoch),
              ))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<Task>> getImportant() async {
    return (_db.select(_db.tasks)
          ..where((t) => t.priority.equals(5) & t.status.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .get();
  }

  Future<Task?> get(String id) async {
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id)))
        .get();
    return result.isNotEmpty ? result.first : null;
  }

  // --- 子任务树 ---

  Future<List<Task>> getSubTasks(String parentId) async {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  Future<List<Task>> getDescendants(String taskId) async {
    final result = <Task>[];
    final queue = <String>[taskId];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final children = await getSubTasks(current);
      for (final child in children) {
        result.add(child);
        queue.add(child.id);
      }
    }
    return result;
  }

  Future<Map<String?, List<Task>>> getTreeMap(String rootTaskId) async {
    final map = <String?, List<Task>>{};
    final allDescendants = await getDescendants(rootTaskId);
    // 包含根任务本身
    final root = await get(rootTaskId);
    if (root != null) {
      map[rootTaskId] = allDescendants
          .where((t) => t.parentId == rootTaskId)
          .toList();
      for (final task in allDescendants) {
        map[task.id] = allDescendants
            .where((t) => t.parentId == task.id)
            .toList();
      }
    }
    return map;
  }

  Future<void> moveTask(String taskId, String? newParentId) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        parentId: newParentId != null
            ? Value(newParentId)
            : const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> reorderSubTasks(
      String? parentId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(orderedIds[i])))
          .write(TasksCompanion(
        sortOrder: Value(i),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }

  // --- CRUD ---

  Future<Task> create({
    required String projectId,
    required String title,
    String description = '',
    int priority = 0,
    int? startDate,
    int? dueDate,
    bool isAllDay = false,
    String? parentId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.tasks).insert(TasksCompanion(
      id: Value(id),
      projectId: Value(projectId),
      title: Value(title),
      description: Value(description),
      priority: Value(priority),
      isAllDay: Value(isAllDay ? 1 : 0),
      parentId: parentId != null ? Value(parentId) : const Value.absent(),
      startDate: startDate != null ? Value(startDate) : const Value.absent(),
      dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id)))
        .get();
    return result.first;
  }

  Future<void> update(String id,
      {String? projectId,
      String? title,
      String? description,
      int? priority,
      int? startDate,
      int? dueDate,
      int? isAllDay,
      int? sortOrder,
      String? parentId}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        projectId: projectId != null ? Value(projectId) : const Value.absent(),
        title: title != null ? Value(title) : const Value.absent(),
        description:
            description != null ? Value(description) : const Value.absent(),
        priority: priority != null ? Value(priority) : const Value.absent(),
        startDate:
            startDate != null ? Value(startDate) : const Value.absent(),
        dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
        isAllDay: isAllDay != null ? Value(isAllDay) : const Value.absent(),
        sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete(String id) async {
    // 先递归删除所有子任务
    final descendants = await getDescendants(id);
    for (final desc in descendants) {
      await (_db.delete(_db.checklistItems)
            ..where((c) => c.taskId.equals(desc.id)))
          .go();
    }
    for (final desc in descendants) {
      await (_db.delete(_db.tasks)..where((t) => t.id.equals(desc.id))).go();
    }
    // 再删除任务自身的检查项
    await (_db.delete(_db.checklistItems)
          ..where((c) => c.taskId.equals(id)))
        .go();
    await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleStatus(String id) async {
    final task = await get(id);
    if (task == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final newStatus = task.status == 0 ? 2 : 0;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(newStatus),
        completedTime: newStatus == 2 ? Value(now) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> reorder(String projectId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(orderedIds[i])))
          .write(TasksCompanion(
        sortOrder: Value(i),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }
}
