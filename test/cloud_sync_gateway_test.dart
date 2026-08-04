import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/data/sync/local_only_cloud_sync_gateway.dart';

void main() {
  // 每个 AppDatabase(NativeDatabase.memory()) 相互独立，多实例警告是误报。
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late LocalOnlyCloudSyncGateway gateway;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    gateway = LocalOnlyCloudSyncGateway(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('syncAll/pullAll/subscribe 为 no-op，不抛异常', () async {
    await gateway.syncAll();
    await gateway.syncAll(forcePush: true);
    await gateway.pullAll();
    gateway.subscribe();
    gateway.unsubscribe();
  });

  test('快照 round-trip：7 表数据导出后可导入并回读一致', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final now1h = now + 3600000;

    await db.into(db.projectGroups).insertOnConflictUpdate(
          ProjectGroup.fromJson({
            'id': 'g1',
            'name': '组A',
            'color': '#4772FA',
            'sortOrder': 0,
            'deleted': 0,
            'createdAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );
    await db.into(db.projects).insertOnConflictUpdate(
          Project.fromJson({
            'id': 'p1',
            'name': '项目A',
            'color': '#4772FA',
            'groupId': 'g1',
            'sortOrder': 0,
            'archived': 0,
            'isTemplate': 0,
            'deleted': 0,
            'createdAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );
    await db.into(db.tasks).insertOnConflictUpdate(
          Task.fromJson({
            'id': 't1',
            'projectId': 'p1',
            'parentId': null,
            'title': '任务A',
            'description': '',
            'priority': 1,
            'status': 0,
            'startDate': now,
            'dueDate': now1h,
            'isAllDay': 0,
            'completedTime': null,
            'sortOrder': 0,
            'deleted': 0,
            'createdAt': now,
            'updatedAt': now,
            'remindBeforeMinutes': 15,
            'reminderEnabled': 1,
            'estimatedMinutes': null,
            'archived': 0,
          }).toCompanion(true),
        );
    await db.into(db.checklistItems).insertOnConflictUpdate(
          ChecklistItem.fromJson({
            'id': 'c1',
            'taskId': 't1',
            'title': '清单1',
            'status': 0,
            'sortOrder': 0,
            'obsidianUri': null,
            'completedTime': null,
            'deleted': 0,
            'createdAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );
    await db.into(db.taskAttachments).insertOnConflictUpdate(
          TaskAttachment.fromJson({
            'id': 'a1',
            'taskId': 't1',
            'fileName': 'f.txt',
            'localPath': '/tmp/f.txt',
            'storagePath': 'bucket/f.txt',
            'sizeBytes': 10,
            'mimeType': 'text/plain',
            'addedAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );
    await db.into(db.nodeTemplates).insertOnConflictUpdate(
          NodeTemplate.fromJson({
            'id': 'n1',
            'name': '模板A',
            'title': '标题A',
            'description': '',
            'priority': 1,
            'checklistJson': '[]',
            'imagesJson': '[]',
            'subtasksJson': '[]',
            'deleted': 0,
            'createdAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );
    await db.into(db.lazyLogDrafts).insertOnConflictUpdate(
          LazyLogDraft.fromJson({
            'id': 'd1',
            'batchId': 'b1',
            'sourceInput': '源',
            'status': 'pending_review',
            'errorMessage': null,
            'summary': '',
            'projectId': null,
            'parentTaskId': null,
            'parentTitle': '',
            'title': '草稿A',
            'description': '',
            'priority': 'P2',
            'checklistJson': '[]',
            'startDate': now,
            'dueDate': now1h,
            'sortOrder': 0,
            'needsReview': 1,
            'createdTaskId': null,
            'createdAt': now,
            'updatedAt': now,
          }).toCompanion(true),
        );

    final snapshot = await gateway.exportSnapshot();
    expect(snapshot, contains('taskora-snapshot'));
    expect(snapshot, contains('任务A'));

    // 导入到全新内存库，验证全部回读一致
    final db2 = AppDatabase(NativeDatabase.memory());
    final gateway2 = LocalOnlyCloudSyncGateway(db2);
    await gateway2.importSnapshot(snapshot);

    final tasks = await db2.select(db2.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, '任务A');
    expect(tasks.single.startDate, now);
    expect(tasks.single.projectId, 'p1');

    expect(await db2.select(db2.projects).get(), hasLength(2)); // onCreate 自动种子 inbox + 导入的 p1
    final projects = await db2.select(db2.projects).get();
    expect(projects.map((p) => p.id), contains('p1'));
    expect(projects.firstWhere((p) => p.id == 'p1').name, '项目A');
    expect(await db2.select(db2.checklistItems).get(), hasLength(1));
    expect(await db2.select(db2.projectGroups).get(), hasLength(1));
    expect(await db2.select(db2.taskAttachments).get(), hasLength(1));
    expect(await db2.select(db2.nodeTemplates).get(), hasLength(1));
    expect(await db2.select(db2.lazyLogDrafts).get(), hasLength(1));

    await db2.close();
  });

  test('import 拒绝非 taskora 格式快照', () async {
    expect(
      () => gateway.importSnapshot('{"format":"other"}'),
      throwsArgumentError,
    );
  });
}
