# Regression Cases: task-progress-calculation

## Test Environment
- App: SmartAssistant (Flutter)
- Test type: unit test plus focused manual UI checks
- Last command: `flutter test test\task_progress_calculator_test.dart`

## Unit Cases
- Leaf task progress follows checklist completion.
- Completed leaf task returns 100 even when checklist items are incomplete.
- Leaf task without checklist follows task completion status.
- Parent task progress recursively includes self and descendant work units.
- Project progress counts each task work unit once.
- Project progress does not overweight checklist item count.
- Completed parent task overrides descendant progress for project total.

## Manual UI Cases

### TC1: Task card progress renders from calculated progress
1. Create or open a task with checklist items.
2. Complete some, but not all, checklist items.
3. Expected: the task card progress bar and percent match checklist completion.

### TC2: Parent task progress includes descendants
1. Create a parent task with at least two child tasks.
2. Complete one child task and leave the other incomplete.
3. Expected: the parent task progress changes according to recursive descendant progress.

### TC3: Completed section preserves task hierarchy
1. Complete a parent task and at least one child task.
2. Open the completed task section.
3. Expected: completed tasks render in parent-child hierarchy instead of a flat list.

### TC4: Project progress counts tasks equally
1. Create a project with tasks where one task has multiple checklist items.
2. Complete a subset of tasks and checklist items.
3. Expected: project progress is based on task work units, not a global checklist-item denominator.

## Pass Criteria
- The recorded Flutter unit test exits with code 0.
- Manual UI checks confirm task, completed tree, and project progress stay consistent.
