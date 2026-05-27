import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/task_repository.dart';

/// Supabase 直连同步服务：每一行任务独立 CRUD，支持 Realtime 实时推送
class TaskSyncService {
  static final TaskSyncService instance = TaskSyncService._();
  TaskSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  TaskRepository? _taskRepo;
  RealtimeChannel? _channel;

  void bind(TaskRepository taskRepo) {
    _taskRepo = taskRepo;
  }

  // ── 全量拉取 ──

  /// 启动时全量拉取云端任务，覆盖本地缓存
  Future<void> pullAll() async {
    if (_taskRepo == null) return;
    try {
      final rows = await _client
          .from('user_tasks')
          .select()
          .eq('user_id', _client.auth.currentUser!.id);

      for (final row in (rows as List)) {
        final json = _rowToJson(row as Map<String, dynamic>);
        try {
          await _taskRepo!.syncFromJson(json);
        } catch (_) {}
      }
      print('[Sync] 全量拉取完成: ${rows.length} 条');
    } catch (e) {
      print('[Sync] 全量拉取失败: $e');
    }
  }

  // ── 单行推送 ──

  /// 推送一条任务到云端（upsert）
  Future<void> push(Task task) async {
    try {
      final json = _taskToRow(task);
      await _client.from('user_tasks').upsert(json);
    } catch (e) {
      print('[Sync] 推送任务失败 ${task.id}: $e');
    }
  }

  /// 从云端删除一条任务
  Future<void> remove(String taskId) async {
    try {
      await _client.from('user_tasks').delete().eq('id', taskId);
    } catch (e) {
      print('[Sync] 删除任务失败 $taskId: $e');
    }
  }

  // ── Realtime 实时订阅 ──

  /// 订阅云端变更，自动更新本地数据库
  void subscribe() {
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
    print('[Sync] Realtime 订阅已启动');
  }

  void _onRemoteChange(Map<String, dynamic>? record) {
    if (record == null || _taskRepo == null) return;
    try {
      final json = _rowToJson(record);
      _taskRepo!.syncFromJson(json);
    } catch (e) {
      print('[Sync] 远端变更合并失败: $e');
    }
  }

  void _onRemoteDelete(Map<String, dynamic>? record) async {
    if (record == null || _taskRepo == null) return;
    try {
      await _taskRepo!.delete(record['id'] as String);
    } catch (e) {
      print('[Sync] 远端删除失败: $e');
    }
  }

  void unsubscribe() {
    _channel?.unsubscribe();
  }

  // ── 格式转换 ──

  Map<String, dynamic> _taskToRow(Task t) {
    return {
      'id': t.id,
      'user_id': _client.auth.currentUser!.id,
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
