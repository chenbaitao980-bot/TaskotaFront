# Delta: task-status-and-week-timeline

## Relationship To Main Spec
Same capability / Spec Gap.

## Main Spec Hit
- Capability: `smart-butler`
- Requirement: Calendar view
- Requirement: AI task breakdown

## Change Type
MODIFIED: add interaction scenarios to existing capabilities.

## Business Conflict Check
| Dimension | Status |
|---|---|
| Main spec requirement hit | Calendar view; AI task breakdown |
| Relationship | Same capability, missing UI interaction scenario |
| Other active change collision | `fix-schedule-create-feedback` also touches calendar/home but is a prerequisite feedback fix; this change builds on it |
| Conflict status | No blocking conflict found |
| ADDED allowed | No; existing capabilities are extended |
| Archive completeness | Pending implementation and verification |

## Original Rule
- Users can view calendar schedules in week/month views and create/edit/delete schedules.
- Users can create and view task breakdown data.

## New Rule
### Scenario: Drill into task status list
- WHEN the user taps the Home overview status for pending, in-progress, or completed
- THEN the app SHALL show a task list filtered by that status
- AND tapping a task SHALL open its detail page
- AND returning from detail SHALL refresh the list and Home counts.

### Scenario: Drag schedule in week timeline
- WHEN the user switches Calendar to week mode
- THEN the app SHALL show a time-grid week timeline with schedule blocks positioned by start/end time
- AND the user SHALL be able to drag a schedule block to another time/day
- AND the app SHALL preserve event duration and persist the updated start/end range.

### Scenario: Resize schedule in week timeline
- WHEN the user drags the top or bottom edge of a schedule block in week mode
- THEN the app SHALL update the corresponding start or end time
- AND the drop position SHALL snap to a 15-minute time range
- AND the app SHALL reject invalid ranges where the event duration would be zero or negative
- AND the updated range SHALL persist locally.

### Scenario: Priority-colored schedule blocks
- WHEN schedules have different priority values
- THEN week timeline blocks SHALL use distinct colors for urgent, important, normal, and low priority.

### Scenario: Open week timeline at current time
- WHEN the user opens Calendar in week mode for the current week
- THEN the app SHALL automatically scroll the timeline near the current time
- AND the app SHALL show a current-time indicator for today.

### Scenario: Cross-day schedule in week timeline
- WHEN a schedule starts on one day and ends on another
- THEN week mode SHALL render the schedule on each affected day segment.

### Scenario: Task status actions
- WHEN the user uses a filtered task list
- THEN the list SHALL provide quick actions for pending, in-progress, completed, and delete.
- WHEN the user opens a task detail page
- THEN the app SHALL provide explicit actions for 待办, 进行中, 已完成, and 删除
- AND changing status SHALL update the Home overview counts and filtered task lists.

### Scenario: Schedule-derived pending work
- WHEN the user has created schedules but no task breakdown records
- THEN the Home pending overview SHALL still reflect actionable scheduled items
- AND tapping pending SHALL show those scheduled items.

## Change Details
- `home_page.dart`: status cards become interactive and route to filtered task lists.
- `task_list_page.dart`: new filtered task list screen.
- `calendar_page.dart`: week mode gains time-grid drag/drop event blocks.
- `task_detail_page.dart`: explicit task status and delete actions.
