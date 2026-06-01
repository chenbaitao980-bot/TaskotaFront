import 'dart:typed_data';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../data/database/app_database.dart';

class TaskExportRow {
  final Task task;
  final int depth;

  const TaskExportRow({required this.task, required this.depth});
}

class TaskExportService {
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  Uint8List exportTasksToExcel({
    required List<Task> tasks,
    required List<Project> projects,
    DateTime? startDate,
    DateTime? endDate,
    Set<String> projectIds = const {},
    Set<int> priorities = const {},
  }) {
    final filtered = filterTasks(
      tasks: tasks,
      startDate: startDate,
      endDate: endDate,
      projectIds: projectIds,
      priorities: priorities,
    );
    final excel = Excel.createExcel();
    final projectMap = {for (final p in projects) p.id: p};
    final selectedProjectIds = projectIds.isEmpty
        ? projects.map((p) => p.id).toSet()
        : projectIds;
    final projectsToExport =
        projects.where((p) => selectedProjectIds.contains(p.id)).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final usedSheetNames = <String>{};
    var hasSheet = false;
    for (final project in projectsToExport) {
      final projectTasks = filtered
          .where((task) => task.projectId == project.id)
          .toList();
      if (projectTasks.isEmpty) continue;
      final rows = buildTreeRows(projectTasks);
      final sheetName = _uniqueSheetName(project.name, usedSheetNames);
      final sheet = excel[sheetName];
      _writeProjectSheet(
        sheet: sheet,
        project: project,
        rows: rows,
        startDate: startDate,
        endDate: endDate,
        priorities: priorities,
      );
      hasSheet = true;
    }

    final orphanTasks = filtered
        .where((task) => !projectMap.containsKey(task.projectId))
        .toList();
    if (orphanTasks.isNotEmpty) {
      final sheetName = _uniqueSheetName('未匹配项目', usedSheetNames);
      _writeProjectSheet(
        sheet: excel[sheetName],
        project: null,
        rows: buildTreeRows(orphanTasks),
        startDate: startDate,
        endDate: endDate,
        priorities: priorities,
      );
      hasSheet = true;
    }

    if (!hasSheet) {
      final sheet = excel['无数据'];
      _writeEmptySheet(sheet, startDate, endDate, priorities);
      usedSheetNames.add('无数据');
    }

    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null &&
        defaultSheet == 'Sheet1' &&
        !usedSheetNames.contains(defaultSheet) &&
        excel.tables.length > 1) {
      excel.delete(defaultSheet);
    }

    return _freezeTopRows(Uint8List.fromList(excel.encode() ?? <int>[]));
  }

  List<Task> filterTasks({
    required List<Task> tasks,
    DateTime? startDate,
    DateTime? endDate,
    Set<String> projectIds = const {},
    Set<int> priorities = const {},
  }) {
    final startMs = startDate?.millisecondsSinceEpoch;
    final endMs = endDate?.millisecondsSinceEpoch;
    return tasks.where((task) {
      if (task.deleted != 0) return false;
      if (projectIds.isNotEmpty && !projectIds.contains(task.projectId)) {
        return false;
      }
      if (priorities.isNotEmpty && !priorities.contains(task.priority)) {
        return false;
      }
      if (startMs != null && endMs != null) {
        final taskStart = task.startDate ?? task.dueDate;
        final taskEnd = task.dueDate ?? task.startDate;
        if (taskStart == null || taskEnd == null) return false;
        return taskStart <= endMs && taskEnd >= startMs;
      }
      return true;
    }).toList();
  }

  List<TaskExportRow> buildTreeRows(List<Task> tasks) {
    final result = <TaskExportRow>[];
    final taskIds = tasks.map((task) => task.id).toSet();
    final childrenByParent = <String?, List<Task>>{};
    for (final task in tasks) {
      final parentId = task.parentId;
      final key = parentId != null && taskIds.contains(parentId)
          ? parentId
          : null;
      childrenByParent.putIfAbsent(key, () => []).add(task);
    }
    for (final children in childrenByParent.values) {
      children.sort(_compareTaskOrder);
    }
    final visited = <String>{};
    void walk(Task task, int depth) {
      if (!visited.add(task.id)) return;
      result.add(TaskExportRow(task: task, depth: depth));
      for (final child in childrenByParent[task.id] ?? const <Task>[]) {
        walk(child, depth + 1);
      }
    }

    for (final root in childrenByParent[null] ?? const <Task>[]) {
      walk(root, 0);
    }
    return result;
  }

  void _writeProjectSheet({
    required Sheet sheet,
    required Project? project,
    required List<TaskExportRow> rows,
    required DateTime? startDate,
    required DateTime? endDate,
    required Set<int> priorities,
  }) {
    final title = project == null ? '未匹配项目任务导出' : '${project.name}任务导出';
    final summary =
        '时间：${_dateRangeLabel(startDate, endDate)}    重要级别：${_priorityFilterLabel(priorities)}    任务数：${rows.length}';
    _setupColumns(sheet);
    _mergeWrite(sheet, 0, 0, 7, title, _titleStyle());
    _writeCell(sheet, 1, 0, summary, _summaryStyle());
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 1),
    );

    final headers = ['层级', '任务标题', '重要级别', '状态', '开始时间', '截止时间', '完成时间', '描述'];
    for (var col = 0; col < headers.length; col++) {
      _writeCell(sheet, 3, col, headers[col], _headerStyle());
    }

    var rowIndex = 4;
    for (final row in rows) {
      final task = row.task;
      final rowStyle = rowIndex.isEven ? _bodyAltStyle() : _bodyStyle();
      final indent = List.filled(row.depth, '  ').join();
      _writeCell(
        sheet,
        rowIndex,
        0,
        row.depth == 0 ? '根任务' : 'L${row.depth + 1}',
        rowStyle,
      );
      _writeCell(sheet, rowIndex, 1, '$indent${task.title}', rowStyle);
      _writeCell(
        sheet,
        rowIndex,
        2,
        _priorityLabel(task.priority),
        _priorityStyle(task.priority),
      );
      _writeCell(sheet, rowIndex, 3, _statusLabel(task.status), rowStyle);
      _writeCell(sheet, rowIndex, 4, _formatMs(task.startDate), rowStyle);
      _writeCell(sheet, rowIndex, 5, _formatMs(task.dueDate), rowStyle);
      _writeCell(sheet, rowIndex, 6, _formatMs(task.completedTime), rowStyle);
      _writeCell(sheet, rowIndex, 7, task.description, rowStyle);
      rowIndex++;
    }
  }

  void _writeEmptySheet(
    Sheet sheet,
    DateTime? startDate,
    DateTime? endDate,
    Set<int> priorities,
  ) {
    _setupColumns(sheet);
    _mergeWrite(sheet, 0, 0, 7, '任务导出', _titleStyle());
    _writeCell(
      sheet,
      2,
      0,
      '没有符合筛选条件的任务。时间：${_dateRangeLabel(startDate, endDate)}；重要级别：${_priorityFilterLabel(priorities)}',
      _summaryStyle(),
    );
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 2),
    );
  }

  void _setupColumns(Sheet sheet) {
    const widths = [10.0, 34.0, 12.0, 12.0, 18.0, 18.0, 18.0, 42.0];
    for (var i = 0; i < widths.length; i++) {
      sheet.setColumnWidth(i, widths[i]);
    }
    sheet.setRowHeight(0, 26);
    sheet.setRowHeight(1, 22);
    sheet.setDefaultRowHeight(20);
  }

  void _mergeWrite(
    Sheet sheet,
    int row,
    int startCol,
    int endCol,
    String value,
    CellStyle style,
  ) {
    final start = CellIndex.indexByColumnRow(
      columnIndex: startCol,
      rowIndex: row,
    );
    final end = CellIndex.indexByColumnRow(columnIndex: endCol, rowIndex: row);
    sheet.merge(start, end, customValue: TextCellValue(value));
    sheet.setMergedCellStyle(start, style);
  }

  void _writeCell(
    Sheet sheet,
    int row,
    int col,
    String value,
    CellStyle style,
  ) {
    sheet.updateCell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      TextCellValue(value),
      cellStyle: style,
    );
  }

  static int _compareTaskOrder(Task a, Task b) {
    final sort = a.sortOrder.compareTo(b.sortOrder);
    if (sort != 0) return sort;
    return a.createdAt.compareTo(b.createdAt);
  }

  static String _uniqueSheetName(String raw, Set<String> used) {
    final sanitized = raw
        .replaceAll(RegExp(r'[\[\]\:\*\?\/\\]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final base = sanitized.isEmpty ? '未命名项目' : sanitized;
    var name = base.length > 31 ? base.substring(0, 31) : base;
    var index = 2;
    while (used.contains(name)) {
      final suffix = ' $index';
      final limit = 31 - suffix.length;
      name = '${base.length > limit ? base.substring(0, limit) : base}$suffix';
      index++;
    }
    used.add(name);
    return name;
  }

  static String _dateRangeLabel(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return '全部时间';
    return '${_dateFormat.format(startDate)} 至 ${_dateFormat.format(endDate)}';
  }

  static String _priorityFilterLabel(Set<int> priorities) {
    if (priorities.isEmpty || priorities.length >= 4) return '全部';
    final values = priorities.toList()..sort((a, b) => b.compareTo(a));
    return values.map(_priorityLabel).join('、');
  }

  static String _priorityLabel(int priority) {
    return switch (priority) {
      5 => '高',
      3 => '中',
      1 => '低',
      _ => '无',
    };
  }

  static String _statusLabel(int status) {
    return status == 2 ? '已完成' : '待完成';
  }

  static String _formatMs(int? value) {
    if (value == null) return '';
    return _dateTimeFormat.format(DateTime.fromMillisecondsSinceEpoch(value));
  }

  static CellStyle _titleStyle() => CellStyle(
    fontColorHex: ExcelColor.white,
    backgroundColorHex: ExcelColor.fromHexString('FFC45F3C'),
    fontFamily: getFontFamily(FontFamily.Arial_Unicode_MS),
    fontSize: 16,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static CellStyle _summaryStyle() => CellStyle(
    fontColorHex: ExcelColor.fromHexString('FF5F5A53'),
    backgroundColorHex: ExcelColor.fromHexString('FFFFF7F0'),
    fontFamily: getFontFamily(FontFamily.Arial_Unicode_MS),
    fontSize: 11,
    verticalAlign: VerticalAlign.Center,
  );

  static CellStyle _headerStyle() => _borderedStyle(
    fontColor: ExcelColor.white,
    background: ExcelColor.fromHexString('FF2F3A44'),
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
  );

  static CellStyle _bodyStyle() => _borderedStyle(
    fontColor: ExcelColor.fromHexString('FF2E2B28'),
    background: ExcelColor.white,
  );

  static CellStyle _bodyAltStyle() => _borderedStyle(
    fontColor: ExcelColor.fromHexString('FF2E2B28'),
    background: ExcelColor.fromHexString('FFFFFBF7'),
  );

  static CellStyle _priorityStyle(int priority) {
    final color = switch (priority) {
      5 => ExcelColor.fromHexString('FFD14343'),
      3 => ExcelColor.fromHexString('FFB85C38'),
      1 => ExcelColor.fromHexString('FF4D7C59'),
      _ => ExcelColor.fromHexString('FF7D7A75'),
    };
    return _borderedStyle(
      fontColor: color,
      background: ExcelColor.fromHexString('FFFFF7F0'),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  static CellStyle _borderedStyle({
    required ExcelColor fontColor,
    required ExcelColor background,
    bool bold = false,
    HorizontalAlign horizontalAlign = HorizontalAlign.Left,
  }) {
    final border = Border(
      borderStyle: BorderStyle.Thin,
      borderColorHex: ExcelColor.fromHexString('FFE5DED7'),
    );
    return CellStyle(
      fontColorHex: fontColor,
      backgroundColorHex: background,
      fontFamily: getFontFamily(FontFamily.Arial_Unicode_MS),
      fontSize: 11,
      bold: bold,
      horizontalAlign: horizontalAlign,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
  }

  Uint8List _freezeTopRows(Uint8List bytes) {
    final source = ZipDecoder().decodeBytes(bytes);
    final output = Archive();
    for (final file in source.files) {
      if (!file.isFile) {
        output.addFile(file);
        continue;
      }
      final content = file.content as List<int>;
      if (RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(file.name)) {
        final xml = utf8.decode(content);
        final nextXml = _withFrozenHeader(xml);
        final nextBytes = utf8.encode(nextXml);
        output.addFile(ArchiveFile(file.name, nextBytes.length, nextBytes));
      } else {
        output.addFile(ArchiveFile(file.name, content.length, content));
      }
    }
    return Uint8List.fromList(ZipEncoder().encode(output) ?? bytes);
  }

  String _withFrozenHeader(String xml) {
    final document = XmlDocument.parse(xml);
    final worksheet = document.rootElement;
    var sheetViews = worksheet.getElement('sheetViews');
    if (sheetViews == null) {
      sheetViews = XmlElement(XmlName('sheetViews'));
      final sheetPrIndex = worksheet.children.indexWhere(
        (node) => node is XmlElement && node.name.local == 'sheetPr',
      );
      worksheet.children.insert(
        sheetPrIndex < 0 ? 0 : sheetPrIndex + 1,
        sheetViews,
      );
    }

    XmlElement? sheetView;
    for (final element in sheetViews.findElements('sheetView')) {
      sheetView = element;
      break;
    }
    if (sheetView == null) {
      sheetView = XmlElement(XmlName('sheetView'), [
        XmlAttribute(XmlName('workbookViewId'), '0'),
      ]);
      sheetViews.children.add(sheetView);
    }

    sheetView.children.removeWhere((node) {
      return node is XmlElement &&
          (node.name.local == 'pane' || node.name.local == 'selection');
    });
    sheetView.children.insert(
      0,
      XmlElement(XmlName('pane'), [
        XmlAttribute(XmlName('ySplit'), '4'),
        XmlAttribute(XmlName('topLeftCell'), 'A5'),
        XmlAttribute(XmlName('activePane'), 'bottomLeft'),
        XmlAttribute(XmlName('state'), 'frozen'),
      ]),
    );
    sheetView.children.add(
      XmlElement(XmlName('selection'), [
        XmlAttribute(XmlName('pane'), 'bottomLeft'),
        XmlAttribute(XmlName('activeCell'), 'A5'),
        XmlAttribute(XmlName('sqref'), 'A5'),
      ]),
    );
    return document.toXmlString();
  }
}
