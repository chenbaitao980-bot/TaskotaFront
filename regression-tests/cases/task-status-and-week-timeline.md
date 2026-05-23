# Regression Cases: task-status-and-week-timeline

## Batch Test Endpoint
- command_or_url: `flutter test`; `flutter build windows --release`
- auth: authenticated or local-auth state with local task/schedule data
- env: Flutter Windows development environment

## Cases
| case_id | Target | Input Summary | Expected Key Output | Assertion | Source | Status |
|---|---|---|---|---|---|---|
| status-pending-list | Home pending count | tap pending status | pending task list opens | list contains only pending tasks | user | pending |
| status-progress-list | Home in-progress count | tap in-progress status | in-progress task list opens | list contains only in-progress tasks | user | pending |
| status-completed-list | Home completed count | tap completed status | completed task list opens | list contains only completed tasks | user | pending |
| task-detail-refresh | Task status update | open task detail and change status | list and Home counts refresh after return | updated status reflected | user | pending |
| week-timeline-renders | Calendar week mode | switch to week | time-grid blocks appear | schedule block positioned by time | user | pending |
| week-drag-event | Drag event block | drag to another day/hour | event time range persists | updated time visible after refresh | user | pending |
| week-cross-day-event | Cross-day schedule | event spans midnight | segments appear on both affected days | both day columns show block | user | pending |
| week-resize-start | Resize top edge | drag top edge to another hour | start time changes, end time unchanged | updated range visible | user | pending |
| week-resize-end | Resize bottom edge | drag bottom edge to another hour | end time changes, start time unchanged | updated range visible | user | pending |
| schedule-pending-count | Schedule-derived pending | create schedules without tasks | pending count/list reflects schedule items | Home pending > 0 | user | pending |
| task-status-actions | Explicit task actions | open task detail | can set pending/in-progress/completed and delete | list/count refreshes | user | pending |

## Notes
- Keep first implementation focused on local storage data already used by Home/Calendar.
- Avoid recording personal schedule details beyond minimal test summaries.
