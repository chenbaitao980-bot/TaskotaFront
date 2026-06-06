import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/presentation/pages/tasks/widgets/project_sidebar.dart';

void main() {
  testWidgets('shows empty groups when there are no projects', (tester) async {
    final group = _group(id: 'group-1', name: 'New Group');

    await tester.pumpWidget(
      _host(projects: const [], groups: [group], expandedGroupIds: {'group-1'}),
    );

    expect(find.text('New Group'), findsOneWidget);
  });

  testWidgets('uses controlled group expansion', (tester) async {
    final group = _group(id: 'group-1', name: 'Group');
    final project = _project(id: 'project-1', name: 'Alpha', groupId: group.id);

    await tester.pumpWidget(
      _host(projects: [project], groups: [group], expandedGroupIds: const {}),
    );

    expect(find.text('Alpha'), findsNothing);

    await tester.pumpWidget(
      _host(
        projects: [project],
        groups: [group],
        expandedGroupIds: {'group-1'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('calls expand, collapse, and sort actions', (tester) async {
    var expanded = false;
    var collapsed = false;
    var sorted = false;

    await tester.pumpWidget(
      _host(
        groups: [_group(id: 'group-1', name: 'Group')],
        onExpandAllGroups: () => expanded = true,
        onCollapseAllGroups: () => collapsed = true,
        onToggleSortDirection: () => sorted = true,
      ),
    );

    await tester.tap(find.byTooltip('全部展开'));
    await tester.tap(find.byTooltip('全部收缩'));
    await tester.tap(find.byTooltip('时间倒序'));

    expect(expanded, isTrue);
    expect(collapsed, isTrue);
    expect(sorted, isTrue);
  });

  testWidgets('sorts groups and projects by createdAt', (tester) async {
    final oldGroup = _group(id: 'old-group', name: 'Old Group', createdAt: 1);
    final newGroup = _group(id: 'new-group', name: 'New Group', createdAt: 2);
    final oldProject = _project(
      id: 'old-project',
      name: 'Old Project',
      groupId: newGroup.id,
      createdAt: 1,
    );
    final newProject = _project(
      id: 'new-project',
      name: 'New Project',
      groupId: newGroup.id,
      createdAt: 2,
    );

    await tester.pumpWidget(
      _host(
        projects: [oldProject, newProject],
        groups: [oldGroup, newGroup],
        expandedGroupIds: {newGroup.id, oldGroup.id},
        sortDescending: true,
      ),
    );

    expect(_top(tester, 'New Group'), lessThan(_top(tester, 'Old Group')));
    expect(_top(tester, 'New Project'), lessThan(_top(tester, 'Old Project')));
  });
}

Widget _host({
  List<Project> projects = const [],
  List<ProjectGroup> groups = const [],
  Set<String> expandedGroupIds = const {},
  bool sortDescending = true,
  void Function(String groupId, bool expanded)? onToggleGroupExpanded,
  VoidCallback? onExpandAllGroups,
  VoidCallback? onCollapseAllGroups,
  VoidCallback? onToggleSortDirection,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProjectSidebar(
        projects: projects,
        groups: groups,
        expandedGroupIds: expandedGroupIds,
        sortDescending: sortDescending,
        onProjectSelected: (_) {},
        onFilterSelected: (_) {},
        onCreateProject: () {},
        onToggleGroupExpanded: onToggleGroupExpanded ?? (_, _) {},
        onExpandAllGroups: onExpandAllGroups ?? () {},
        onCollapseAllGroups: onCollapseAllGroups ?? () {},
        onToggleSortDirection: onToggleSortDirection ?? () {},
      ),
    ),
  );
}

ProjectGroup _group({
  required String id,
  required String name,
  int createdAt = 0,
}) {
  return ProjectGroup(
    id: id,
    name: name,
    color: '#4772FA',
    sortOrder: 0,
    deleted: 0,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Project _project({
  required String id,
  required String name,
  String? groupId,
  int createdAt = 0,
}) {
  return Project(
    id: id,
    name: name,
    color: '#4772FA',
    groupId: groupId,
    sortOrder: 0,
    archived: 0,
    isTemplate: 0,
    deleted: 0,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

double _top(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text)).dy;
}
