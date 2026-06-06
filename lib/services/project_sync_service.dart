import 'dart:async';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import '../data/repositories/project_repository.dart';
import '../../core/utils/file_logger.dart';
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

  /// 纯拉取：从云端拉取所有项目/分组并合并到本地（不推送本地数据）
  Future<void> forcePullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _db == null) {
      flog('[ProjectSync] ⚠ forcePullAll 跳过 userId=$userId db=$_db');
      return;
    }
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
      flog('[ProjectSync] forcePull 完成 groups=${groupRows.length} projects=${projRows.length}');
      // 拉取后触发 UI 刷新
      _emitChange();
    } catch (e, st) {
      flog('[ProjectSync] ❌ forcePull 失败: $e\n$st');
    }
  }

  /// 双向 LWW 全量对账：拉云端（含墓石）合并到本地；本地更新/云端缺失则推送上云
  /// [forcePush] 为 true 时跳过 updatedAt 比较，无条件推送所有本地数据（用于首次同步）
  Future<void> syncAll({bool forcePush = false}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _db == null) {
      flog('[ProjectSync] ⚠ syncAll 跳过 userId=$userId db=$_db');
      return;
    }
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
          if (forcePush || r == null || g.updatedAt > (r['updated_at'] as int? ?? -1)) {
            await pushGroup(g);
          }
        }
      }
      if (_projectRepo != null) {
        for (final p in await _projectRepo!.getAllRaw()) {
          final r = remoteProjects[p.id];
          if (forcePush || r == null || p.updatedAt > (r['updated_at'] as int? ?? -1)) {
            await pushProject(p);
          }
        }
      }
      flog('[ProjectSync] 全量对账完成 groups=${groupRows.length} projects=${projRows.length} forcePush=$forcePush');
    } catch (e, st) {
      flog('[ProjectSync] ❌ 全量对账失败: $e\n$st');
    }
  }

  Future<void> pushProject(Project p) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      flog('[ProjectSync] ⚠ pushProject ${p.id} 跳过（未登录 Supabase）');
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
        'is_template': p.isTemplate,
        'deleted': p.deleted,
        'created_at': p.createdAt,
        'updated_at': p.updatedAt,
      });
      flog('[ProjectSync] ✓ pushProject ${p.id} ${p.name}');
    } catch (e) {
      flog('[ProjectSync] ❌ push project 失败 ${p.id}: $e');
    }
  }

  Future<void> removeProject(String id) async {
    try {
      await _client.from('projects').delete().eq('id', id);
      flog('[ProjectSync] ✓ removeProject $id');
    } catch (e) {
      flog('[ProjectSync] ❌ 删除 project 失败 $id: $e');
    }
  }

  Future<void> pushGroup(ProjectGroup g) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      flog('[ProjectSync] ⚠ pushGroup ${g.id} 跳过（未登录 Supabase）');
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
      flog('[ProjectSync] ✓ pushGroup ${g.id} ${g.name}');
    } catch (e) {
      flog('[ProjectSync] ❌ push group 失败 ${g.id}: $e');
    }
  }

  Future<void> removeGroup(String id) async {
    try {
      await _client.from('project_groups').delete().eq('id', id);
      flog('[ProjectSync] ✓ removeGroup $id');
    } catch (e) {
      flog('[ProjectSync] ❌ 删除 group 失败 $id: $e');
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
            flog('[ProjectSync] 收到 DELETE projects oldRecord=${p.oldRecord}');
            final id = p.oldRecord['id'] as String?;
            if (id == null || _db == null) return;
            try {
              // 墓碑保护：检查本地项目是否存活
              final localProject = await (_db!.select(_db!.projects)
                    ..where((t) => t.id.equals(id)))
                  .getSingleOrNull();
              if (localProject != null && localProject.deleted == 0) {
                // 本地项目存活，拒绝物理删除，反推存活版本上云
                flog('[ProjectSync] 远端删除被拒绝: 本地活项目 ${id.length > 8 ? id.substring(0, 8) : id} 反推');
                await pushProject(localProject);
                _emitChange();
                return;
              }
              await (_db!.delete(_db!.projects)
                    ..where((t) => t.id.equals(id)))
                  .go();
              _emitChange();
              flog('[ProjectSync] ✓ 本地删 project $id');
            } catch (e) {
              flog('[ProjectSync] ❌ 本地删 project 失败 $id: $e');
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
            flog('[ProjectSync] 收到 DELETE project_groups oldRecord=${p.oldRecord}');
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
              flog('[ProjectSync] ✓ 本地删 group $id');
            } catch (e) {
              flog('[ProjectSync] ❌ 本地删 group 失败 $id: $e');
            }
          },
        );
    _channel!.subscribe((status, [error]) {
      flog('[ProjectSync] channel status=$status ${error ?? ''}');
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

    // LWW tombstone: remote deleted vs local alive → latest writer wins
    final localProject = await (_db!.select(_db!.projects)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
    if (localProject != null && localProject.deleted == 0 && remoteDeleted == 1) {
      if (localProject.updatedAt >= remoteUpdated) {
        // Local is newer or equal → reject remote tombstone, push alive version back
        flog('[ProjectSync] tombstone-reject: local alive ${id.length > 8 ? id.substring(0, 8) : id} (local=$localProject.updatedAt >= remote=$remoteUpdated)');
        await pushProject(localProject);
        return;
      }
      // Remote is newer → accept tombstone (intentional delete from another device)
      flog('[ProjectSync] tombstone-accept: local alive ${id.length > 8 ? id.substring(0, 8) : id} overridden by remote (remote=$remoteUpdated > local=$localProject.updatedAt)');
      // fall through to insertOnConflictUpdate below → local gets deleted=1 + cascade
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
      isTemplate: Value(row['is_template'] as int? ?? 0),
      deleted: Value(remoteDeleted),
      createdAt: Value(row['created_at'] as int? ?? now),
      updatedAt: Value(remoteUpdated),
    );
    await _db!.into(_db!.projects).insertOnConflictUpdate(companion);
    // 远端项目墓石 → 级联软删本地该项目下 tasks/checklist
    // 仅当本地项目原本就是墓碑或不存在时才执行
    if (remoteDeleted == 1 && (localProject == null || localProject.deleted == 1)) {
      flog('[ProjectSync] 级联软删项目 ${id.length > 8 ? id.substring(0, 8) : id} 下的任务');
      // 使用远端 updated_at 而非 local now，避免 cascaded 墓碑时间戳 > 远端活任务
      final cascadeSeed = remoteUpdated;
      await _db!.transaction(() async {
        final tasks = await (_db!.select(_db!.tasks)
              ..where((t) => t.projectId.equals(id)))
            .get();
        for (final t in tasks) {
          await (_db!.update(_db!.checklistItems)
                ..where((c) => c.taskId.equals(t.id)))
              .write(ChecklistItemsCompanion(
            deleted: const Value(1),
            updatedAt: Value(cascadeSeed),
          ));
        }
        await (_db!.update(_db!.tasks)..where((t) => t.projectId.equals(id)))
            .write(TasksCompanion(deleted: const Value(1), updatedAt: Value(cascadeSeed)));
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
