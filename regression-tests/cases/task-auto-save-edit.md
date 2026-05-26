# Regression Cases: task-auto-save-edit

## Test Environment
- App: SmartAssistant (Flutter)
- Test type: static check plus manual edit flow
- Last command: `flutter analyze lib\presentation\pages\tasks\task_detail\task_detail_page.dart lib\presentation\pages\tasks\widgets\task_edit_page.dart lib\presentation\pages\tasks\task_detail\widgets\subtask_tree_section.dart`

## Cases

### TC1: Task detail edits auto-save
1. Open an existing task detail page.
2. Edit task fields that were previously saved by the explicit save action.
3. Leave the page and reopen the same task.
4. Expected: edited values are retained without pressing a save button.
5. Expected: no task edit save button is shown in the detail editing surface.

### TC2: Subtask edits persist on exit
1. Open a task with at least one subtask.
2. Edit the subtask title or supported editable fields.
3. Leave the subtask editing surface.
4. Expected: subtask changes are retained after returning to the parent task detail page.

### TC3: Existing task tree UI remains stable
1. Open a task with subtasks.
2. Expand and collapse the subtask tree.
3. Expected: the subtask tree still renders and responds normally after auto-save changes.

## Pass Criteria
- All manual cases pass.
- The recorded `flutter analyze` command exits with code 0.
