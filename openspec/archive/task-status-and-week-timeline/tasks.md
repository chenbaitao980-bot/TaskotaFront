# Tasks: task-status-and-week-timeline

## Implementation
- [x] 1. Add filtered `TaskListPage`.
- [x] 2. Wire Home status cards to task lists.
- [x] 3. Refresh Home counts after returning from task lists.
- [x] 4. Add week timeline grid rendering to Calendar.
- [x] 5. Render event blocks by schedule time range, including cross-day segments.
- [x] 6. Add drag/drop rescheduling that preserves duration and persists changes.
- [x] 7. Keep month view behavior intact.
- [x] 8. Add top/bottom resize handles for week timeline events.
- [x] 9. Persist resized schedule ranges with validation.
- [x] 10. Include schedule-derived pending items in Home status counts.
- [x] 11. Show schedule-derived pending items in the pending task list.
- [x] 12. Add explicit task detail actions for 待办, 进行中, 已完成, 删除.
- [x] 13. Refresh list/Home counts after status/delete actions.
- [x] 14. Auto-scroll week timeline to the current time when opened.
- [x] 15. Show a current-time indicator in the visible current week.
- [x] 16. Add task list quick actions for pending, in-progress, completed, and delete.
- [x] 17. Snap week timeline move/resize drops to 15-minute ranges.
- [x] 18. Color week timeline blocks by priority.

## Verification
- [x] Historical BugFixSpecs check completed or confirmed no hit.
- [x] Regression case maintained.
- [x] `dart format`.
- [x] `flutter test`.
- [x] `flutter build windows --release`.
- [x] Windows zip artifact refreshed.
- [x] `gitnexus detect-changes --scope all -r smart-assistant`.
