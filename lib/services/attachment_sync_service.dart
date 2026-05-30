import 'dart:async';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart' as db;

/// 附件 metadata 云同步：pullAll + Realtime upsert/delete。
/// 不下载文件本体 —— 用户点击附件时按需 download（TaskAttachmentService.ensureLocalFile）
class AttachmentSyncService {
  static final AttachmentSyncService instance = AttachmentSyncService._();
  AttachmentSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  db.AppDatabase? _db;
  RealtimeChannel? _channel;
  final _changesCtrl = StreamController<void>.broadcast();
  Stream<void> get changes => _changesCtrl.stream;
  void _emit() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }

  void bind(db.AppDatabase d) {
    _db = d;
  }

  Future<void> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _db == null) return;
    try {
      final rows = await _client
          .from('task_attachments')
          .select()
          .eq('user_id', userId);
      final remoteIds = <String>{};
      for (final r in (rows as List)) {
        final m = r as Map<String, dynamic>;
        remoteIds.add(m['id'] as String);
        await _upsertFromRow(m);
      }
      // 双向对账：本地有、云端缺失的 metadata 补传上云
      final localRows = await _db!.select(_db!.taskAttachments).get();
      for (final a in localRows) {
        if (!remoteIds.contains(a.id)) {
          await _pushRow(a, userId);
        }
      }
      print('[AttachSync] ✓ 对账完成: 云端 ${rows.length} / 本地 ${localRows.length}');
    } catch (e) {
      print('[AttachSync] ❌ 对账失败: $e');
    }
  }

  Future<void> _pushRow(db.TaskAttachment a, String userId) async {
    try {
      await _client.from('task_attachments').upsert({
        'id': a.id,
        'user_id': userId,
        'task_id': a.taskId,
        'file_name': a.fileName,
        'storage_path': a.storagePath,
        'size_bytes': a.sizeBytes,
        'mime_type': a.mimeType,
        'added_at': a.addedAt,
        'updated_at': a.updatedAt,
      });
    } catch (e) {
      print('[AttachSync] ❌ 补传 ${a.id} 失败: $e');
    }
  }

  void subscribe() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }
    _channel?.unsubscribe();
    _channel = _client.channel('attachments_sync');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'task_attachments',
          callback: (p) => _upsertFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'task_attachments',
          callback: (p) => _upsertFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'task_attachments',
          callback: (p) async {
            print('[AttachSync] DELETE oldRecord=${p.oldRecord}');
            final id = p.oldRecord['id'] as String?;
            if (id == null || _db == null) return;
            try {
              await (_db!.delete(_db!.taskAttachments)
                    ..where((t) => t.id.equals(id)))
                  .go();
              _emit();
            } catch (e) {
              print('[AttachSync] ❌ 本地删 attachment 失败 $id: $e');
            }
          },
        );
    _channel!.subscribe((status, [err]) {
      print('[AttachSync] channel status=$status ${err ?? ''}');
    });
  }

  void unsubscribe() => _channel?.unsubscribe();

  Future<void> _upsertFromRow(Map<String, dynamic> row) async {
    if (_db == null) return;
    final id = row['id'] as String?;
    if (id == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = db.TaskAttachmentsCompanion(
      id: Value(id),
      taskId: Value(row['task_id'] as String),
      fileName: Value(row['file_name'] as String? ?? ''),
      storagePath: Value(row['storage_path'] as String? ?? ''),
      sizeBytes: row['size_bytes'] != null
          ? Value((row['size_bytes'] as num).toInt())
          : const Value.absent(),
      mimeType: row['mime_type'] != null
          ? Value(row['mime_type'] as String)
          : const Value.absent(),
      addedAt: Value((row['added_at'] as num?)?.toInt() ?? now),
      updatedAt: Value((row['updated_at'] as num?)?.toInt() ?? now),
      // localPath 不从云端传入，保留本地值；新设备初次同步时 localPath=null，由 ensureLocalFile 按需补
    );
    await _db!.into(_db!.taskAttachments).insertOnConflictUpdate(companion);
    _emit();
  }
}
