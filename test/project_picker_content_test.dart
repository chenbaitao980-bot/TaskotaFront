import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/data/database/app_database.dart';
import 'package:smart_assistant/presentation/widgets/project_picker_content.dart';

void main() {
  testWidgets('project picker shows grouped projects', (tester) async {
    final draft = <String>{};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => buildProjectPickerContent(
              projects: [
                _project(id: 'project-1', name: 'Alpha', groupId: 'group-1'),
              ],
              groups: [_group(id: 'group-1', name: 'Work')],
              draft: draft,
              setDialogState: setState,
              extraHeader: const Text('全部项目'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();

    expect(draft, {'project-1'});
  });
}

Project _project({
  required String id,
  required String name,
  required String groupId,
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
    createdAt: 1,
    updatedAt: 1,
  );
}

ProjectGroup _group({required String id, required String name}) {
  return ProjectGroup(
    id: id,
    name: name,
    color: '#4772FA',
    sortOrder: 0,
    deleted: 0,
    createdAt: 1,
    updatedAt: 1,
  );
}
