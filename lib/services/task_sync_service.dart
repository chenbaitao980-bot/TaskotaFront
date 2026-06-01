import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/task_repository.dart';
import '../core/utils/file_logger.dart';

/// Supabase 鐩磋繛鍚屾鏈嶅姟锛氭瘡涓€琛屼换鍔＄嫭绔?CRUD锛屾敮鎸?Realtime 瀹炴椂鎺ㄩ€?
class TaskSyncService {
  static final TaskSyncService instance = TaskSyncService._();
  TaskSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  TaskRepository? _taskRepo;
  RealtimeChannel? _channel;
  Future<void>? _pendingOp; // 涓茶鍖?Realtime 鍥炶皟锛岄槻姝?database locked
  final _changesCtrl = StreamController<void>.broadcast();
  Stream<void> get changes => _changesCtrl.stream;

  void _emitChange() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }

  void bind(TaskRepository taskRepo) {
    _taskRepo = taskRepo;
  }

  // 鈹€鈹€ 鍏ㄩ噺鎷夊彇 鈹€鈹€

  /// 鍏煎鏃ц皟鐢ㄥ叆鍙?
  Future<void> pullAll() => syncAll();

  /// 鍙屽悜 LWW 鍏ㄩ噺瀵硅处锛氭媺浜戠锛堝惈澧撶煶锛夆啋 鏈湴鍚堝苟锛涙湰鍦版洿鏂?浜戠缂哄け 鈫?鎺ㄩ€佷笂浜?
  Future<void> syncAll({bool rethrowErrors = false}) async {
    if (_taskRepo == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // 鍚堝苟鍓嶅揩鐓ф湰鍦板瓙浠诲姟
      final beforeMerge = await _taskRepo!.getAllRaw();
      final beforeChildren = beforeMerge
          .where((t) => t.parentId != null)
          .toList();
      flog('[SyncAll] ===== 鍚堝苟鍓嶆湰鍦板瓙浠诲姟 (${beforeChildren.length}) =====');
      for (final bc in beforeChildren) {
        flog(
          '[SyncAll]   BEFORE: id=${bc.id.substring(0, 8)}, title=${bc.title}, parentId=${bc.parentId?.substring(0, 8)}, deleted=${bc.deleted}, updatedAt=${bc.updatedAt}',
        );
      }

      final rows = await _client
          .from('user_tasks')
          .select()
          .eq('user_id', userId);

      final remoteById = <String, Map<String, dynamic>>{};
      // DEBUG: 鎵撳嵃浜戠鏈塸arentId鐨勪换鍔?
      final remoteChildren = (rows as List)
          .where((r) => (r as Map)['parent_id'] != null)
          .toList();
      flog(
        '[SyncAll] 浜戠鎬绘暟=${rows.length}, 鏈塸arent_id=${remoteChildren.length}',
      );
      for (final rc in remoteChildren) {
        final m = rc as Map<String, dynamic>;
        flog(
          '[SyncAll]   cloud child: id=${(m['id'] as String).substring(0, 8)}, title=${m['title']}, parent_id=${(m['parent_id'] as String?)?.substring(0, 8)}, deleted=${m['deleted']}',
        );
      }
      for (final row in rows) {
        final map = row;
        remoteById[map['id'] as String] = map;
        try {
          await _taskRepo!.syncFromJson(_rowToJson(map));
        } catch (e) {
          flog('[Sync] 鍚堝苟浠诲姟澶辫触 ${map['id']}: $e');
        }
      }

      // 鍚堝苟鍚庢鏌ュ瓙浠诲姟鏄惁涓㈠け
      final afterMerge = await _taskRepo!.getAllRaw();
      final afterChildren = afterMerge
          .where((t) => t.parentId != null)
          .toList();
      if (afterChildren.length < beforeChildren.length) {
        flog(
          '[SyncAll] 鈿狅笍 鍚堝苟鍚庡瓙浠诲姟鍑忓皯锛?{beforeChildren.length} 鈫?${afterChildren.length}',
        );
        for (final bc in beforeChildren) {
          final found = afterChildren.any((a) => a.id == bc.id);
          if (!found) {
            final afterRow = afterMerge.where((a) => a.id == bc.id).firstOrNull;
            flog(
              '[SyncAll] 鈿狅笍 瀛愪换鍔′涪澶? id=${bc.id.substring(0, 8)}, title=${bc.title}, afterDeleted=${afterRow?.deleted}, afterParentId=${afterRow?.parentId?.substring(0, 8)}',
            );
          }
        }
      }

      // 鏈湴锛堝惈澧撶煶锛夆啋 浜戠缂哄け鎴栨湰鍦版洿鏂板垯鎺ㄩ€?
      // 閲嶆柊璇诲彇鏈€鏂版湰鍦版暟鎹紙鍓嶉潰鐨勫悎骞跺彲鑳藉凡淇敼鏈湴琛岋級
      final localRows = await _taskRepo!.getAllRaw();
      // DEBUG: 鎵撳嵃鏈湴鏈塸arentId鐨勪换鍔?
      final localChildren = localRows.where((t) => t.parentId != null).toList();
      flog(
        '[SyncAll] 鏈湴鎬绘暟=${localRows.length}, 鏈塸arentId=${localChildren.length}',
      );
      for (final lc in localChildren) {
        flog(
          '[SyncAll]   local child: id=${lc.id.substring(0, 8)}, title=${lc.title}, parentId=${lc.parentId?.substring(0, 8)}, deleted=${lc.deleted}',
        );
      }
      for (final t in localRows) {
        final remote = remoteById[t.id];
        final remoteUpdated = remote?['updated_at'] as int? ?? -1;
        // 鎺ㄩ€佹潯浠讹細浜戠缂哄け / 鏈湴鏇存柊 / 鏈湴娲讳絾浜戠鏄鐭筹紙淇娈嬬暀澧撶煶锛?
        if (remote == null || t.updatedAt > remoteUpdated) {
          await push(t, rethrowErrors: rethrowErrors);
        }
      }
      flog(
        '[Sync] syncAll completed: remote=${rows.length}, local=${localRows.length}',
      );
    } catch (e) {
      if (rethrowErrors) rethrow;
      flog('[Sync] 鍏ㄩ噺瀵硅处澶辫触: $e');
    }
  }

  // 鈹€鈹€ 鍗曡鎺ㄩ€?鈹€鈹€

  /// 鎺ㄩ€佷竴鏉′换鍔″埌浜戠锛坲psert锛?
  Future<void> push(Task task, {bool rethrowErrors = false}) async {
    if (_client.auth.currentUser == null) return;
    try {
      final json = _taskToRow(task);
      await _client.from('user_tasks').upsert(json);
    } catch (e) {
      if (rethrowErrors) rethrow;
      flog('[Sync] 鎺ㄩ€佷换鍔″け璐?${task.id}: $e');
    }
  }

  /// 浠庝簯绔垹闄や竴鏉′换鍔?
  Future<void> remove(String taskId) async {
    try {
      await _client.from('user_tasks').delete().eq('id', taskId);
    } catch (e) {
      flog('[Sync] 鍒犻櫎浠诲姟澶辫触 $taskId: $e');
    }
  }

  // 鈹€鈹€ Realtime 瀹炴椂璁㈤槄 鈹€鈹€

  /// 璁㈤槄浜戠鍙樻洿锛岃嚜鍔ㄦ洿鏂版湰鍦版暟鎹簱
  void subscribe() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }
    _channel?.unsubscribe();
    _channel = _client.channel('user_tasks_sync');

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_tasks',
          callback: (payload) {
            _onRemoteChange(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_tasks',
          callback: (payload) {
            _onRemoteChange(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'user_tasks',
          callback: (payload) {
            _onRemoteDelete(payload.oldRecord);
          },
        );

    _channel!.subscribe();
    flog('[Sync] Realtime subscription started');
  }

  /// 涓茶鎵ц鏁版嵁搴撴搷浣滐紝闃叉 Realtime 骞跺彂瀵艰嚧 database locked
  Future<void> _enqueue(Future<void> Function() op) async {
    final prev = _pendingOp;
    final completer = Completer<void>();
    _pendingOp = completer.future;
    try {
      if (prev != null) await prev;
      await op();
    } catch (e) {
      flog('[Sync] 涓茶闃熷垪鎿嶄綔澶辫触: $e');
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
        _emitChange();
      } catch (e) {
        flog('[Sync] 杩滅鍙樻洿鍚堝苟澶辫触: $e');
      }
    });
  }

  void _onRemoteDelete(Map<String, dynamic>? record) {
    if (record == null || _taskRepo == null) return;
    _enqueue(() async {
      try {
        final taskId = record['id'] as String;
        // 澧撶淇濇姢锛氭鏌ユ湰鍦颁换鍔℃槸鍚﹀瓨娲?
        final localTask = await _taskRepo!.get(taskId);
        if (localTask != null) {
          // 鏈湴浠诲姟瀛樻椿(deleted=0)锛屾嫆缁濊繙绔垹闄わ紝鍙嶆帹瀛樻椿鐗堟湰涓婁簯
          flog('[Sync] 杩滅鍒犻櫎琚嫆缁? 鏈湴娲讳换鍔?$taskId 鍙嶆帹瑕嗙洊杩滅鍒犻櫎');
          await push(localTask);
          return;
        }
        // 鏈湴涓嶅瓨鍦ㄦ垨宸叉槸澧撶锛屾墽琛岃繙绔垹闄わ紙鍐欏鐭?+ 绾ц仈鍚庝唬锛?
        await _taskRepo!.delete(taskId);
        _emitChange();
      } catch (e) {
        flog('[Sync] 杩滅鍒犻櫎澶辫触: $e');
      }
    });
  }

  void unsubscribe() {
    _channel?.unsubscribe();
  }

  // 鈹€鈹€ 鏍煎紡杞崲 鈹€鈹€

  Map<String, dynamic> _taskToRow(Task t) {
    return taskToSyncRow(t, userId: _client.auth.currentUser!.id);
  }

  static Map<String, dynamic> taskToSyncRow(Task t, {required String userId}) {
    return {
      'id': t.id,
      'user_id': userId,
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
    return syncRowToTaskJson(row);
  }

  static Map<String, dynamic> syncRowToTaskJson(Map<String, dynamic> row) {
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
