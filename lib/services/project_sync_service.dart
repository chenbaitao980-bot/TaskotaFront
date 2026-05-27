import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/project_group_repository.dart';

/// 项目 + 分组的云端同步
class ProjectSyncService {
  static final ProjectSyncService instance = ProjectSyncService._();
  ProjectSyncService._();

  final SupabaseClient _client = Supabase.instance.client;
  AppDatabase? _db;
  ProjectRepository? _projectRepo;
  ProjectGroupRepository? _groupRepo;
  RealtimeChannel? _channel;

  void bind({
    required AppDatabase db,
    required ProjectRepository projectRepo,
    required ProjectGroupRepository groupRepo,
  }) {
    _db = db;
    _projectRepo = projectRepo;
    _groupRepo = groupRepo;
  }

  Future<void> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _db == null) return;
    try {
      final groupRows = await _client
          .from('project_groups')
          .select()
          .eq('user_id', userId);
      for (final row in (groupRows as List)) {
        await _upsertGroupFromRow(row as Map<String, dynamic>);
      }
      final projRows = await _client
          .from('projects')
          .select()
          .eq('user_id', userId);
      for (final row in (projRows as List)) {
        await _upsertProjectFromRow(row as Map<String, dynamic>);
      }
      print('[ProjectSync] 拉取完成 groups=${groupRows.length} projects=${projRows.length}');
    } catch (e) {
      print('[ProjectSync] 拉取失败: $e');
    }
  }

  Future<void> pushProject(Project p) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('projects').upsert({
        'id': p.id,
        'user_id': userId,
        'name': p.name,
        'color': p.color,
        'group_id': p.groupId,
        'sort_order': p.sortOrder,
        'archived': p.archived,
        'created_at': p.createdAt,
        'updated_at': p.updatedAt,
      });
    } catch (e) {
      print('[ProjectSync] push project 失败 ${p.id}: $e');
    }
  }

  Future<void> removeProject(String id) async {
    try {
      await _client.from('projects').delete().eq('id', id);
    } catch (e) {
      print('[ProjectSync] 删除 project 失败 $id: $e');
    }
  }

  Future<void> pushGroup(ProjectGroup g) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.from('project_groups').upsert({
        'id': g.id,
        'user_id': userId,
        'name': g.name,
        'color': g.color,
        'sort_order': g.sortOrder,
        'created_at': g.createdAt,
        'updated_at': g.updatedAt,
      });
    } catch (e) {
      print('[ProjectSync] push group 失败 ${g.id}: $e');
    }
  }

  Future<void> removeGroup(String id) async {
    try {
      await _client.from('project_groups').delete().eq('id', id);
    } catch (e) {
      print('[ProjectSync] 删除 group 失败 $id: $e');
    }
  }

  void subscribe() {
    _channel?.unsubscribe();
    _channel = _client.channel('projects_sync');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'projects',
          callback: (p) => _upsertProjectFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'projects',
          callback: (p) => _upsertProjectFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'projects',
          callback: (p) async {
            final id = p.oldRecord['id'] as String?;
            if (id != null) await _projectRepo?.delete(id);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'project_groups',
          callback: (p) => _upsertGroupFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'project_groups',
          callback: (p) => _upsertGroupFromRow(p.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'project_groups',
          callback: (p) async {
            final id = p.oldRecord['id'] as String?;
            if (id != null) await _groupRepo?.delete(id);
          },
        );
    _channel!.subscribe();
  }

  void unsubscribe() => _channel?.unsubscribe();

  Future<void> _upsertProjectFromRow(Map<String, dynamic> row) async {
    if (_db == null) return;
    final id = row['id'] as String?;
    if (id == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = ProjectsCompanion(
      id: Value(id),
      name: Value(row['name'] as String? ?? ''),
      color: Value(row['color'] as String? ?? '#4772FA'),
      groupId: row['group_id'] != null
          ? Value(row['group_id'] as String)
          : const Value(null),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      archived: Value(row['archived'] as int? ?? 0),
      createdAt: Value(row['created_at'] as int? ?? now),
      updatedAt: Value(row['updated_at'] as int? ?? now),
    );
    await _db!.into(_db!.projects).insertOnConflictUpdate(companion);
  }

  Future<void> _upsertGroupFromRow(Map<String, dynamic> row) async {
    if (_db == null) return;
    final id = row['id'] as String?;
    if (id == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = ProjectGroupsCompanion(
      id: Value(id),
      name: Value(row['name'] as String? ?? ''),
      color: Value(row['color'] as String? ?? '#4772FA'),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      createdAt: Value(row['created_at'] as int? ?? now),
      updatedAt: Value(row['updated_at'] as int? ?? now),
    );
    await _db!.into(_db!.projectGroups).insertOnConflictUpdate(companion);
  }
}
