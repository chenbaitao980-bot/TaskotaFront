import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/database/app_database.dart';
import '../data/repositories/node_template_repository.dart';

class NodeTemplateSyncService {
  static final NodeTemplateSyncService instance = NodeTemplateSyncService._();
  NodeTemplateSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  NodeTemplateRepository? _repo;
  RealtimeChannel? _channel;
  final _changesCtrl = StreamController<void>.broadcast();

  Stream<void> get changes => _changesCtrl.stream;

  void bind(NodeTemplateRepository repo) {
    _repo = repo;
  }

  Future<void> pullAll() => syncAll();

  Future<void> syncAll() async {
    if (_repo == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await _client
          .from('node_templates')
          .select()
          .eq('user_id', userId);
      final remoteById = <String, Map<String, dynamic>>{};
      for (final row in (rows as List)) {
        final map = row as Map<String, dynamic>;
        remoteById[map['id'] as String] = map;
        await _repo!.syncFromJson(_rowToJson(map));
      }

      final localRows = await _repo!.getAllRaw();
      for (final template in localRows) {
        final remote = remoteById[template.id];
        final remoteUpdated = remote?['updated_at'] as int? ?? -1;
        if (remote == null || template.updatedAt > remoteUpdated) {
          await push(template);
        }
      }
      _emitChange();
    } catch (e) {
      print('[NodeTemplateSync] syncAll failed: $e');
    }
  }

  Future<void> push(NodeTemplate template) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('node_templates').upsert(_toRow(template, userId));
    } catch (e) {
      print('[NodeTemplateSync] push failed ${template.id}: $e');
    }
  }

  void subscribe() {
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) _client.realtime.setAuth(token);
    _channel?.unsubscribe();
    _channel = _client.channel('node_templates_sync');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'node_templates',
          callback: (payload) => _onRemoteChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'node_templates',
          callback: (payload) => _onRemoteChange(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'node_templates',
          callback: (payload) => _onRemoteChange(payload.oldRecord),
        );
    _channel!.subscribe();
  }

  void unsubscribe() => _channel?.unsubscribe();

  void _onRemoteChange(Map<String, dynamic>? record) {
    if (record == null || _repo == null) return;
    () async {
      try {
        await _repo!.syncFromJson(_rowToJson(record));
        _emitChange();
      } catch (e) {
        print('[NodeTemplateSync] remote merge failed: $e');
      }
    }();
  }

  void _emitChange() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }

  Map<String, dynamic> _toRow(NodeTemplate template, String userId) => {
    'id': template.id,
    'user_id': userId,
    'name': template.name,
    'title': template.title,
    'description': template.description,
    'priority': template.priority,
    'checklist': jsonDecode(template.checklistJson),
    'images': jsonDecode(template.imagesJson),
    'subtasks': jsonDecode(template.subtasksJson),
    'deleted': template.deleted,
    'created_at': template.createdAt,
    'updated_at': template.updatedAt,
  };

  Map<String, dynamic> _rowToJson(Map<String, dynamic> row) => {
    'id': row['id'],
    'name': row['name'] ?? '',
    'title': row['title'] ?? '',
    'description': row['description'] ?? '',
    'priority': row['priority'] ?? 1,
    'checklist': row['checklist'] ?? const [],
    'images': row['images'] ?? const [],
    'subtasks': row['subtasks'] ?? const [],
    'deleted': row['deleted'] ?? 0,
    'createdAt': row['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
    'updatedAt': row['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
  };
}
