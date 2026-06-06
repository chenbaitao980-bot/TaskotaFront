import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../models/node_template_payload.dart';
import '../../services/node_template_sync_service.dart';
import '../database/app_database.dart';

class NodeTemplateRepository {
  final AppDatabase _db;
  final NodeTemplateSyncService? _syncService;

  NodeTemplateRepository(this._db, {NodeTemplateSyncService? syncService})
    : _syncService = syncService;

  Future<List<NodeTemplate>> getAll() {
    return (_db.select(_db.nodeTemplates)
          ..where((template) => template.deleted.equals(0))
          ..orderBy([(template) => OrderingTerm.desc(template.updatedAt)]))
        .get();
  }

  Future<List<NodeTemplate>> getAllRaw() => _db.select(_db.nodeTemplates).get();

  Future<NodeTemplate?> get(String id) async {
    final rows = await (_db.select(
      _db.nodeTemplates,
    )..where((template) => template.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  NodeTemplatePayload payloadOf(NodeTemplate template) {
    return NodeTemplatePayload(
      checklistTitles: NodeTemplatePayload.decodeChecklist(
        template.checklistJson,
      ),
      images: NodeTemplatePayload.decodeImages(template.imagesJson),
      subtasks: NodeTemplatePayload.decodeSubtasks(template.subtasksJson),
    );
  }

  Future<NodeTemplate> create({
    required String name,
    required String title,
    required String description,
    required int priority,
    required NodeTemplatePayload payload,
    bool syncImmediately = true,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.nodeTemplates)
        .insert(
          NodeTemplatesCompanion(
            id: Value(id),
            name: Value(name),
            title: Value(title),
            description: Value(description),
            priority: Value(priority),
            checklistJson: Value(payload.encodeChecklist()),
            imagesJson: Value(payload.encodeImages()),
            subtasksJson: Value(payload.encodeSubtasks()),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final template = (await (_db.select(
      _db.nodeTemplates,
    )..where((row) => row.id.equals(id))).get()).first;
    if (syncImmediately) await _syncService?.push(template);
    return template;
  }

  Future<void> update(
    String id, {
    required String name,
    required String title,
    required String description,
    required int priority,
    required NodeTemplatePayload payload,
    bool syncImmediately = true,
  }) async {
    await (_db.update(
      _db.nodeTemplates,
    )..where((row) => row.id.equals(id))).write(
      NodeTemplatesCompanion(
        name: Value(name),
        title: Value(title),
        description: Value(description),
        priority: Value(priority),
        checklistJson: Value(payload.encodeChecklist()),
        imagesJson: Value(payload.encodeImages()),
        subtasksJson: Value(payload.encodeSubtasks()),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    if (syncImmediately) {
      final template = await get(id);
      if (template != null) await _syncService?.push(template);
    }
  }

  Future<void> delete(String id, {bool syncImmediately = true}) async {
    await (_db.update(
      _db.nodeTemplates,
    )..where((row) => row.id.equals(id))).write(
      NodeTemplatesCompanion(
        deleted: const Value(1),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    if (syncImmediately) {
      final template = await get(id);
      if (template != null) await _syncService?.push(template);
    }
  }

  Future<void> syncFromJson(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remoteUpdated = json['updatedAt'] as int? ?? now;
    final existing = await get(id);
    if (existing != null && existing.updatedAt >= remoteUpdated) return;

    final companion = NodeTemplatesCompanion(
      id: Value(id),
      name: Value(json['name'] as String? ?? ''),
      title: Value(json['title'] as String? ?? ''),
      description: Value(json['description'] as String? ?? ''),
      priority: Value(json['priority'] as int? ?? 1),
      checklistJson: Value(jsonEncode(json['checklist'] ?? const [])),
      imagesJson: Value(jsonEncode(json['images'] ?? const [])),
      subtasksJson: Value(jsonEncode(json['subtasks'] ?? const [])),
      deleted: Value(json['deleted'] as int? ?? 0),
      createdAt: Value(json['createdAt'] as int? ?? remoteUpdated),
      updatedAt: Value(remoteUpdated),
    );

    if (existing == null) {
      await _db.into(_db.nodeTemplates).insert(companion);
    } else {
      await (_db.update(
        _db.nodeTemplates,
      )..where((row) => row.id.equals(id))).write(companion);
    }
  }
}
