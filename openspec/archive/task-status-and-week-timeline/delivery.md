# Delivery: task-status-and-week-timeline

## Changed
- Added `TaskListPage` for filtered pending/in-progress/completed task lists.
- Made Home overview status counts tappable.
- Home counts refresh after returning from a task status list.
- Calendar week mode now shows a 24-hour, 7-day timeline grid.
- Schedule blocks render according to their start/end time.
- Cross-day schedules render as day-by-day segments in week mode.
- Schedule blocks can be dragged to another day/hour; duration is preserved and the updated range is saved locally.
- Schedule blocks now include top/bottom resize handles to adjust start/end time.
- Resizing validates that the event remains at least 15 minutes long.
- Month calendar behavior remains intact.
- Home pending counts include schedule-derived pending items so created schedules show up as actionable work.
- Pending task list shows schedule-derived items.
- Task detail now exposes explicit actions for 待办, 进行中, 已完成, 编辑, and 删除.
- Filtered task lists now expose quick actions for pending, in-progress, completed, and delete.
- Week timeline opens near the current time and shows a current-time indicator for today.
- Week timeline resize/move drops snap to 15-minute ranges.
- Week timeline schedule blocks use distinct priority colors.
- Windows release zip was refreshed.

## Verification
- `dart format`: passed.
- `flutter test`: passed.
- `flutter analyze`: completed with 6 existing deprecated API info messages.
- `flutter build windows --release`: passed.
- `gitnexus detect-changes --scope all -r smart-assistant`: passed with LOW risk and 0 affected processes.
- Zip artifact: `E:\claude\project2\smart_assistant\smart_assistant_windows_release.zip`
- Follow-up verification after resize/status actions: `flutter test` passed; `flutter build windows --release` passed.
- Follow-up `gitnexus detect-changes`: completed with MEDIUM risk because the working tree still contains previous auth changes; affected execution flow is limited to Home build/action-card flow.

## Notes
- Dragging and edge resizing snap to 15-minute positions inside the target hour cell.
- Cross-day display is segmented visually by day column while preserving the original event range.
