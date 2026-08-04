import 'dart:convert';
import '../database/app_database.dart';
import 'cloud_sync_gateway.dart';

/// 本地唯一后端网关（prd Final Architecture）。
/// 同步全部 no-op（数据只走本地 drift），仅快照导出/导入可用——快照即迁移到云端的桥。
class LocalOnlyCloudSyncGateway implements CloudSyncGateway {
  LocalOnlyCloudSyncGateway(this._db);

  final AppDatabase _db;

  @override
  Future<void> syncAll({bool forcePush = false}) async {}

  @override
  Future<void> pullAll() async {}

  @override
  void subscribe() {}

  @override
  void unsubscribe() {}

  @override
  Future<String> exportSnapshot() async {
    final projects = await _db.select(_db.projects).get();
    final tasks = await _db.select(_db.tasks).get();
    final checklists = await _db.select(_db.checklistItems).get();
    final groups = await _db.select(_db.projectGroups).get();
    final attachments = await _db.select(_db.taskAttachments).get();
    final templates = await _db.select(_db.nodeTemplates).get();
    final drafts = await _db.select(_db.lazyLogDrafts).get();
    final payload = <String, Object?>{
      'format': 'taskora-snapshot',
      'version': 1,
      'exportedAt': DateTime.now().millisecondsSinceEpoch,
      'projects': projects.map(_projectToMap).toList(),
      'tasks': tasks.map(_taskToMap).toList(),
      'checklistItems': checklists.map(_checklistToMap).toList(),
      'projectGroups': groups.map(_groupToMap).toList(),
      'taskAttachments': attachments.map(_attachmentToMap).toList(),
      'nodeTemplates': templates.map(_templateToMap).toList(),
      'lazyLogDrafts': drafts.map(_draftToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  @override
  Future<void> importSnapshot(String payload) async {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    if (json['format'] != 'taskora-snapshot') {
      throw ArgumentError('非 taskora 快照格式: ${json['format']}');
    }
    await _db.transaction(() async {
      for (final m in (json['projects'] as List? ?? const [])) {
        await _db.into(_db.projects).insertOnConflictUpdate(
              Project.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['tasks'] as List? ?? const [])) {
        await _db.into(_db.tasks).insertOnConflictUpdate(
              Task.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['checklistItems'] as List? ?? const [])) {
        await _db.into(_db.checklistItems).insertOnConflictUpdate(
              ChecklistItem.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['projectGroups'] as List? ?? const [])) {
        await _db.into(_db.projectGroups).insertOnConflictUpdate(
              ProjectGroup.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['taskAttachments'] as List? ?? const [])) {
        await _db.into(_db.taskAttachments).insertOnConflictUpdate(
              TaskAttachment.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['nodeTemplates'] as List? ?? const [])) {
        await _db.into(_db.nodeTemplates).insertOnConflictUpdate(
              NodeTemplate.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
      for (final m in (json['lazyLogDrafts'] as List? ?? const [])) {
        await _db.into(_db.lazyLogDrafts).insertOnConflictUpdate(
              LazyLogDraft.fromJson(m as Map<String, dynamic>).toCompanion(true),
            );
      }
    });
  }

  // --- 序列化：手动建 map（drift 数据类无 toJson），键名与 fromJson 对齐 ---

  static Map<String, dynamic> _projectToMap(Project p) => {
        'id': p.id,
        'name': p.name,
        'color': p.color,
        'groupId': p.groupId,
        'sortOrder': p.sortOrder,
        'archived': p.archived,
        'isTemplate': p.isTemplate,
        'deleted': p.deleted,
        'createdAt': p.createdAt,
        'updatedAt': p.updatedAt,
      };

  static Map<String, dynamic> _taskToMap(Task t) => {
        'id': t.id,
        'projectId': t.projectId,
        'parentId': t.parentId,
        'title': t.title,
        'description': t.description,
        'priority': t.priority,
        'status': t.status,
        'startDate': t.startDate,
        'dueDate': t.dueDate,
        'isAllDay': t.isAllDay,
        'completedTime': t.completedTime,
        'sortOrder': t.sortOrder,
        'deleted': t.deleted,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
        'remindBeforeMinutes': t.remindBeforeMinutes,
        'reminderEnabled': t.reminderEnabled,
        'estimatedMinutes': t.estimatedMinutes,
        'archived': t.archived,
      };

  static Map<String, dynamic> _checklistToMap(ChecklistItem c) => {
        'id': c.id,
        'taskId': c.taskId,
        'title': c.title,
        'status': c.status,
        'sortOrder': c.sortOrder,
        'obsidianUri': c.obsidianUri,
        'completedTime': c.completedTime,
        'deleted': c.deleted,
        'createdAt': c.createdAt,
        'updatedAt': c.updatedAt,
      };

  static Map<String, dynamic> _groupToMap(ProjectGroup g) => {
        'id': g.id,
        'name': g.name,
        'color': g.color,
        'sortOrder': g.sortOrder,
        'deleted': g.deleted,
        'createdAt': g.createdAt,
        'updatedAt': g.updatedAt,
      };

  static Map<String, dynamic> _attachmentToMap(TaskAttachment a) => {
        'id': a.id,
        'taskId': a.taskId,
        'fileName': a.fileName,
        'localPath': a.localPath,
        'storagePath': a.storagePath,
        'sizeBytes': a.sizeBytes,
        'mimeType': a.mimeType,
        'addedAt': a.addedAt,
        'updatedAt': a.updatedAt,
      };

  static Map<String, dynamic> _templateToMap(NodeTemplate n) => {
        'id': n.id,
        'name': n.name,
        'title': n.title,
        'description': n.description,
        'priority': n.priority,
        'checklistJson': n.checklistJson,
        'imagesJson': n.imagesJson,
        'subtasksJson': n.subtasksJson,
        'deleted': n.deleted,
        'createdAt': n.createdAt,
        'updatedAt': n.updatedAt,
      };

  static Map<String, dynamic> _draftToMap(LazyLogDraft d) => {
        'id': d.id,
        'batchId': d.batchId,
        'sourceInput': d.sourceInput,
        'status': d.status,
        'errorMessage': d.errorMessage,
        'summary': d.summary,
        'projectId': d.projectId,
        'parentTaskId': d.parentTaskId,
        'parentTitle': d.parentTitle,
        'title': d.title,
        'description': d.description,
        'priority': d.priority,
        'checklistJson': d.checklistJson,
        'startDate': d.startDate,
        'dueDate': d.dueDate,
        'sortOrder': d.sortOrder,
        'needsReview': d.needsReview,
        'createdTaskId': d.createdTaskId,
        'createdAt': d.createdAt,
        'updatedAt': d.updatedAt,
      };
}
