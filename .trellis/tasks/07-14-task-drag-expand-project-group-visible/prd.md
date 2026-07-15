# Fix Task Drag Expansion And Empty Project Group Visibility

## Goal

Fix two task/project UI behaviors so changes are visible immediately: after dragging a task under another task, the receiving parent should be expanded by default; after creating a project group, the empty group should be shown immediately even before a project is created under it.

## Requirements

* When a task is moved under another task, the new parent task is expanded by default so the moved child is visible.
* Creating a project group displays the group immediately, even if it has no projects yet.
* Existing filters, task ordering, and project/group persistence behavior must remain unchanged.

## Acceptance Criteria

* [x] Dragging task A under task B shows task B expanded with A visible beneath it after the move completes.
* [x] Creating a project group shows the group in the project selection/list UI immediately without needing to create a project inside it.
* [x] Existing task load/filter behavior still works.
* [x] Flutter analyzer was run for affected files; it reports only pre-existing info-level findings.

## Definition of Done

* Code changes are scoped to the relevant Bloc/UI paths.
* Lint/type analysis is run for the affected project.
* No unrelated dirty files are modified or reverted.

## Technical Approach

Use the existing Bloc/UI state patterns. Locate the task move handler and expanded-id management, then ensure the new parent is included in expanded state after `MoveTaskToParent`. Locate project group rendering and include empty groups instead of only groups inferred through existing projects.

## Spec Conflicts

* None found.

## Out of Scope

* Redesigning project picker UI.
* Changing sync semantics for task/project mutations.
* Changing task sort order or project filter semantics.

## Technical Notes

* Relevant specs: `.trellis/spec/frontend/index.md`, `.trellis/spec/frontend/state-management.md`, `.trellis/spec/frontend/component-guidelines.md`, `.trellis/spec/frontend/quality-guidelines.md`.
* CodeGraph indicates likely paths include `lib/presentation/pages/tasks/tasks_page.dart` and `lib/presentation/blocs/task_new/*`.
* Prior memory notes identify `TaskNewBloc` as the task mutation orchestration point and `MindMapView` as a drag-related UI path.
