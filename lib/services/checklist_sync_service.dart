import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/checklist_repository.dart';

/// Supabase 直连同步服务：清单项（checklist_items）独立 CRUD + Realtime + 双向对账
class ChecklistSyncService {
  static final ChecklistSyncService instance = ChecklistSyncService._();
  ChecklistSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  ChecklistRepository? _repo;
  RealtimeChannel? _channel;

  void bind(ChecklistRepository repo) {
    _repo = repo;
  }

  // ── 兼容入口 ──
  Future<void> pullAll() => syncAll();

  /// 双向 LWW 全量对账
  Future<void> syncAll() async {
    if (_repo == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _client
          .from('checklist_items')
          .select()
          .eq('user_id', userId);

      final remoteById = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final m = row as Map<String, dynamic>;
        remoteById[m['id'] as String] = m;
        try {
          await _repo!.syncFromJson(_rowToJson(m));
        } catch (e) {
          print('[ChecklistSync] 合并失败 ${m['id']}: $e');
        }
      }

      final localRows = await _repo!.getAllRaw();
      for (final c in localRows) {
        final remote = remoteById[c.id];
        final remoteUpdated = remote?['updated_at'] as int? ?? -1;
        if (remote == null || c.updatedAt > remoteUpdated) {
          await push(c);
        }
      }
      print('[ChecklistSync] 全量对账完成: 云端 ${rows.length} / 本地 ${localRows.length}');
    } catch (e) {
      print('[ChecklistSync] 全量对账失败: $e');
    }
  }

  /// 推送一条清单项（upsert）
  Future<void> push(ChecklistItem item) async {
    if (_client.auth.currentUser == null) return;
    try {
      await _client.from('checklist_items').upsert(_toRow(item));
    } catch (e) {
      print('[ChecklistSync] 推送失败 ${item.id}: $e');
    }
  }

  // ── Realtime ──
  void subscribe() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }
    _channel?.unsubscribe();
    _channel = _client.channel('checklist_items_sync');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'checklist_items',
          callback: (p) => _onRemoteChange(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'checklist_items',
          callback: (p) => _onRemoteChange(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'checklist_items',
          callback: (p) => _onRemoteChange(p.oldRecord),
        );
    _channel!.subscribe();
    print('[ChecklistSync] Realtime 订阅已启动');
  }

  void _onRemoteChange(Map<String, dynamic>? record) {
    if (record == null || _repo == null) return;
    try {
      _repo!.syncFromJson(_rowToJson(record));
    } catch (e) {
      print('[ChecklistSync] 远端变更合并失败: $e');
    }
  }

  void unsubscribe() => _channel?.unsubscribe();

  // ── 格式转换 ──
  Map<String, dynamic> _toRow(ChecklistItem c) {
    return {
      'id': c.id,
      'user_id': _client.auth.currentUser!.id,
      'task_id': c.taskId,
      'title': c.title,
      'status': c.status,
      'sort_order': c.sortOrder,
      'obsidian_uri': c.obsidianUri,
      'completed_time': c.completedTime,
      'deleted': c.deleted,
      'created_at': c.createdAt,
      'updated_at': c.updatedAt,
    };
  }

  Map<String, dynamic> _rowToJson(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'taskId': row['task_id'],
      'title': row['title'] ?? '',
      'status': row['status'] ?? 0,
      'sortOrder': row['sort_order'] ?? 0,
      'obsidianUri': row['obsidian_uri'],
      'completedTime': row['completed_time'],
      'deleted': row['deleted'] ?? 0,
      'createdAt': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      'updatedAt': row['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
    };
  }
}
