import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../services/task_sync_service.dart';
import '../../core/utils/file_logger.dart';

class TaskRepository {
  final AppDatabase _db;
  final TaskSyncService? _syncService;
  TaskRepository(this._db, {TaskSyncService? syncService})
      : _syncService = syncService;

  Future<List<Task>> getAll(
      {String? projectId, int? status, int? priority}) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.deleted.equals(0))
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
      ..where((t) => t.parentId.isNull() & t.deleted.equals(0))
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
      ..where((t) => t.projectId.equals(projectId) & t.deleted.equals(0))
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
          ..where((t) =>
              t.dueDate.isBetween(
                Variable(startOfDay.millisecondsSinceEpoch),
                Variable(endOfDay.millisecondsSinceEpoch),
              ) &
              t.deleted.equals(0))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<Task>> getImportant() async {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.priority.equals(5) & t.status.equals(0) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .get();
  }

  Future<Task?> get(String id) async {
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id) & t.deleted.equals(0)))
        .get();
    return result.isNotEmpty ? result.first : null;
  }

  // --- 子任务树 ---

  Future<List<Task>> getSubTasks(String parentId) async {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId) & t.deleted.equals(0))
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
    print('[TaskRepo.create] id=${task.id}, parentId=${task.parentId}, projectId=${task.projectId}, deleted=${task.deleted}');
    await _syncService?.push(task);
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
    // 软删除：自身 + 全部后代写墓石，每个 id 推送上云（带 deleted=1）
    final descendants = await getDescendants(id);
    final ids = <String>[id, ...descendants.map((d) => d.id)];
    flog('[TaskRepo.delete] id=${id.substring(0, 8)}, 级联删除 ${ids.length} 条 (自身+${descendants.length}后代)');
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final tid in ids) {
        batch.update(
          _db.tasks,
          TasksCompanion(
            deleted: const Value(1),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(tid),
        );
        // checklist 项同步软删
        batch.update(
          _db.checklistItems,
          ChecklistItemsCompanion(
            deleted: const Value(1),
            updatedAt: Value(now),
          ),
          where: (c) => c.taskId.equals(tid),
        );
      }
    });
    for (final tid in ids) {
      final row = await _getRaw(tid);
      if (row != null) _syncService?.push(row);
    }
  }

  /// 不过滤墓石地读取全部行（用于全量对账上推）
  Future<List<Task>> getAllRaw() => _db.select(_db.tasks).get();

  /// 不过滤墓石地读取一行（用于删除后推送墓石）
  Future<Task?> _getRaw(String id) async {
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.id.equals(id)))
        .get();
    return result.isNotEmpty ? result.first : null;
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
  /// 使用远端 updatedAt 做 LWW，保留远端时间戳避免反推覆盖
  Future<void> syncFromJson(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final remoteUpdated = json['updatedAt'] as int? ?? 0;
    final remoteDeleted = json['deleted'] as int? ?? 0;
    final existing = await _getRaw(id);

    flog('[syncFromJson] 开始: id=${id.substring(0, 8)}, remoteDeleted=$remoteDeleted, remoteUpdated=$remoteUpdated, remoteParentId=${json['parentId']?.toString().substring(0, 8) ?? 'null'}, remoteStatus=${json['status']}');

    final companion = TasksCompanion(
      projectId: Value(json['projectId'] as String),
      title: Value(json['title'] as String),
      deleted: Value(remoteDeleted),
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
      updatedAt: Value(remoteUpdated),
    );

    if (existing != null) {
      flog('[syncFromJson] 本地已存在: id=${id.substring(0, 8)}, localDeleted=${existing.deleted}, localUpdated=${existing.updatedAt}, localParentId=${existing.parentId?.substring(0, 8) ?? 'null'}, localStatus=${existing.status}');
      // 墓石保护：本地已删除且时间戳>=远端，不被远端未删除状态覆盖
      if (existing.deleted == 1 && remoteDeleted == 0 && existing.updatedAt >= remoteUpdated) {
        flog('[syncFromJson] 墓石保护: 本地墓碑 ${id.substring(0, 8)} 拒绝被远端live覆盖');
        return;
      }
      // 反向保护：本地未删除(活任务)不被远端墓石覆盖
      if (existing.deleted == 0 &&
          remoteDeleted == 1 &&
          existing.updatedAt > remoteUpdated) {
        flog('[syncFromJson] 反向墓石保护: 本地活任务 ${id.substring(0, 8)} 拒绝被远端墓石覆盖, localUpdated=${existing.updatedAt}, remoteUpdated=$remoteUpdated');
        // 本地是活的，远端要删除 → 以本地为准，反推到云端
        return;
      }
      // 仅当云端版本更新时才更新
      if (remoteUpdated > existing.updatedAt) {
        final changedFields = <String>[];
        if (remoteDeleted != existing.deleted) changedFields.add('deleted:${existing.deleted}→$remoteDeleted');
        if (json['parentId'] != existing.parentId) changedFields.add('parentId:${existing.parentId?.substring(0, 8) ?? 'null'}→${json['parentId']?.toString().substring(0, 8) ?? 'null'}');
        if ((json['status'] as int? ?? 0) != existing.status) changedFields.add('status:${existing.status}→${json['status']}');
        flog('[syncFromJson] ☁️ 云端更新: id=${id.substring(0, 8)}, 变更字段=[${changedFields.join(', ')}], remoteUpdated=$remoteUpdated > localUpdated=${existing.updatedAt}');
        await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(companion);
      } else {
        flog('[syncFromJson] 跳过(本地更新): id=${id.substring(0, 8)}, localUpdated=${existing.updatedAt} >= remoteUpdated=$remoteUpdated');
      }
    } else {
      flog('[syncFromJson] 新增: id=${id.substring(0, 8)}, title=${json['title']}, deleted=$remoteDeleted, parentId=${json['parentId']?.toString().substring(0, 8) ?? 'null'}');
      await _db.into(_db.tasks).insert(TasksCompanion(
        id: Value(id),
        projectId: Value(json['projectId'] as String),
        title: Value(json['title'] as String),
        deleted: Value(remoteDeleted),
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
        createdAt: Value(json['createdAt'] as int? ?? remoteUpdated),
        updatedAt: Value(remoteUpdated),
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
