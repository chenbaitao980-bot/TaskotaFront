import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/task_repository.dart';
import '../core/utils/file_logger.dart';

/// Supabase 直连同步服务：每一行任务独立 CRUD，支持 Realtime 实时推送
class TaskSyncService {
  static final TaskSyncService instance = TaskSyncService._();
  TaskSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  TaskRepository? _taskRepo;
  RealtimeChannel? _channel;
  Future<void>? _pendingOp; // 串行化 Realtime 回调，防止 database locked

  void bind(TaskRepository taskRepo) {
    _taskRepo = taskRepo;
  }

  // ── 全量拉取 ──

  /// 兼容旧调用入口
  Future<void> pullAll() => syncAll();

  /// 双向 LWW 全量对账：拉云端（含墓石）→ 本地合并；本地更新/云端缺失 → 推送上云
  Future<void> syncAll() async {
    if (_taskRepo == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // 合并前快照本地子任务
      final beforeMerge = await _taskRepo!.getAllRaw();
      final beforeChildren = beforeMerge.where((t) => t.parentId != null).toList();
      flog('[SyncAll] ===== 合并前本地子任务 (${beforeChildren.length}) =====');
      for (final bc in beforeChildren) {
        flog('[SyncAll]   BEFORE: id=${bc.id.substring(0, 8)}, title=${bc.title}, parentId=${bc.parentId?.substring(0, 8)}, deleted=${bc.deleted}, updatedAt=${bc.updatedAt}');
      }

      final rows = await _client
          .from('user_tasks')
          .select()
          .eq('user_id', userId);

      final remoteById = <String, Map<String, dynamic>>{};
      // DEBUG: 打印云端有parentId的任务
      final remoteChildren = (rows as List).where((r) => (r as Map)['parent_id'] != null).toList();
      flog('[SyncAll] 云端总数=${rows.length}, 有parent_id=${remoteChildren.length}');
      for (final rc in remoteChildren) {
        final m = rc as Map<String, dynamic>;
        flog('[SyncAll]   cloud child: id=${(m['id'] as String).substring(0, 8)}, title=${m['title']}, parent_id=${(m['parent_id'] as String?)?.substring(0, 8)}, deleted=${m['deleted']}');
      }
      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        remoteById[map['id'] as String] = map;
        try {
          await _taskRepo!.syncFromJson(_rowToJson(map));
        } catch (e) {
          flog('[Sync] 合并任务失败 ${map['id']}: $e');
        }
      }

      // 合并后检查子任务是否丢失
      final afterMerge = await _taskRepo!.getAllRaw();
      final afterChildren = afterMerge.where((t) => t.parentId != null).toList();
      if (afterChildren.length < beforeChildren.length) {
        flog('[SyncAll] ⚠️ 合并后子任务减少！${beforeChildren.length} → ${afterChildren.length}');
        for (final bc in beforeChildren) {
          final found = afterChildren.any((a) => a.id == bc.id);
          if (!found) {
            final afterRow = afterMerge.where((a) => a.id == bc.id).firstOrNull;
            flog('[SyncAll] ⚠️ 子任务丢失: id=${bc.id.substring(0, 8)}, title=${bc.title}, afterDeleted=${afterRow?.deleted}, afterParentId=${afterRow?.parentId?.substring(0, 8)}');
          }
        }
      }

      // 本地（含墓石）→ 云端缺失或本地更新则推送
      // 重新读取最新本地数据（前面的合并可能已修改本地行）
      final localRows = await _taskRepo!.getAllRaw();
      // DEBUG: 打印本地有parentId的任务
      final localChildren = localRows.where((t) => t.parentId != null).toList();
      flog('[SyncAll] 本地总数=${localRows.length}, 有parentId=${localChildren.length}');
      for (final lc in localChildren) {
        flog('[SyncAll]   local child: id=${lc.id.substring(0, 8)}, title=${lc.title}, parentId=${lc.parentId?.substring(0, 8)}, deleted=${lc.deleted}');
      }
      for (final t in localRows) {
        final remote = remoteById[t.id];
        final remoteUpdated = remote?['updated_at'] as int? ?? -1;
        final remoteDeleted = remote?['deleted'] as int? ?? 0;
        // 推送条件：云端缺失 / 本地更新 / 本地活但云端是墓石（修复残留墓石）
        if (remote == null || t.updatedAt > remoteUpdated ||
            (t.deleted == 0 && remoteDeleted == 1)) {
          if (t.deleted == 0 && remoteDeleted == 1) {
            flog('[SyncAll] 修复云端残留墓石: id=${t.id.substring(0, 8)}, title=${t.title}, 本地deleted=0 → 推送覆盖云端deleted=1');
          }
          await push(t);
        }
      }
      flog('[Sync] 全量对账完成: 云端 ${rows.length} 条 / 本地 ${localRows.length} 条');
    } catch (e) {
      flog('[Sync] 全量对账失败: $e');
    }
  }

  // ── 单行推送 ──

  /// 推送一条任务到云端（upsert）
  Future<void> push(Task task) async {
    if (_client.auth.currentUser == null) return;
    try {
      final json = _taskToRow(task);
      await _client.from('user_tasks').upsert(json);
    } catch (e) {
      flog('[Sync] 推送任务失败 ${task.id}: $e');
    }
  }

  /// 从云端删除一条任务
  Future<void> remove(String taskId) async {
    try {
      await _client.from('user_tasks').delete().eq('id', taskId);
    } catch (e) {
      flog('[Sync] 删除任务失败 $taskId: $e');
    }
  }

  // ── Realtime 实时订阅 ──

  /// 订阅云端变更，自动更新本地数据库
  void subscribe() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }
    _channel?.unsubscribe();
    _channel = _client.channel('user_tasks_sync');

    _channel!.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'user_tasks',
      callback: (payload) {
        _onRemoteChange(payload.newRecord);
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'user_tasks',
      callback: (payload) {
        _onRemoteChange(payload.newRecord);
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'user_tasks',
      callback: (payload) {
        _onRemoteDelete(payload.oldRecord);
      },
    );

    _channel!.subscribe();
    flog('[Sync] Realtime 订阅已启动');
  }

  /// 串行执行数据库操作，防止 Realtime 并发导致 database locked
  Future<void> _enqueue(Future<void> Function() op) async {
    final prev = _pendingOp;
    final completer = Completer<void>();
    _pendingOp = completer.future;
    try {
      if (prev != null) await prev;
      await op();
    } catch (e) {
      flog('[Sync] 串行队列操作失败: $e');
    } finally {
      completer.complete();
    }
  }

  void _onRemoteChange(Map<String, dynamic>? record) {
    if (record == null || _taskRepo == null) return;
    _enqueue(() async {
      try {
        final json = _rowToJson(record);
        await _taskRepo!.syncFromJson(json);
      } catch (e) {
        flog('[Sync] 远端变更合并失败: $e');
      }
    });
  }

  void _onRemoteDelete(Map<String, dynamic>? record) {
    if (record == null || _taskRepo == null) return;
    _enqueue(() async {
      try {
        final taskId = record['id'] as String;
        // 墓碑保护：检查本地任务是否存活
        final localTask = await _taskRepo!.get(taskId);
        if (localTask != null) {
          // 本地任务存活(deleted=0)，拒绝远端删除，反推存活版本上云
          flog('[Sync] 远端删除被拒绝: 本地活任务 $taskId 反推覆盖远端删除');
          await push(localTask);
          return;
        }
        // 本地不存在或已是墓碑，执行远端删除（写墓石 + 级联后代）
        await _taskRepo!.delete(taskId);
      } catch (e) {
        flog('[Sync] 远端删除失败: $e');
      }
    });
  }

  void unsubscribe() {
    _channel?.unsubscribe();
  }

  // ── 格式转换 ──

  Map<String, dynamic> _taskToRow(Task t) {
    return {
      'id': t.id,
      'user_id': _client.auth.currentUser!.id,
      'deleted': t.deleted,
      'project_id': t.projectId,
      'parent_id': t.parentId,
      'title': t.title,
      'description': t.description,
      'priority': t.priority,
      'status': t.status,
      'start_date': t.startDate,
      'due_date': t.dueDate,
      'is_all_day': t.isAllDay,
      'completed_time': t.completedTime,
      'sort_order': t.sortOrder,
      'remind_before_minutes': t.remindBeforeMinutes,
      'reminder_enabled': t.reminderEnabled,
      'estimated_minutes': t.estimatedMinutes,
      'created_at': t.createdAt,
      'updated_at': t.updatedAt,
    };
  }

  Map<String, dynamic> _rowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'deleted': row['deleted'] ?? 0,
      'projectId': row['project_id'],
      'parentId': row['parent_id'],
      'title': row['title'],
      'description': row['description'] ?? '',
      'priority': row['priority'] ?? 0,
      'status': row['status'] ?? 0,
      'startDate': row['start_date'],
      'dueDate': row['due_date'],
      'isAllDay': row['is_all_day'] ?? 0,
      'completedTime': row['completed_time'],
      'sortOrder': row['sort_order'] ?? 0,
      'remindBeforeMinutes': row['remind_before_minutes'] ?? 15,
      'reminderEnabled': row['reminder_enabled'] ?? 1,
      'estimatedMinutes': row['estimated_minutes'],
      'createdAt': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': row['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
