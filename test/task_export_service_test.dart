import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/services/task_export_service.dart';

void main() {
  final service = TaskExportService();

  test('filters tasks by overlapping date range, projects, and priorities', () {
    final tasks = [
      _task(
        id: 'root',
        projectId: 'p1',
        title: '根任务',
        priority: 5,
        startDate: DateTime(2026, 1, 5).millisecondsSinceEpoch,
        dueDate: DateTime(2026, 1, 6).millisecondsSinceEpoch,
      ),
      _task(
        id: 'child',
        projectId: 'p1',
        parentId: 'root',
        title: '子任务',
        priority: 3,
        startDate: DateTime(2026, 1, 6).millisecondsSinceEpoch,
      ),
      _task(
        id: 'other',
        projectId: 'p2',
        title: '其他项目',
        priority: 5,
        startDate: DateTime(2026, 1, 6).millisecondsSinceEpoch,
      ),
      _task(
        id: 'low',
        projectId: 'p1',
        title: '低优先级',
        priority: 1,
        startDate: DateTime(2026, 1, 6).millisecondsSinceEpoch,
      ),
    ];

    final result = service.filterTasks(
      tasks: tasks,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10, 23, 59, 59),
      projectIds: {'p1'},
      priorities: {5, 3},
    );

    expect(result.map((task) => task.id), ['root', 'child']);
  });

  test('builds parent-first tree rows', () {
    final rows = service.buildTreeRows([
      _task(id: 'child', projectId: 'p1', parentId: 'root', title: '子任务'),
      _task(id: 'root', projectId: 'p1', title: '根任务'),
      _task(id: 'grand', projectId: 'p1', parentId: 'child', title: '孙任务'),
    ]);

    expect(rows.map((row) => row.task.id), ['root', 'child', 'grand']);
    expect(rows.map((row) => row.depth), [0, 1, 2]);
  });

  test('exports one sheet per project', () {
    final bytes = service.exportTasksToExcel(
      tasks: [
        _task(id: 'a', projectId: 'p1', title: '任务 A'),
        _task(id: 'b', projectId: 'p2', title: '任务 B'),
      ],
      projects: [
        _project(id: 'p1', name: '项目一'),
        _project(id: 'p2', name: '项目二'),
      ],
      projectIds: {'p1', 'p2'},
      priorities: {0, 1, 3, 5},
    );

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.keys, containsAll(['项目一', '项目二']));

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheet = archive.files.firstWhere(
      (file) => file.name == 'xl/worksheets/sheet1.xml',
    );
    final xml = XmlDocument.parse(utf8.decode(sheet.content as List<int>));
    final pane = xml.findAllElements('pane').first;
    expect(pane.getAttribute('state'), 'frozen');
    expect(pane.getAttribute('topLeftCell'), 'A5');
  });

  test('exports unmatched project tasks when project filter is empty', () {
    final bytes = service.exportTasksToExcel(
      tasks: [_task(id: 'orphan', projectId: 'missing', title: 'Orphan')],
      projects: [_project(id: 'p1', name: 'Project 1')],
      projectIds: const {},
      priorities: {0, 1, 3, 5},
    );

    final workbook = Excel.decodeBytes(bytes);
    expect(workbook.tables.length, 1);
    final values = workbook.tables.values.single.rows
        .expand((row) => row)
        .map((cell) => cell?.value.toString())
        .whereType<String>();
    expect(values, contains('Orphan'));
  });
}

Project _project({required String id, required String name}) {
  return Project(
    id: id,
    name: name,
    color: '#4772FA',
    sortOrder: 0,
    archived: 0,
    isTemplate: 0,
    deleted: 0,
    createdAt: 0,
    updatedAt: 0,
  );
}

Task _task({
  required String id,
  required String projectId,
  String? parentId,
  required String title,
  int priority = 5,
  int status = 0,
  int? startDate,
  int? dueDate,
}) {
  return Task(
    id: id,
    projectId: projectId,
    parentId: parentId,
    title: title,
    description: '',
    priority: priority,
    status: status,
    startDate: startDate,
    dueDate: dueDate,
    isAllDay: 0,
    sortOrder: 0,
    deleted: 0,
    createdAt: 0,
    updatedAt: 0,
    remindBeforeMinutes: 15,
    reminderEnabled: 1,
  );
}
