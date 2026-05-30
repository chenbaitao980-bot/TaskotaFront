import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- 表定义 ---

class ProjectGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().customConstraint('NOT NULL DEFAULT \'#4772FA\'')();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get deleted => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().customConstraint('NOT NULL DEFAULT \'#4772FA\'')();
  TextColumn? get groupId => text().nullable()();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get archived => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get deleted => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn? get parentId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().customConstraint('NOT NULL DEFAULT \'\'')();
  IntColumn get priority => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get status => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn? get startDate => integer().nullable()();
  IntColumn? get dueDate => integer().nullable()();
  IntColumn get isAllDay => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn? get completedTime => integer().nullable()();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get deleted => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get remindBeforeMinutes => integer().customConstraint('NOT NULL DEFAULT 15')();
  IntColumn get reminderEnabled => integer().customConstraint('NOT NULL DEFAULT 1')();
  IntColumn? get estimatedMinutes => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get fileName => text()();
  TextColumn? get localPath => text().nullable()();
  TextColumn get storagePath => text()();
  IntColumn? get sizeBytes => integer().nullable()();
  TextColumn? get mimeType => text().nullable()();
  IntColumn get addedAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get title => text()();
  IntColumn get status => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  TextColumn? get obsidianUri => text().nullable()();
  IntColumn? get completedTime => integer().nullable()();
  IntColumn get deleted => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- 数据库 ---

@DriftDatabase(tables: [Projects, Tasks, ChecklistItems, ProjectGroups, TaskAttachments])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await into(projects).insert(ProjectsCompanion(
          id: Value('inbox'),
          name: Value('未分类'),
          color: Value('#4772FA'),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.addColumn(tasks, tasks.parentId);
        }
        if (from < 3) {
          await m.addColumn(checklistItems, checklistItems.obsidianUri);
        }
        if (from < 4) {
          await m.addColumn(tasks, tasks.remindBeforeMinutes);
          await m.addColumn(tasks, tasks.reminderEnabled);
        }
        if (from < 5) {
          await m.createTable(projectGroups);
          await m.addColumn(projects, projects.groupId);
          await m.addColumn(tasks, tasks.estimatedMinutes);
        }
        if (from < 6) {
          await m.createTable(taskAttachments);
        }
        if (from < 7) {
          await m.addColumn(tasks, tasks.deleted);
          await m.addColumn(projects, projects.deleted);
          await m.addColumn(projectGroups, projectGroups.deleted);
          await m.addColumn(checklistItems, checklistItems.deleted);
        }
      },
    );
  }

  /// 清空全部业务数据并重建"未分类"项目
  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(checklistItems).go();
      await delete(taskAttachments).go();
      await delete(tasks).go();
      await delete(projects).go();
      await delete(projectGroups).go();
      await into(projects).insert(ProjectsCompanion(
        id: const Value('inbox'),
        name: const Value('未分类'),
        color: const Value('#4772FA'),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'smart_assistant.db'));
    return NativeDatabase(file);
  });
}
