import 'package:drift/drift.dart';
import 'connection/connection.dart';

part 'app_database.g.dart';

// --- 表定义 ---

class ProjectGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color =>
      text().customConstraint('NOT NULL DEFAULT \'#4772FA\'')();
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
  TextColumn get color =>
      text().customConstraint('NOT NULL DEFAULT \'#4772FA\'')();
  TextColumn? get groupId => text().nullable()();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get archived => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get isTemplate =>
      integer().customConstraint('NOT NULL DEFAULT 0')();
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
  TextColumn get description =>
      text().customConstraint('NOT NULL DEFAULT \'\'')();
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
  IntColumn get remindBeforeMinutes =>
      integer().customConstraint('NOT NULL DEFAULT 15')();
  IntColumn get reminderEnabled =>
      integer().customConstraint('NOT NULL DEFAULT 1')();
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

class NodeTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get title => text()();
  TextColumn get description =>
      text().customConstraint('NOT NULL DEFAULT \'\'')();
  IntColumn get priority => integer().customConstraint('NOT NULL DEFAULT 1')();
  TextColumn get checklistJson =>
      text().customConstraint('NOT NULL DEFAULT \'[]\'')();
  TextColumn get imagesJson =>
      text().customConstraint('NOT NULL DEFAULT \'[]\'')();
  TextColumn get subtasksJson =>
      text().customConstraint('NOT NULL DEFAULT \'[]\'')();
  IntColumn get deleted => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Projects,
    Tasks,
    ChecklistItems,
    ProjectGroups,
    TaskAttachments,
    NodeTemplates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await into(projects).insert(
          ProjectsCompanion(
            id: Value('inbox'),
            name: Value('未分类'),
            color: Value('#4772FA'),
            createdAt: Value(DateTime.now().millisecondsSinceEpoch),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
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
        if (from < 8) {
          await m.createTable(nodeTemplates);
        }
        if (from < 9) {
          try {
            await m.addColumn(projects, projects.isTemplate);
          } catch (e) {
            if (!e.toString().contains('duplicate column name')) rethrow;
          }
        }
        if (from < 10) {
          await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks (project_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_parent_id ON tasks (parent_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_deleted ON tasks (deleted)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks (status)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks (due_date)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_checklist_items_task_id ON checklist_items (task_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_checklist_items_deleted ON checklist_items (deleted)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_task_attachments_task_id ON task_attachments (task_id)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_projects_deleted ON projects (deleted)');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_projects_group_id ON projects (group_id)');
        }
      },
    );
  }

  /// 清空全部业务数据并重建"未分类"项目
  Future<void> wipeAllData() async {
    await transaction(() async {
      await delete(checklistItems).go();
      await delete(taskAttachments).go();
      await delete(nodeTemplates).go();
      await delete(tasks).go();
      await delete(projects).go();
      await delete(projectGroups).go();
      await into(projects).insert(
        ProjectsCompanion(
          id: const Value('inbox'),
          name: const Value('未分类'),
          color: const Value('#4772FA'),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
    });
  }

  Future<void> checkpointForBackup() async {
    await customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
  }
}

QueryExecutor _openConnection() => openConnection();
