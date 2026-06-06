import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_assistant/core/constants/app_constants.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/data/repositories/checklist_repository.dart';
import 'package:smart_assistant/data/repositories/node_template_repository.dart';
import 'package:smart_assistant/data/repositories/project_repository.dart';
import 'package:smart_assistant/data/repositories/task_repository.dart';
import 'package:smart_assistant/presentation/blocs/task_new/task_bloc.dart';
import 'package:smart_assistant/presentation/blocs/task_new/task_event.dart';
import 'package:smart_assistant/presentation/blocs/task_new/task_state.dart';
import 'package:smart_assistant/services/subtask_scheduler.dart';
import 'package:smart_assistant/services/task_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
    } catch (_) {}
  });

  test('LoadTasks carries mind map focus request', () {
    final event = LoadTasks(
      projectIds: {'project-1'},
      filter: 'all',
      statusFilter: 'pending',
      clearDateRange: true,
      focusTaskId: 'task-1',
      focusRequestToken: 1001,
    );

    expect(event.projectIds, {'project-1'});
    expect(event.hasProjectSelectionOverride, isTrue);
    expect(event.statusFilter, 'pending');
    expect(event.clearDateRange, isTrue);
    expect(event.focusTaskId, 'task-1');
    expect(event.focusRequestToken, 1001);
  });

  test('LoadTasks distinguishes refresh from clearing project selection', () {
    final refresh = LoadTasks();
    final clearSelection = LoadTasks(projectIds: const {});

    expect(refresh.projectIds, isEmpty);
    expect(refresh.hasProjectSelectionOverride, isFalse);
    expect(clearSelection.projectIds, isEmpty);
    expect(clearSelection.hasProjectSelectionOverride, isTrue);
  });

  test('TaskNewLoaded preserves focus request in equality props', () {
    final state = TaskNewLoaded(
      viewMode: 'mindmap',
      selectedProjectIds: {'project-1'},
      selectedStatusFilter: 'completed',
      focusTaskId: 'task-1',
      focusRequestToken: 1001,
    );

    expect(state.viewMode, 'mindmap');
    expect(state.selectedStatusFilter, 'completed');
    expect(state.focusTaskId, 'task-1');
    expect(state.focusRequestToken, 1001);
    expect(state.props, contains('task-1'));
    expect(state.props, contains('completed'));
    expect(state.props, contains(1001));
  });

  test('subtree refresh preserves existing collapsed expansion state', () {
    final expanded = TaskNewBloc.resolveSubTreeExpandedNodesForRefresh(
      rootTaskId: 'root',
      descendants: [
        _task('child-1', parentId: 'root'),
        _task('child-2', parentId: 'root'),
      ],
      currentExpanded: const {},
    );

    expect(expanded, isEmpty);
  });

  test('subtree refresh removes expansion ids for deleted descendants', () {
    final expanded = TaskNewBloc.resolveSubTreeExpandedNodesForRefresh(
      rootTaskId: 'root',
      descendants: [
        _task('child-1', parentId: 'root'),
        _task('grandchild-1', parentId: 'child-1'),
      ],
      currentExpanded: const {'child-1', 'deleted-child'},
    );

    expect(expanded, {'child-1'});
  });

  test('subtree refresh expands direct children on first load', () {
    final expanded = TaskNewBloc.resolveSubTreeExpandedNodesForRefresh(
      rootTaskId: 'root',
      descendants: [
        _task('child-1', parentId: 'root'),
        _task('grandchild-1', parentId: 'child-1'),
      ],
      currentExpanded: null,
    );

    expect(expanded, {'child-1'});
  });

  test(
    'bare LoadTasks preserves selected project filter in bloc state',
    () async {
      final harness = await _BlocHarness.create();
      addTearDown(harness.dispose);

      final project = await harness.projectRepository.create(name: 'Project A');
      await harness.taskRepository.create(
        projectId: project.id,
        title: 'Visible',
        syncImmediately: false,
      );

      harness.bloc.add(LoadTasks(projectIds: {project.id}, filter: 'all'));
      final selected = await harness.nextLoaded();
      expect(selected.selectedProjectIds, {project.id});

      harness.bloc.add(LoadTasks());
      final refreshed = await harness.nextLoaded();
      expect(refreshed.selectedProjectIds, {project.id});
    },
  );

  test(
    'LoadTasks filters by task completion status and preserves it',
    () async {
      final harness = await _BlocHarness.create();
      addTearDown(harness.dispose);

      final project = await harness.projectRepository.create(name: 'Project A');
      final pending = await harness.taskRepository.create(
        projectId: project.id,
        title: 'Pending',
        syncImmediately: false,
      );
      final completed = await harness.taskRepository.create(
        projectId: project.id,
        title: 'Completed',
        syncImmediately: false,
      );
      await harness.taskRepository.setStatusCascade(
        completed.id,
        2,
        syncImmediately: false,
      );

      harness.bloc.add(LoadTasks(projectIds: {project.id}));
      final all = await harness.nextLoaded();
      expect(all.selectedStatusFilter, 'all');
      expect(
        all.tasks.map((t) => t.id),
        containsAll({pending.id, completed.id}),
      );

      harness.bloc.add(LoadTasks(statusFilter: 'pending'));
      final pendingOnly = await harness.nextLoaded();
      expect(pendingOnly.selectedStatusFilter, 'pending');
      expect(pendingOnly.tasks.map((t) => t.id), [pending.id]);

      harness.bloc.add(LoadTasks(statusFilter: 'completed'));
      final completedOnly = await harness.nextLoaded();
      expect(completedOnly.selectedStatusFilter, 'completed');
      expect(completedOnly.tasks.map((t) => t.id), [completed.id]);

      harness.bloc.add(LoadTasks());
      final refreshed = await harness.nextLoaded();
      expect(refreshed.selectedStatusFilter, 'completed');
      expect(refreshed.tasks.map((t) => t.id), [completed.id]);
    },
  );

  test('creating a subtask expands ancestors and focuses new node', () async {
    final harness = await _BlocHarness.create();
    addTearDown(harness.dispose);

    final project = await harness.projectRepository.create(name: 'Project A');
    final root = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Root',
      syncImmediately: false,
    );
    final parent = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Parent',
      parentId: root.id,
      syncImmediately: false,
    );

    harness.bloc.add(LoadTasks(projectIds: {project.id}, filter: 'all'));
    await harness.nextLoaded();

    harness.bloc.add(
      CreateTask(projectId: project.id, title: 'Child', parentId: parent.id),
    );
    final created = await harness.nextLoaded(
      where: (state) => state.focusTaskId != null,
    );
    final expanded = created.expandedNodes['main_tree'] ?? {};

    expect(created.focusTaskId, isNotNull);
    expect(created.focusRequestToken, isNotNull);
    expect(expanded, containsAll({root.id, parent.id}));
  });

  test('creating a dated subtask expands parent range to child end', () async {
    final harness = await _BlocHarness.create();
    addTearDown(harness.dispose);

    final project = await harness.projectRepository.create(name: 'Project A');
    final parentStart = DateTime(2026, 6, 1, 9);
    final parentEnd = DateTime(2026, 6, 2, 18);
    final childStart = DateTime(2026, 6, 2, 20);
    final childEnd = DateTime(2026, 6, 3, 10);
    final parent = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Parent',
      startDate: parentStart.millisecondsSinceEpoch,
      dueDate: parentEnd.millisecondsSinceEpoch,
      syncImmediately: false,
    );

    harness.bloc.add(LoadTasks(projectIds: {project.id}, filter: 'all'));
    await harness.nextLoaded();

    harness.bloc.add(
      CreateTask(
        projectId: project.id,
        title: 'Child',
        parentId: parent.id,
        startDate: childStart.millisecondsSinceEpoch,
        dueDate: childEnd.millisecondsSinceEpoch,
      ),
    );
    final created = await harness.nextLoaded(
      where: (state) => state.focusTaskId != null,
    );

    final updatedParent = created.tasks.where((t) => t.id == parent.id).first;
    expect(updatedParent.startDate, parentStart.millisecondsSinceEpoch);
    expect(updatedParent.dueDate, childEnd.millisecondsSinceEpoch);
  });

  test(
    'auto-insert shifted subtask expands parent range to shifted end',
    () async {
      final harness = await _BlocHarness.create();
      addTearDown(harness.dispose);

      final project = await harness.projectRepository.create(name: 'Project A');
      final parentStart = DateTime(2026, 6, 1, 9);
      final parentEnd = DateTime(2026, 6, 2, 18);
      final shiftedStart = DateTime(2026, 6, 3, 9);
      final shiftedEnd = DateTime(2026, 6, 3, 10);
      final parent = await harness.taskRepository.create(
        projectId: project.id,
        title: 'Parent',
        startDate: parentStart.millisecondsSinceEpoch,
        dueDate: parentEnd.millisecondsSinceEpoch,
        syncImmediately: false,
      );
      final existingChild = await harness.taskRepository.create(
        projectId: project.id,
        title: 'Existing child',
        parentId: parent.id,
        startDate: DateTime(2026, 6, 2, 10).millisecondsSinceEpoch,
        dueDate: DateTime(2026, 6, 2, 11).millisecondsSinceEpoch,
        syncImmediately: false,
      );

      harness.bloc.add(LoadTasks(projectIds: {project.id}, filter: 'all'));
      await harness.nextLoaded();

      harness.bloc.add(
        CreateTask(
          projectId: project.id,
          title: 'Inserted child',
          parentId: parent.id,
          startDate: DateTime(2026, 6, 2, 9).millisecondsSinceEpoch,
          dueDate: DateTime(2026, 6, 2, 10).millisecondsSinceEpoch,
          shiftedTasks: [
            ScheduledTaskShift(
              taskId: existingChild.id,
              start: shiftedStart,
              end: shiftedEnd,
            ),
          ],
        ),
      );
      final created = await harness.nextLoaded(
        where: (state) => state.focusTaskId != null,
      );

      final updatedChild = created.tasks
          .where((t) => t.id == existingChild.id)
          .first;
      final updatedParent = created.tasks.where((t) => t.id == parent.id).first;
      expect(updatedChild.startDate, shiftedStart.millisecondsSinceEpoch);
      expect(updatedChild.dueDate, shiftedEnd.millisecondsSinceEpoch);
      expect(updatedParent.dueDate, shiftedEnd.millisecondsSinceEpoch);
    },
  );
  test('completing the last pending child auto-completes parent', () async {
    final harness = await _BlocHarness.create();
    addTearDown(harness.dispose);

    final project = await harness.projectRepository.create(name: 'Project A');
    final parent = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Parent',
      syncImmediately: false,
    );
    final childA = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Child A',
      parentId: parent.id,
      syncImmediately: false,
    );
    final childB = await harness.taskRepository.create(
      projectId: project.id,
      title: 'Child B',
      parentId: parent.id,
      syncImmediately: false,
    );

    await harness.taskRepository.toggleStatus(
      childA.id,
      syncImmediately: false,
    );
    expect((await harness.taskRepository.get(parent.id))!.status, 0);

    await harness.taskRepository.toggleStatus(
      childB.id,
      syncImmediately: false,
    );
    expect((await harness.taskRepository.get(parent.id))!.status, 2);
  });
}

class _BlocHarness {
  final AppDatabase database;
  final ProjectRepository projectRepository;
  final TaskRepository taskRepository;
  final TaskNewBloc bloc;

  _BlocHarness._({
    required this.database,
    required this.projectRepository,
    required this.taskRepository,
    required this.bloc,
  });

  static Future<_BlocHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final database = AppDatabase(NativeDatabase.memory());
    final projectRepository = ProjectRepository(database);
    final taskRepository = TaskRepository(database);
    TaskSyncService.instance.bind(taskRepository);
    final bloc = TaskNewBloc(
      projectRepository: projectRepository,
      taskRepository: taskRepository,
      checklistRepository: ChecklistRepository(database),
      nodeTemplateRepository: NodeTemplateRepository(database),
    );
    return _BlocHarness._(
      database: database,
      projectRepository: projectRepository,
      taskRepository: taskRepository,
      bloc: bloc,
    );
  }

  Future<TaskNewLoaded> nextLoaded({
    bool Function(TaskNewLoaded state)? where,
  }) async {
    final predicate = where ?? (_) => true;
    try {
      return await bloc.stream
          .where((state) => state is TaskNewLoaded)
          .cast<TaskNewLoaded>()
          .where(predicate)
          .first
          .timeout(const Duration(seconds: 2));
    } on TimeoutException {
      final current = bloc.state;
      if (current is TaskNewLoaded && predicate(current)) return current;
      rethrow;
    }
  }

  Future<void> dispose() async {
    await bloc.close();
    await database.close();
  }
}

Task _task(String id, {String? parentId}) {
  return Task(
    id: id,
    projectId: 'project-1',
    parentId: parentId,
    title: id,
    description: '',
    priority: 0,
    status: 0,
    isAllDay: 0,
    sortOrder: 0,
    deleted: 0,
    createdAt: 0,
    updatedAt: 0,
    remindBeforeMinutes: 15,
    reminderEnabled: 1,
  );
}
