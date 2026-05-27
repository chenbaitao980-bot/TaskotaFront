import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../services/task_sync_service.dart';

class TaskRepository {
  final AppDatabase _db;
  final TaskSyncService? _syncService;
  TaskRepository(this._db, {TaskSyncService? syncService})
      : _syncService = syncService;

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
    int? estimatedMinutes,
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
      estimatedMinutes: estimatedMinutes != null
          ? Value(estimatedMinutes)
          : const Value.absent(),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id)))
        .get();
    final task = result.first;
    _syncService?.push(task);
    return task;
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
      String? parentId,
      int? remindBeforeMinutes,
      int? reminderEnabled,
      int? estimatedMinutes}) async {
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
        remindBeforeMinutes: remindBeforeMinutes != null
            ? Value(remindBeforeMinutes)
            : const Value.absent(),
        reminderEnabled: reminderEnabled != null
            ? Value(reminderEnabled)
            : const Value.absent(),
        estimatedMinutes: estimatedMinutes != null
            ? Value(estimatedMinutes)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    final updated = await get(id);
    if (updated != null) _syncService?.push(updated);

    // 项目变更时级联同步到所有后代
    if (projectId != null) {
      await _cascadeProjectId(id, projectId);
    }
  }

  /// 把指定任务的所有后代的 projectId 改为 newProjectId
  Future<void> _cascadeProjectId(String rootId, String newProjectId) async {
    final descendants = await getDescendants(rootId);
    if (descendants.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final d in descendants) {
        if (d.projectId == newProjectId) continue;
        batch.update(
          _db.tasks,
          TasksCompanion(
            projectId: Value(newProjectId),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(d.id),
        );
      }
    });
    for (final d in descendants) {
      if (d.projectId == newProjectId) continue;
      final updated = await get(d.id);
      if (updated != null) _syncService?.push(updated);
    }
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
    _syncService?.remove(id);
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
    final toggled = await get(id);
    if (toggled != null) _syncService?.push(toggled);
  }

  /// 从云端同步导入任务（插入或更新，保留原始 ID）
  Future<void> syncFromJson(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await get(id);
    if (existing != null) {
      // 仅当云端版本更新时才更新
      final remoteUpdated = json['updatedAt'] as int? ?? 0;
      if (remoteUpdated > existing.updatedAt) {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            projectId: Value(json['projectId'] as String),
            title: Value(json['title'] as String),
            description: Value(json['description'] as String? ?? ''),
            priority: Value(json['priority'] as int? ?? 0),
            status: Value(json['status'] as int? ?? 0),
            startDate: json['startDate'] != null
                ? Value(json['startDate'] as int)
                : const Value.absent(),
            dueDate: json['dueDate'] != null
                ? Value(json['dueDate'] as int)
                : const Value.absent(),
            isAllDay: Value(json['isAllDay'] as int? ?? 0),
            sortOrder: Value(json['sortOrder'] as int? ?? 0),
            parentId: json['parentId'] != null
                ? Value(json['parentId'] as String)
                : const Value.absent(),
            remindBeforeMinutes: json['remindBeforeMinutes'] != null
                ? Value(json['remindBeforeMinutes'] as int)
                : const Value.absent(),
            reminderEnabled: json['reminderEnabled'] != null
                ? Value(json['reminderEnabled'] as int)
                : const Value.absent(),
            estimatedMinutes: json['estimatedMinutes'] != null
                ? Value(json['estimatedMinutes'] as int)
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
      }
    } else {
      // 不存在则插入
      await _db.into(_db.tasks).insert(TasksCompanion(
        id: Value(id),
        projectId: Value(json['projectId'] as String),
        title: Value(json['title'] as String),
        description: Value(json['description'] as String? ?? ''),
        priority: Value(json['priority'] as int? ?? 0),
        status: Value(json['status'] as int? ?? 0),
        startDate: json['startDate'] != null
            ? Value(json['startDate'] as int)
            : const Value.absent(),
        dueDate: json['dueDate'] != null
            ? Value(json['dueDate'] as int)
            : const Value.absent(),
        isAllDay: Value(json['isAllDay'] as int? ?? 0),
        sortOrder: Value(json['sortOrder'] as int? ?? 0),
        parentId: json['parentId'] != null
            ? Value(json['parentId'] as String)
            : const Value.absent(),
        remindBeforeMinutes: json['remindBeforeMinutes'] != null
            ? Value(json['remindBeforeMinutes'] as int)
            : const Value.absent(),
        reminderEnabled: json['reminderEnabled'] != null
            ? Value(json['reminderEnabled'] as int)
            : const Value.absent(),
        estimatedMinutes: json['estimatedMinutes'] != null
            ? Value(json['estimatedMinutes'] as int)
            : const Value.absent(),
        completedTime: json['completedTime'] != null
            ? Value(json['completedTime'] as int)
            : const Value.absent(),
        createdAt: Value(json['createdAt'] as int? ?? now),
        updatedAt: Value(now),
      ));
    }
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
