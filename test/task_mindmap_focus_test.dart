import 'package:flutter_test/flutter_test.dart';
import 'package:smart_assistant/presentation/blocs/task_new/task_event.dart';
import 'package:smart_assistant/presentation/blocs/task_new/task_state.dart';

void main() {
  test('LoadTasks carries mind map focus request', () {
    final event = LoadTasks(
      projectIds: {'project-1'},
      filter: 'all',
      clearDateRange: true,
      focusTaskId: 'task-1',
      focusRequestToken: 1001,
    );

    expect(event.projectIds, {'project-1'});
    expect(event.clearDateRange, isTrue);
    expect(event.focusTaskId, 'task-1');
    expect(event.focusRequestToken, 1001);
  });

  test('TaskNewLoaded preserves focus request in equality props', () {
    final state = TaskNewLoaded(
      viewMode: 'mindmap',
      selectedProjectIds: {'project-1'},
      focusTaskId: 'task-1',
      focusRequestToken: 1001,
    );

    expect(state.viewMode, 'mindmap');
    expect(state.focusTaskId, 'task-1');
    expect(state.focusRequestToken, 1001);
    expect(state.props, contains('task-1'));
    expect(state.props, contains(1001));
  });
}
