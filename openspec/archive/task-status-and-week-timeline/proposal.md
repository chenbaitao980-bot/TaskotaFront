# task-status-and-week-timeline

## Why
The Home overview shows pending/in-progress/completed task counts but the status cards are not interactive and users cannot drill into a task list from the overview. The Calendar week mode is currently a basic `TableCalendar` week view and does not provide a TickTick-like draggable time-range schedule interface or support visible cross-day event ranges.

## Impact
GitNexus impact:
- `_HomeContent`: LOW risk, 2 direct upstream references, 0 affected processes.
- `_CalendarPageState`: LOW risk, 2 direct upstream references, 0 affected processes.
- `TaskBloc`: LOW risk, 2 direct upstream references, 0 affected processes.
- BugFixSpecs: no historical hits under `openspec/bugfixspecs`.

## Business Spec Relationship
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirements:
  - Calendar view
  - AI task breakdown
- Relationship: Same capability / Spec Gap for status-list drilldown and week time-grid interaction.
- Action: add scenarios under existing `smart-butler` capability; no new capability.

## Scope
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/task/task_list_page.dart` (new)
- `lib/presentation/pages/task/task_detail_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/services/local_storage_service.dart` only if needed for update operations already present
- Router changes if a named task-list route is useful

## Acceptance
- [x] Tapping pending/in-progress/completed status cards opens a task list filtered by that status.
- [x] The task list shows matching local tasks and allows tapping into task detail.
- [x] Returning from task detail refreshes the task list and Home counts.
- [x] Week calendar mode shows a time-grid schedule view instead of only the month-style event list.
- [x] Week events render as draggable time blocks based on start/end time.
- [x] Dragging an event to another day/hour updates its start/end range and persists locally.
- [x] Event duration is preserved while dragging.
- [x] Cross-day events are visible across affected days in week view.
- [x] Existing month view continues to show event markers and selected-day event list.
- [x] `flutter test` passes.
- [x] `flutter build windows --release` passes and Windows package is refreshed.
- [x] `gitnexus detect-changes --scope all -r smart-assistant` is run.

## Bug / Feature Record
| item_id | Symptom / Need | First Seen | count | Status |
|---|---|---|---:|---|
| task-status-no-drilldown | Home status counts are non-interactive and do not expose task lists | 2026-05-23 | 1 | open |
| week-calendar-no-drag-range | Week calendar lacks draggable time-range events and cross-day range visibility | 2026-05-23 | 1 | open |
| timeline-edge-resize-missing | Week event edge cannot be dragged to resize start/end time | 2026-05-23 | 1 | open |
| task-status-actions-missing | Task status counts remain 0 and task list/detail lacks complete status/delete interactions | 2026-05-23 | 1 | open |

## Follow-up Scope
- Add draggable top/bottom edge handles on week timeline events to resize start/end time.
- Make Home status counts reflect actionable work even when users created schedules rather than task breakdowns.
- Add explicit task status actions for pending, in-progress, completed, and delete.
- Keep existing drag-to-move behavior.
