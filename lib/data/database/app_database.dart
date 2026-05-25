import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// --- 表定义 ---

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text().customConstraint('NOT NULL DEFAULT \'#4772FA\'')();
  IntColumn get sortOrder => integer().customConstraint('NOT NULL DEFAULT 0')();
  IntColumn get archived => integer().customConstraint('NOT NULL DEFAULT 0')();
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
  IntColumn get createdAt => integer()();
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
  IntColumn? get completedTime => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// --- 数据库 ---

@DriftDatabase(tables: [Projects, Tasks, ChecklistItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

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
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'smart_assistant.db'));
    return NativeDatabase(file);
  });
}
