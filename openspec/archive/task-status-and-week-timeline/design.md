# Design: task-status-and-week-timeline

## Current State
Home computes task counts from `LocalStorageService.getTasks()` and renders them in `_buildTodayOverview()`, but the count items are static. The project already has `CreateTaskPage` and `TaskDetailPage`, and `TaskDetailPage` can update status, but there is no filtered task list entry from Home.

Calendar uses `TableCalendar` for both month and week formats. The week format still behaves like a compact calendar strip plus selected-day list. Events are local `Schedule` objects with `startTime` and `endTime`, so the data model can already represent hour ranges and cross-day ranges.

## Approach
### Task Status Drilldown
- Create `TaskListPage` that accepts a status filter (`pending`, `in_progress`, `completed`) and a display title.
- Read tasks from `LocalStorageService`, filter by status, and show a scan-friendly list.
- Tap a task to open `TaskDetailPage`; refresh the list when returning.
- Make the Home overview status items clickable and navigate to `TaskListPage`.
- Refresh Home counts when returning from the list.

### Week Timeline
- Keep month mode largely unchanged.
- When `CalendarFormat.week` is selected, render a week time-grid below the existing header controls.
- Build seven day columns and hourly rows for a practical day range, initially 00:00-24:00 with compact hour labels.
- Render each schedule as a positioned block using its overlap with each day:
  - `segmentStart = max(schedule.startTime, dayStart)`
  - `segmentEnd = min(schedule.endTime, dayEnd)`
  - top/height from minute offsets
- Use `Draggable` + `DragTarget` on day/hour cells to move an event.
- Preserve duration while dragging: new start is target day + target hour/minute, new end is new start + original duration.
- Persist drag changes with `LocalStorageService.updateSchedule()` and refresh events.
- Show a SnackBar after a successful drag update.

### Edge Resize Follow-up
- Add top and bottom resize handles to each event block.
- Top handle adjusts `startTime`; bottom handle adjusts `endTime`.
- Resize snaps to the target hour cell for the first implementation.
- Enforce minimum duration of 15 minutes.
- Allow resizing across day boundaries by accepting target day/hour from the week grid.

### Current Time Positioning Follow-up
- Add a `ScrollController` for the week timeline vertical scroll.
- When the user opens week mode or jumps to today, scroll the time grid near the current time.
- If the visible week contains today, draw a current-time horizontal indicator on today's column.
- Use a post-frame callback so the scroll happens after the timeline layout is attached.

### Task Status Follow-up
- Home status counts currently read only `TaskBreakdown` records, while users mainly create `Schedule` records. To make the status cards useful immediately, count schedules without a linked task as pending actionable items.
- `TaskListPage` should display both matching tasks and schedule-derived pending items.
- Schedule-derived items can open a simple schedule detail/actions sheet with delete and status conversion options.
- `TaskDetailPage` should expose explicit actions: mark pending, mark in-progress, mark completed, delete.

## Business Rule Handling
- Existing Requirement / Scenario: Calendar view supports viewing schedules and creating/editing/deleting schedules.
- Existing Requirement / Scenario: AI task breakdown creates tasks.
- Handling: add interaction scenarios for status drilldown and week timeline; no new model fields.

## Historical BugFixSpecs
- Hit files: none found under `openspec/bugfixspecs`.
- Historical root cause: none.
- Prevention check: every visible dashboard summary should provide a path to the underlying records.

## Risks
- Drag-and-drop time-grid UI can become large; keep the first version simple and robust.
- Cross-day events need segmentation to avoid a block exceeding one day column.
- Resizing cross-day events must avoid invalid ranges where end <= start.
- Counting schedules as pending is a product compromise until schedule/task unification exists.
- Formatter may touch nearby line wrapping in large UI files.

## Regression Test Plan
- Case file: `regression-tests/cases/task-status-and-week-timeline.md`
- Commands: `flutter test`, `flutter build windows --release`
- Manual/UI cases:
  - tap each status count and verify filtered task list
  - open task detail, change status, return and verify counts/list refresh
  - switch calendar to week, drag an event block, verify persisted new time
  - create cross-day event and verify it renders on both days
  - resize top/bottom edge and verify start/end changes persist
  - create schedules and verify pending count/list reflects them
  - use task detail status actions and delete

## Rollback
Revert `TaskListPage`, Home overview navigation changes, and week timeline changes in `calendar_page.dart`.
