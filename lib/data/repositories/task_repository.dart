import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../../core/exceptions/quota_exceeded_exception.dart';
import '../../services/task_sync_service.dart';
import '../../services/subscription_service.dart';
import '../../core/utils/file_logger.dart';

class TaskRepository {
  final AppDatabase _db;
  final TaskSyncService? _syncService;
  TaskRepository(this._db, {TaskSyncService? syncService})
    : _syncService = syncService;

  Future<List<Task>> getAll({
    String? projectId,
    int? status,
    int? priority,
  }) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.deleted.equals(0) & t.archived.equals(0))
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
      ..where((t) => t.parentId.isNull() & t.deleted.equals(0) & t.archived.equals(0))
      ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]);
    if (projectId != null) {
      query.where((t) => t.projectId.equals(projectId));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status));
    }
    return query.get();
  }

  Future<int> getActiveCountForProject(String projectId) async {
    final countExp = countAll();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([countExp])
      ..where(_db.tasks.projectId.equals(projectId) &
          _db.tasks.deleted.equals(0) &
          _db.tasks.archived.equals(0));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  Future<List<Task>> getByProject(String projectId, {int? status}) async {
    final query = _db.select(_db.tasks)
      ..where((t) => t.projectId.equals(projectId) & t.deleted.equals(0) & t.archived.equals(0))
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
          ..where(
            (t) =>
                t.dueDate.isBetween(
                  Variable(startOfDay.millisecondsSinceEpoch),
                  Variable(endOfDay.millisecondsSinceEpoch),
                ) &
                t.deleted.equals(0) &
                t.archived.equals(0),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.priority, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<List<Task>> getImportant() async {
    return (_db.select(_db.tasks)
          ..where(
            (t) =>
                t.priority.equals(5) & t.status.equals(0) & t.deleted.equals(0) & t.archived.equals(0),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.dueDate)]))
        .get();
  }

  /// 获取所有已归档任务（未删除），支持搜索关键词和日期区间过滤
  Future<List<Task>> getArchived({String? searchKeyword, int? dateFrom, int? dateTo}) async {
    final query = _db.select(_db.tasks);
    if (searchKeyword != null && searchKeyword.isNotEmpty) {
      final pattern = '%$searchKeyword%';
      query.where((t) =>
          t.archived.equals(1) &
          t.deleted.equals(0) &
          (t.title.like(pattern) | t.description.like(pattern)));
    } else {
      query.where((t) => t.archived.equals(1) & t.deleted.equals(0));
    }
    query.orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);

    // 日期区间过滤下推为 SQL：任务的 [startDate, dueDate] 与 [dateFrom, dateTo] 有交集
    // coalesce 两列均为 NULL 时条件求值为 NULL（不命中），与原内存过滤的 return false 等价
    if (dateFrom != null && dateTo != null) {
      query.where((t) {
        final taskStart = coalesce<int>([t.startDate, t.dueDate]);
        final taskEnd = coalesce<int>([t.dueDate, t.startDate]);
        return taskStart.isSmallerOrEqualValue(dateTo) &
            taskEnd.isBiggerOrEqualValue(dateFrom);
      });
    }

    return query.get();
  }

  /// 归档任务（递归将所有后代也设为 archived=1）
  Future<void> archiveTask(String id, {bool syncImmediately = true}) async {
    final descendants = await getDescendants(id);
    final ids = <String>[id, ...descendants.map((d) => d.id)];
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final tid in ids) {
        batch.update(
          _db.tasks,
          TasksCompanion(archived: const Value(1), updatedAt: Value(now)),
          where: (t) => t.id.equals(tid),
        );
      }
    });
    if (syncImmediately) {
      final rows = await _getRawByIds(ids);
      for (final row in rows) {
        _syncService?.push(row);
      }
    }
  }

  /// 取消归档（仅恢复自身，子任务保持各自归档状态）
  Future<void> unarchiveTask(String id, {bool syncImmediately = true}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(archived: const Value(0), updatedAt: Value(now)),
    );
    if (syncImmediately) {
      final updated = await _getRaw(id);
      if (updated != null) _syncService?.push(updated);
    }
  }

  /// 检查任务的所有后代是否都已完成（status==2），用于归档前拦截
  Future<bool> allDescendantsCompleted(String id) async {
    final descendants = await getDescendants(id);
    if (descendants.isEmpty) return true;
    return descendants.every((t) => t.status == 2);
  }

  /// Search task IDs matching keyword in title, description, or checklist item titles.
  /// Returns a set of matching task IDs for intersection with existing filters.
  Future<Set<String>> searchTaskIds(String keyword) async {
    final pattern = '%$keyword%';
    // Tasks matching by title or description
    final tasksMatch = await (_db.select(_db.tasks)
      ..where((t) =>
          t.deleted.equals(0) &
          t.archived.equals(0) &
          (t.title.like(pattern) | t.description.like(pattern)))
    ).get();
    final matchedIds = tasksMatch.map((t) => t.id).toSet();
    // Tasks matching by checklist item titles
    final checklistMatch = await (_db.select(_db.checklistItems)
      ..where((c) => c.deleted.equals(0) & c.title.like(pattern))
    ).get();
    matchedIds.addAll(checklistMatch.map((c) => c.taskId));
    return matchedIds;
  }

  Future<Task?> get(String id) async {
    final result = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id) & t.deleted.equals(0))).get();
    return result.isNotEmpty ? result.first : null;
  }

  // --- 子任务树 ---

  Future<List<Task>> getSubTasks(String parentId) async {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId) & t.deleted.equals(0) & t.archived.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// 获取子任务（含归档），用于归档前递归检查
  Future<List<Task>> getSubTasksIncludingArchived(String parentId) async {
    return (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(parentId) & t.deleted.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// 检查任务是否有子任务（至少一个）
  Future<bool> hasChildren(String id) async {
    final result = await (_db.select(_db.tasks)
          ..where((t) => t.parentId.equals(id) & t.deleted.equals(0))
          ..limit(1))
        .get();
    return result.isNotEmpty;
  }

  /// 从当前层向上追溯，扩展每层父任务的时间范围覆盖所有子任务
  /// 当子任务缩小时会重新计算所有子任务的 min/max，支持回缩
  Future<void> expandAncestorDates(
    String? childParentId,
    int? childStart,
    int? childEnd, {
    bool syncImmediately = true,
  }) async {
    String? currentParentId = childParentId;
    while (currentParentId != null) {
      final parent = await get(currentParentId);
      if (parent == null) break;

      int? ns = parent.startDate;
      int? nd = parent.dueDate;

      // 1) 先尝试向外扩展（子任务超出父范围）
      if (childStart != null) {
        ns = (ns == null || childStart < ns) ? childStart : ns;
      }
      if (childEnd != null) {
        nd = (nd == null || childEnd > nd) ? childEnd : nd;
      }

      // 2) 如果子任务在父范围内（本次未扩展），重新计算所有子任务的真实范围，支持回缩
      if (ns == parent.startDate && nd == parent.dueDate) {
        final children = await getSubTasks(parent.id);
        int? minStart, maxEnd;
        for (final c in children) {
          if (c.startDate != null) {
            minStart =
                (minStart == null || c.startDate! < minStart)
                    ? c.startDate!
                    : minStart;
          }
          if (c.dueDate != null) {
            maxEnd =
                (maxEnd == null || c.dueDate! > maxEnd)
                    ? c.dueDate!
                    : maxEnd;
          }
        }
        ns = minStart ?? ns;
        nd = maxEnd ?? nd;
      }

      if (ns != parent.startDate || nd != parent.dueDate) {
        await update(
          parent.id,
          startDate: ns,
          dueDate: nd,
          syncImmediately: syncImmediately,
        );
      }
      currentParentId = parent.parentId;
    }
  }

  Future<List<Task>> getDescendants(String taskId) async {
    // 一次 SELECT 取全部活动行（未删除、未归档，按 sortOrder 排序），
    // 内存建 parentId → children 索引后 BFS，保持与逐层查询相同的返回顺序
    final allActive = await (_db.select(_db.tasks)
          ..where((t) => t.deleted.equals(0) & t.archived.equals(0))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    final childrenMap = <String, List<Task>>{};
    for (final task in allActive) {
      final pid = task.parentId;
      if (pid != null) {
        (childrenMap[pid] ??= <Task>[]).add(task);
      }
    }
    final result = <Task>[];
    final queue = <String>[taskId];
    var head = 0;
    while (head < queue.length) {
      final current = queue[head++];
      final children = childrenMap[current] ?? const [];
      for (final child in children) {
        result.add(child);
        queue.add(child.id);
      }
    }
    return result;
  }

  /// 按 ids 一次批量回读（不过滤墓石），保持入参顺序
  Future<List<Task>> _getRawByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows =
        await (_db.select(_db.tasks)..where((t) => t.id.isIn(ids))).get();
    final byId = {for (final r in rows) r.id: r};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// 按 ids 一次批量回读（过滤墓石 deleted=0），保持入参顺序
  Future<List<Task>> _getLiveByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await (_db.select(_db.tasks)
          ..where((t) => t.id.isIn(ids) & t.deleted.equals(0)))
        .get();
    final byId = {for (final r in rows) r.id: r};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
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

  Future<void> moveTask(
    String taskId,
    String? newParentId, {
    bool syncImmediately = true,
  }) async {
    await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        parentId: newParentId != null ? Value(newParentId) : const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    if (syncImmediately) {
      final updated = await get(taskId);
      if (updated != null) _syncService?.push(updated);
    }
  }

  Future<void> reorderSubTasks(
    String? parentId,
    List<String> orderedIds, {
    bool syncImmediately = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.tasks,
          TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
    if (syncImmediately) {
      final rows = await _getLiveByIds(orderedIds);
      for (final row in rows) {
        _syncService?.push(row);
      }
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
    int remindBeforeMinutes = 15,
    int reminderEnabled = 1,
    bool syncImmediately = true,
  }) async {
    final count = await getActiveCountForProject(projectId);
    final canCreate =
        await SubscriptionService.instance.canCreateTask(count);
    if (!canCreate) {
      throw QuotaExceededException(
        '该项目任务数已达上限(50个)，升级VIP解锁无限任务',
        QuotaType.task,
      );
    }

    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.tasks)
        .insert(
          TasksCompanion(
            id: Value(id),
            projectId: Value(projectId),
            title: Value(title),
            description: Value(description),
            priority: Value(priority),
            isAllDay: Value(isAllDay ? 1 : 0),
            parentId: parentId != null ? Value(parentId) : const Value.absent(),
            startDate: startDate != null
                ? Value(startDate)
                : const Value.absent(),
            dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
            estimatedMinutes: estimatedMinutes != null
                ? Value(estimatedMinutes)
                : const Value.absent(),
            remindBeforeMinutes: Value(remindBeforeMinutes),
            reminderEnabled: Value(reminderEnabled),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final result = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).get();
    final task = result.first;
    if (syncImmediately) {
      // fire-and-forget：本地写完立即返回，推送失败由全量对账兜底
      unawaited(_syncService?.push(task));
    }
    return task;
  }

  Future<void> update(
    String id, {
    String? projectId,
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
    int? estimatedMinutes,
    bool syncImmediately = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        projectId: projectId != null ? Value(projectId) : const Value.absent(),
        title: title != null ? Value(title) : const Value.absent(),
        description: description != null
            ? Value(description)
            : const Value.absent(),
        priority: priority != null ? Value(priority) : const Value.absent(),
        startDate: startDate != null ? Value(startDate) : const Value.absent(),
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
    if (syncImmediately && updated != null) _syncService?.push(updated);

    // 项目变更时级联同步到所有后代
    if (projectId != null) {
      await _cascadeProjectId(id, projectId, syncImmediately: syncImmediately);
    }
  }

  /// 把指定任务的所有后代的 projectId 改为 newProjectId
  Future<void> _cascadeProjectId(
    String rootId,
    String newProjectId, {
    bool syncImmediately = true,
  }) async {
    final descendants = await getDescendants(rootId);
    if (descendants.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final d in descendants) {
        if (d.projectId == newProjectId) continue;
        batch.update(
          _db.tasks,
          TasksCompanion(projectId: Value(newProjectId), updatedAt: Value(now)),
          where: (t) => t.id.equals(d.id),
        );
      }
    });
    if (syncImmediately) {
      final changedIds = [
        for (final d in descendants)
          if (d.projectId != newProjectId) d.id,
      ];
      final rows = await _getLiveByIds(changedIds);
      for (final row in rows) {
        _syncService?.push(row);
      }
    }
  }

  Future<void> delete(String id, {bool syncImmediately = true}) async {
    // 软删除：自身 + 全部后代写墓石，每个 id 推送上云（带 deleted=1）
    final descendants = await getDescendants(id);
    final ids = <String>[id, ...descendants.map((d) => d.id)];
    flog(
      '[TaskRepo.delete] id=${id.substring(0, 8)}, 级联删除 ${ids.length} 条 (自身+${descendants.length}后代)',
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final tid in ids) {
        batch.update(
          _db.tasks,
          TasksCompanion(deleted: const Value(1), updatedAt: Value(now)),
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
    if (syncImmediately) {
      final rows = await _getRawByIds(ids);
      for (final row in rows) {
        _syncService?.push(row);
      }
    }
  }

  /// 不过滤墓石地读取全部行（用于全量对账上推）
  Future<List<Task>> getAllRaw() => _db.select(_db.tasks).get();

  Future<void> restoreRawTasks(List<Task> snapshot) async {
    // 只 upsert 快照中的任务，不删除任何行
    // 避免误删：新建任务、Realtime 同步来的任务
    await _db.transaction(() async {
      for (final task in snapshot) {
        await _db.into(_db.tasks).insertOnConflictUpdate(task);
      }
    });
  }

  /// 不过滤墓石地读取一行（用于删除后推送墓石）
  Future<Task?> _getRaw(String id) async {
    final result = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.equals(id))).get();
    return result.isNotEmpty ? result.first : null;
  }

  Future<void> toggleStatus(String id, {bool syncImmediately = true}) async {
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
    if (syncImmediately && toggled != null) _syncService?.push(toggled);
    if (newStatus == 2) {
      await completeEligibleAncestors(id, syncImmediately: syncImmediately);
    }
  }

  Future<void> setStatusCascade(
    String id,
    int status, {
    bool includeDescendants = false,
    bool syncImmediately = true,
  }) async {
    final task = await get(id);
    if (task == null) return;
    final descendants = includeDescendants
        ? await getDescendants(id)
        : <Task>[];
    final ids = <String>[id, ...descendants.map((t) => t.id)];
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (final taskId in ids) {
        batch.update(
          _db.tasks,
          TasksCompanion(
            status: Value(status),
            completedTime: status == 2 ? Value(now) : const Value.absent(),
            updatedAt: Value(now),
          ),
          where: (t) => t.id.equals(taskId),
        );
      }
    });
    if (syncImmediately) {
      final rows = await _getLiveByIds(ids);
      for (final row in rows) {
        _syncService?.push(row);
      }
    }
    if (status == 2) {
      await completeEligibleAncestors(id, syncImmediately: syncImmediately);
    }
  }

  Future<void> completeEligibleAncestors(
    String taskId, {
    bool syncImmediately = true,
  }) async {
    var child = await get(taskId);
    while (child?.parentId != null) {
      final parent = await get(child!.parentId!);
      if (parent == null || parent.status == 2) {
        child = parent;
        continue;
      }
      final siblings = await getSubTasks(parent.id);
      if (siblings.isEmpty || siblings.any((t) => t.status != 2)) break;

      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.tasks)..where((t) => t.id.equals(parent.id))).write(
        TasksCompanion(
          status: const Value(2),
          completedTime: Value(now),
          updatedAt: Value(now),
        ),
      );
      final updated = await get(parent.id);
      if (syncImmediately && updated != null) _syncService?.push(updated);
      child = updated;
    }
  }

  /// 从云端同步导入任务（插入或更新，保留原始 ID）
  /// 使用远端 updatedAt 做 LWW，保留远端时间戳避免反推覆盖
  Future<void> syncFromJson(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final remoteUpdated = json['updatedAt'] as int? ?? 0;
    final remoteDeleted = json['deleted'] as int? ?? 0;
    final existing = await _getRaw(id);

    flog(
      '[syncFromJson] 开始: id=${id.substring(0, 8)}, remoteDeleted=$remoteDeleted, remoteUpdated=$remoteUpdated, remoteParentId=${json['parentId']?.toString().substring(0, 8) ?? 'null'}, remoteStatus=${json['status']}',
    );

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
      archived: Value(json['archived'] as int? ?? 0),
      updatedAt: Value(remoteUpdated),
    );

    if (existing != null) {
      flog(
        '[syncFromJson] 本地已存在: id=${id.substring(0, 8)}, localDeleted=${existing.deleted}, localUpdated=${existing.updatedAt}, localParentId=${existing.parentId?.substring(0, 8) ?? 'null'}, localStatus=${existing.status}',
      );
      // 墓石保护：本地已删除且时间戳>=远端，不被远端未删除状态覆盖
      if (existing.deleted == 1 &&
          remoteDeleted == 0 &&
          existing.updatedAt >= remoteUpdated) {
        flog('[syncFromJson] 墓石保护: 本地墓碑 ${id.substring(0, 8)} 拒绝被远端live覆盖');
        return;
      }
      // 反向保护：本地未删除(活任务)不被远端墓石覆盖
      if (existing.deleted == 0 &&
          remoteDeleted == 1 &&
          existing.updatedAt > remoteUpdated) {
        flog(
          '[syncFromJson] 反向墓石保护: 本地活任务 ${id.substring(0, 8)} 拒绝被远端墓石覆盖, localUpdated=${existing.updatedAt}, remoteUpdated=$remoteUpdated',
        );
        // 本地是活的，远端要删除 → 以本地为准，反推到云端
        return;
      }
      // 仅当云端版本更新时才更新
      if (remoteUpdated > existing.updatedAt) {
        final changedFields = <String>[];
        if (remoteDeleted != existing.deleted)
          changedFields.add('deleted:${existing.deleted}→$remoteDeleted');
        if (json['parentId'] != existing.parentId)
          changedFields.add(
            'parentId:${existing.parentId?.substring(0, 8) ?? 'null'}→${json['parentId']?.toString().substring(0, 8) ?? 'null'}',
          );
        if ((json['status'] as int? ?? 0) != existing.status)
          changedFields.add('status:${existing.status}→${json['status']}');
        flog(
          '[syncFromJson] ☁️ 云端更新: id=${id.substring(0, 8)}, 变更字段=[${changedFields.join(', ')}], remoteUpdated=$remoteUpdated > localUpdated=${existing.updatedAt}',
        );
        await (_db.update(
          _db.tasks,
        )..where((t) => t.id.equals(id))).write(companion);
      } else {
        flog(
          '[syncFromJson] 跳过(本地更新): id=${id.substring(0, 8)}, localUpdated=${existing.updatedAt} >= remoteUpdated=$remoteUpdated',
        );
      }
    } else {
      flog(
        '[syncFromJson] 新增: id=${id.substring(0, 8)}, title=${json['title']}, deleted=$remoteDeleted, parentId=${json['parentId']?.toString().substring(0, 8) ?? 'null'}',
      );
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion(
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
              archived: Value(json['archived'] as int? ?? 0),
              completedTime: json['completedTime'] != null
                  ? Value(json['completedTime'] as int)
                  : const Value.absent(),
              createdAt: Value(json['createdAt'] as int? ?? remoteUpdated),
              updatedAt: Value(remoteUpdated),
            ),
          );
    }
  }

  /// 批量版 syncFromJson：一次取本地全部行建 Map 做 LWW 判断，
  /// 胜出行统一 batch 写入并整体包事务。LWW/墓石保护逻辑与 syncFromJson 完全一致。
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
    final localMap = {for (final t in localRows) t.id: t};

    final inserts = <TasksCompanion>[];
    final updates = <String, TasksCompanion>{};
    var skipped = 0;

    for (final json in byId.values) {
      final id = json['id'] as String;
      final remoteUpdated = json['updatedAt'] as int? ?? 0;
      final remoteDeleted = json['deleted'] as int? ?? 0;
      final existing = localMap[id];

      if (existing != null) {
        // 墓石保护：本地已删除且时间戳>=远端，不被远端未删除状态覆盖
        if (existing.deleted == 1 &&
            remoteDeleted == 0 &&
            existing.updatedAt >= remoteUpdated) {
          skipped++;
          continue;
        }
        // 反向保护：本地未删除(活任务)不被远端墓石覆盖
        if (existing.deleted == 0 &&
            remoteDeleted == 1 &&
            existing.updatedAt > remoteUpdated) {
          skipped++;
          continue;
        }
        // 仅当云端版本更新时才更新
        if (remoteUpdated > existing.updatedAt) {
          updates[id] = TasksCompanion(
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
            archived: Value(json['archived'] as int? ?? 0),
            updatedAt: Value(remoteUpdated),
          );
        } else {
          skipped++;
        }
      } else {
        inserts.add(
          TasksCompanion(
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
            archived: Value(json['archived'] as int? ?? 0),
            completedTime: json['completedTime'] != null
                ? Value(json['completedTime'] as int)
                : const Value.absent(),
            createdAt: Value(json['createdAt'] as int? ?? remoteUpdated),
            updatedAt: Value(remoteUpdated),
          ),
        );
      }
    }

    if (inserts.isNotEmpty || updates.isNotEmpty) {
      await _db.transaction(() async {
        await _db.batch((batch) {
          for (final companion in inserts) {
            batch.insert(_db.tasks, companion);
          }
          for (final entry in updates.entries) {
            batch.update(
              _db.tasks,
              entry.value,
              where: (t) => t.id.equals(entry.key),
            );
          }
        });
      });
    }
    flog(
      '[syncManyFromJson] tasks 批量合并: 共${byId.length}行, 新增${inserts.length}, 更新${updates.length}, 跳过$skipped',
    );
  }

  Future<void> reorder(String projectId, List<String> orderedIds) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.batch((batch) {
      for (var i = 0; i < orderedIds.length; i++) {
        batch.update(
          _db.tasks,
          TasksCompanion(sortOrder: Value(i), updatedAt: Value(now)),
          where: (t) => t.id.equals(orderedIds[i]),
        );
      }
    });
  }
}
