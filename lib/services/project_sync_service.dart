import 'dart:async';
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

  // 远端任何变更（拉取/订阅 upsert/delete）写入本地 db 后广播，
  // 供 UI 层（home_page）刷新 bloc 用
  final _changesCtrl = StreamController<void>.broadcast();
  Stream<void> get changes => _changesCtrl.stream;
  void _emitChange() {
    if (!_changesCtrl.isClosed) _changesCtrl.add(null);
  }

  void bind({
    required AppDatabase db,
    required ProjectRepository projectRepo,
    required ProjectGroupRepository groupRepo,
  }) {
    _db = db;
    _projectRepo = projectRepo;
    _groupRepo = groupRepo;
  }

  Future<void> pullAll() => syncAll();

  /// 双向 LWW 全量对账：拉云端（含墓石）合并到本地；本地更新/云端缺失则推送上云
  Future<void> syncAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _db == null) return;
    try {
      final groupRows = await _client
          .from('project_groups')
          .select()
          .eq('user_id', userId);
      final remoteGroups = <String, Map<String, dynamic>>{};
      for (final row in (groupRows as List)) {
        final m = row as Map<String, dynamic>;
        remoteGroups[m['id'] as String] = m;
        await _upsertGroupFromRow(m);
      }
      final projRows = await _client
          .from('projects')
          .select()
          .eq('user_id', userId);
      final remoteProjects = <String, Map<String, dynamic>>{};
      for (final row in (projRows as List)) {
        final m = row as Map<String, dynamic>;
        remoteProjects[m['id'] as String] = m;
        await _upsertProjectFromRow(m);
      }

      // 本地（含墓石）→ 云端缺失或本地更新则推送
      if (_groupRepo != null) {
        for (final g in await _groupRepo!.getAllRaw()) {
          final r = remoteGroups[g.id];
          if (r == null || g.updatedAt > (r['updated_at'] as int? ?? -1)) {
            await pushGroup(g);
          }
        }
      }
      if (_projectRepo != null) {
        for (final p in await _projectRepo!.getAllRaw()) {
          final r = remoteProjects[p.id];
          if (r == null || p.updatedAt > (r['updated_at'] as int? ?? -1)) {
            await pushProject(p);
          }
        }
      }
      print('[ProjectSync] 全量对账完成 groups=${groupRows.length} projects=${projRows.length}');
    } catch (e, st) {
      print('[ProjectSync] ❌ 全量对账失败: $e\n$st');
    }
  }

  Future<void> pushProject(Project p) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      print('[ProjectSync] ⚠ pushProject ${p.id} 跳过（未登录 Supabase）');
      return;
    }
    try {
      await _client.from('projects').upsert({
        'id': p.id,
        'user_id': userId,
        'name': p.name,
        'color': p.color,
        'group_id': p.groupId,
        'sort_order': p.sortOrder,
        'archived': p.archived,
        'deleted': p.deleted,
        'created_at': p.createdAt,
        'updated_at': p.updatedAt,
      });
      print('[ProjectSync] ✓ pushProject ${p.id} ${p.name}');
    } catch (e) {
      print('[ProjectSync] ❌ push project 失败 ${p.id}: $e');
    }
  }

  Future<void> removeProject(String id) async {
    try {
      await _client.from('projects').delete().eq('id', id);
      print('[ProjectSync] ✓ removeProject $id');
    } catch (e) {
      print('[ProjectSync] ❌ 删除 project 失败 $id: $e');
    }
  }

  Future<void> pushGroup(ProjectGroup g) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      print('[ProjectSync] ⚠ pushGroup ${g.id} 跳过（未登录 Supabase）');
      return;
    }
    try {
      await _client.from('project_groups').upsert({
        'id': g.id,
        'user_id': userId,
        'name': g.name,
        'color': g.color,
        'sort_order': g.sortOrder,
        'deleted': g.deleted,
        'created_at': g.createdAt,
        'updated_at': g.updatedAt,
      });
      print('[ProjectSync] ✓ pushGroup ${g.id} ${g.name}');
    } catch (e) {
      print('[ProjectSync] ❌ push group 失败 ${g.id}: $e');
    }
  }

  Future<void> removeGroup(String id) async {
    try {
      await _client.from('project_groups').delete().eq('id', id);
      print('[ProjectSync] ✓ removeGroup $id');
    } catch (e) {
      print('[ProjectSync] ❌ 删除 group 失败 $id: $e');
    }
  }

  void subscribe() {
    // 用当前 user JWT 认证 Realtime（不然 RLS 表的事件可能拿不到）
    final token = _client.auth.currentSession?.accessToken;
    if (token != null) {
      _client.realtime.setAuth(token);
    }
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
            print('[ProjectSync] 收到 DELETE projects oldRecord=${p.oldRecord}');
            final id = p.oldRecord['id'] as String?;
            if (id == null || _db == null) return;
            try {
              // 墓碑保护：检查本地项目是否存活
              final localProject = await (_db!.select(_db!.projects)
                    ..where((t) => t.id.equals(id)))
                  .getSingleOrNull();
              if (localProject != null && localProject.deleted == 0) {
                // 本地项目存活，拒绝物理删除，反推存活版本上云
                print('[ProjectSync] 远端删除被拒绝: 本地活项目 ${id.substring(0, 8)} 反推');
                await pushProject(localProject);
                _emitChange();
                return;
              }
              await (_db!.delete(_db!.projects)
                    ..where((t) => t.id.equals(id)))
                  .go();
              _emitChange();
              print('[ProjectSync] ✓ 本地删 project $id');
            } catch (e) {
              print('[ProjectSync] ❌ 本地删 project 失败 $id: $e');
            }
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
            print('[ProjectSync] 收到 DELETE project_groups oldRecord=${p.oldRecord}');
            final id = p.oldRecord['id'] as String?;
            if (id == null || _db == null) return;
            try {
              await _db!.transaction(() async {
                await (_db!.update(_db!.projects)
                      ..where((t) => t.groupId.equals(id)))
                    .write(const ProjectsCompanion(groupId: Value(null)));
                await (_db!.delete(_db!.projectGroups)
                      ..where((t) => t.id.equals(id)))
                    .go();
              });
              _emitChange();
              print('[ProjectSync] ✓ 本地删 group $id');
            } catch (e) {
              print('[ProjectSync] ❌ 本地删 group 失败 $id: $e');
            }
          },
        );
    _channel!.subscribe((status, [error]) {
      print('[ProjectSync] channel status=$status ${error ?? ''}');
    });
  }

  void unsubscribe() => _channel?.unsubscribe();

  Future<void> _upsertProjectFromRow(Map<String, dynamic> row) async {
    if (_db == null) return;
    final id = row['id'] as String?;
    if (id == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remoteDeleted = row['deleted'] as int? ?? 0;
    final remoteUpdated = row['updated_at'] as int? ?? now;

    // 墓碑保护：检查本地项目是否存活
    final localProject = await (_db!.select(_db!.projects)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (localProject != null && localProject.deleted == 0 && remoteDeleted == 1) {
      // 本地项目存活，拒绝远端墓碑，反推存活版本上云
      print('[ProjectSync] 墓碑保护: 本地活项目 ${id.substring(0, 8)} 拒绝被远端墓碑覆盖, localUpdated=${localProject.updatedAt}, remoteUpdated=$remoteUpdated');
      if (localProject.updatedAt >= remoteUpdated) {
        await pushProject(localProject);
      }
      return; // 不更新本地，不级联删任务
    }

    final companion = ProjectsCompanion(
      id: Value(id),
      name: Value(row['name'] as String? ?? ''),
      color: Value(row['color'] as String? ?? '#4772FA'),
      groupId: row['group_id'] != null
          ? Value(row['group_id'] as String)
          : const Value(null),
      sortOrder: Value(row['sort_order'] as int? ?? 0),
      archived: Value(row['archived'] as int? ?? 0),
      deleted: Value(remoteDeleted),
      createdAt: Value(row['created_at'] as int? ?? now),
      updatedAt: Value(remoteUpdated),
    );
    await _db!.into(_db!.projects).insertOnConflictUpdate(companion);
    // 远端项目墓石 → 级联软删本地该项目下 tasks/checklist
    // 仅当本地项目原本就是墓碑或不存在时才执行
    if (remoteDeleted == 1 && (localProject == null || localProject.deleted == 1)) {
      print('[ProjectSync] 级联软删项目 ${id.substring(0, 8)} 下的任务');
      await _db!.transaction(() async {
        final tasks = await (_db!.select(_db!.tasks)
              ..where((t) => t.projectId.equals(id)))
            .get();
        for (final t in tasks) {
          await (_db!.update(_db!.checklistItems)
                ..where((c) => c.taskId.equals(t.id)))
              .write(ChecklistItemsCompanion(
            deleted: const Value(1),
            updatedAt: Value(now),
          ));
        }
        await (_db!.update(_db!.tasks)..where((t) => t.projectId.equals(id)))
            .write(TasksCompanion(deleted: const Value(1), updatedAt: Value(now)));
      });
    }
    _emitChange();
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
      deleted: Value(row['deleted'] as int? ?? 0),
      createdAt: Value(row['created_at'] as int? ?? now),
      updatedAt: Value(row['updated_at'] as int? ?? now),
    );
    await _db!.into(_db!.projectGroups).insertOnConflictUpdate(companion);
    _emitChange();
  }
}
