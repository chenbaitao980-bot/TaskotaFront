import 'dart:convert';

import '../data/database/app_database.dart';
import '../data/repositories/project_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/assistant/assistant_models.dart';
import 'local_storage_service.dart';

class AssistantToolService {
  final TaskRepository? taskRepository;
  final ProjectRepository? projectRepository;
  final LocalStorageService storage;

  AssistantToolService({
    required this.taskRepository,
    required this.projectRepository,
    required this.storage,
  });

  static const toolSchemas = [
    {
      'type': 'function',
      'function': {
        'name': 'search_tasks',
        'description':
            'Search local tasks by keyword, status, project, or date window. Read-only.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'date_from': {'type': 'string', 'description': 'YYYY-MM-DD'},
            'date_to': {'type': 'string', 'description': 'YYYY-MM-DD'},
            'status': {
              'type': 'string',
              'description': 'pending, in_progress, completed, or any',
            },
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_projects',
        'description':
            'Search local projects and summarize basic project records. Read-only.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'search_schedules',
        'description':
            'Search calendar schedules by keyword or date window. Read-only.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'date_from': {'type': 'string', 'description': 'YYYY-MM-DD'},
            'date_to': {'type': 'string', 'description': 'YYYY-MM-DD'},
          },
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'get_current_date',
        'description': 'Get the current local date and time.',
        'parameters': {'type': 'object', 'properties': {}},
      },
    },
  ];

  Future<AssistantToolExecution> execute({
    required String toolName,
    required Map<String, Object?> arguments,
  }) async {
    return switch (toolName) {
      'search_tasks' => _searchTasks(arguments),
      'search_projects' => _searchProjects(arguments),
      'search_schedules' => _searchSchedules(arguments),
      'get_current_date' => _currentDate(),
      _ => AssistantToolExecution(
        toolName: toolName,
        content: jsonEncode({'error': 'Unknown read-only tool: $toolName'}),
      ),
    };
  }

  Future<AssistantToolExecution> _currentDate() async {
    final now = DateTime.now();
    return AssistantToolExecution(
      toolName: 'get_current_date',
      content: jsonEncode({
        'now': now.toIso8601String(),
        'date': _dateOnly(now),
        'weekday': now.weekday,
      }),
    );
  }

  Future<AssistantToolExecution> _searchTasks(Map<String, Object?> args) async {
    final repo = taskRepository;
    if (repo == null) {
      return const AssistantToolExecution(
        toolName: 'search_tasks',
        content: '{"error":"Task repository is unavailable."}',
      );
    }
    final query = (args['query'] as String? ?? '').trim().toLowerCase();
    final range = _parseRange(args);
    final requestedStatus = (args['status'] as String? ?? '').trim();
    final tasks = await repo.getAll();
    final filtered = tasks
        .where((task) {
          if (query.isNotEmpty &&
              !('${task.title} ${task.description}'.toLowerCase()).contains(
                query,
              )) {
            return false;
          }
          if (!_statusMatches(task.status, requestedStatus)) return false;
          if (range != null && !_taskOverlaps(task, range.$1, range.$2)) {
            return false;
          }
          return true;
        })
        .take(20)
        .toList();
    final projects = await projectRepository?.getAll() ?? <Project>[];
    final projectNames = {for (final p in projects) p.id: p.name};
    final items = filtered.map((task) {
      final start = _millisToText(task.startDate);
      final due = _millisToText(task.dueDate);
      return {
        'id': task.id,
        'title': task.title,
        'description': task.description,
        'project': projectNames[task.projectId] ?? task.projectId,
        'status': _taskStatusLabel(task.status),
        'priority': _priorityLabel(task.priority),
        'start': start,
        'due': due,
      };
    }).toList();
    return AssistantToolExecution(
      toolName: 'search_tasks',
      content: jsonEncode({'count': items.length, 'tasks': items}),
      sources: filtered
          .map(
            (task) => AssistantSource(
              type: 'task',
              id: task.id,
              title: task.title,
              snippet:
                  '${_taskStatusLabel(task.status)} · ${projectNames[task.projectId] ?? '未匹配项目'}',
            ),
          )
          .toList(),
    );
  }

  Future<AssistantToolExecution> _searchProjects(
    Map<String, Object?> args,
  ) async {
    final repo = projectRepository;
    if (repo == null) {
      return const AssistantToolExecution(
        toolName: 'search_projects',
        content: '{"error":"Project repository is unavailable."}',
      );
    }
    final query = (args['query'] as String? ?? '').trim().toLowerCase();
    final projects = await repo.getAll();
    final filtered = projects
        .where((project) {
          return query.isEmpty || project.name.toLowerCase().contains(query);
        })
        .take(20)
        .toList();
    final items = filtered
        .map(
          (project) => {
            'id': project.id,
            'name': project.name,
            'archived': project.archived == 1,
            'isTemplate': project.isTemplate == 1,
            'updatedAt': _millisToText(project.updatedAt),
          },
        )
        .toList();
    return AssistantToolExecution(
      toolName: 'search_projects',
      content: jsonEncode({'count': items.length, 'projects': items}),
      sources: filtered
          .map(
            (project) => AssistantSource(
              type: 'project',
              id: project.id,
              title: project.name,
              snippet: project.archived == 1 ? '已归档项目' : '进行中项目',
            ),
          )
          .toList(),
    );
  }

  Future<AssistantToolExecution> _searchSchedules(
    Map<String, Object?> args,
  ) async {
    final query = (args['query'] as String? ?? '').trim().toLowerCase();
    final range = _parseRange(args);
    final schedules = storage.getSchedules(
      startDate: range?.$1,
      endDate: range?.$2,
    );
    final filtered = schedules
        .where((schedule) {
          if (query.isEmpty) return true;
          return ('${schedule.title} ${schedule.description ?? ''}'
                  .toLowerCase())
              .contains(query);
        })
        .take(20)
        .toList();
    final items = filtered
        .map(
          (schedule) => {
            'id': schedule.id,
            'title': schedule.title,
            'description': schedule.description,
            'start': schedule.startTime.toIso8601String(),
            'end': schedule.endTime.toIso8601String(),
            'status': schedule.status,
            'priority': schedule.priority,
          },
        )
        .toList();
    return AssistantToolExecution(
      toolName: 'search_schedules',
      content: jsonEncode({'count': items.length, 'schedules': items}),
      sources: filtered
          .map(
            (schedule) => AssistantSource(
              type: 'schedule',
              id: schedule.id,
              title: schedule.title,
              snippet:
                  '${_dateTimeText(schedule.startTime)} - ${_dateTimeText(schedule.endTime)}',
            ),
          )
          .toList(),
    );
  }

  (DateTime, DateTime)? _parseRange(Map<String, Object?> args) {
    final fromRaw = args['date_from'] as String?;
    final toRaw = args['date_to'] as String?;
    if ((fromRaw == null || fromRaw.trim().isEmpty) &&
        (toRaw == null || toRaw.trim().isEmpty)) {
      return null;
    }
    final now = DateTime.now();
    final from =
        DateTime.tryParse(fromRaw ?? '') ??
        DateTime(now.year, now.month, now.day);
    final parsedTo = DateTime.tryParse(toRaw ?? '');
    final to = parsedTo == null
        ? from.add(const Duration(days: 1))
        : DateTime(
            parsedTo.year,
            parsedTo.month,
            parsedTo.day,
          ).add(const Duration(days: 1));
    return (from, to);
  }

  bool _taskOverlaps(Task task, DateTime from, DateTime to) {
    final start = task.startDate ?? task.dueDate;
    final end = task.dueDate ?? task.startDate;
    if (start == null || end == null) return false;
    final startDate = DateTime.fromMillisecondsSinceEpoch(start);
    final endDate = DateTime.fromMillisecondsSinceEpoch(end);
    return startDate.isBefore(to) && endDate.isAfter(from);
  }

  bool _statusMatches(int status, String requested) {
    final normalized = requested.toLowerCase();
    if (normalized.isEmpty || normalized == 'any' || normalized == 'all') {
      return true;
    }
    return _taskStatusLabel(status).toLowerCase().contains(normalized);
  }

  String _taskStatusLabel(int status) {
    return switch (status) {
      2 => 'completed',
      1 => 'in_progress',
      _ => 'pending',
    };
  }

  String _priorityLabel(int priority) {
    return switch (priority) {
      5 => 'P0',
      3 => 'P1',
      1 => 'P2',
      _ => 'P3',
    };
  }

  String _millisToText(int? millis) {
    if (millis == null) return '';
    return _dateTimeText(DateTime.fromMillisecondsSinceEpoch(millis));
  }

  String _dateTimeText(DateTime value) {
    return '${_dateOnly(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}
