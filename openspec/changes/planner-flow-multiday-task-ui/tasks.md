# Tasks: planner-flow-multiday-task-ui

## Implementation
- [x] 1. Fix onboarding goal validation and optional profile skip/back behavior.
- [x] 2. Update schedule dialog to support explicit start/end dates and unambiguous time labels.
- [x] 3. Improve AI suggestion lifecycle so chips match only the current question or explicit options.
- [x] 4. Add structured final-plan rendering as table plus flowchart-style hierarchy.
- [x] 5. Implement unlimited subtask add/display flow using parent references.
- [x] 6. Support multi-day task ranges in storage/UI without breaking existing one-day schedules.
- [x] 7. Render multi-day calendar items as top spanning bars and keep timed events in the hourly grid.
- [x] 8. Maintain regression case file and run verification gates.
- [x] 9. Run `gitnexus detect-changes --scope all -r smart-assistant` and update delivery notes.
- [x] 10. Fix regression: schedule edit exposes add-subtask, onboarding close is one tap on every step, and AI plan renderer removes markdown pipes.
- [x] 11. Fix regression: subtasks can open from calendar and continue nesting.
- [x] 12. Add exact start/end time selection for tasks and subtasks.
- [x] 13. Add AI plan right-click/action-menu assignment with editable dated-time preview.
- [x] 14. Fix regression: single-day tasks and assigned tasks appear in the calendar hourly grid.
- [x] 15. Fix regression: AI question text strips markdown bold markers and still shows current suggestions.
- [x] 16. Move plan assignment action to the mind-map lower-right action area.
- [x] 17. Fix regression: final AI plans always render table plus mind-map and never fall back to plain text only.
- [x] 18. Fix regression: AI suggestion chips are generated only from explicit/current question options, with no stale fallback chips after long answers.
- [x] 19. Restore calendar vertical drag/resize for timed items to adjust start/end times.
- [x] 20. Add calendar horizontal drag/drop so moving an item to another day updates its date while preserving duration.
- [x] 21. Prevent deleting a task that still has child tasks.
- [x] 22. Ensure newly created tasks and subtasks default to same-day start/end ranges.

## User Verification
- [ ] Fill three onboarding goals and confirm the next action enables immediately.
- [ ] Skip occupation/profile collection and confirm one back action returns to Home without immediate re-prompt.
- [ ] Create/edit a schedule and confirm 12-hour time includes 上午/下午 or the UI uses clear 24-hour time.
- [ ] Trigger AI plan generation and confirm option chips answer the current question.
- [ ] Confirm final AI plan appears as table and flowchart, not only a text block.
- [ ] Confirm final AI plan table has no raw `|` characters and the hierarchy appears as a mind-map.
- [ ] Edit an existing schedule and confirm Add Subtask opens task creation with the schedule date range.
- [ ] Add subtasks under a subtask more than one level deep.
- [ ] Tap a calendar task/subtask bar and confirm task detail opens.
- [ ] Create/edit a subtask and confirm exact start/end time is retained.
- [ ] Right-click an AI final plan card, choose one-click assignment, adjust preview details, and confirm tasks are created.
- [ ] Add a subtask or assign an AI plan task for today and confirm it appears in the calendar hourly grid.
- [ ] Confirm AI question bubbles do not show raw `**` and current suggestion chips appear.
- [ ] Confirm 一键分配任务 appears at the lower-right of the mind-map area.
- [ ] Create a task spanning May 24-30, 2026 and confirm it appears as a horizontal bar across the week calendar.
- [ ] Confirm an AI final answer that contains a plan shows table and mind-map actions again.
- [ ] Confirm AI option chips disappear for final/long plan answers and never answer an earlier question.
- [ ] Drag a calendar item vertically and confirm the time range changes.
- [ ] Drag a calendar item from Monday to Tuesday and confirm it becomes Tuesday with the same duration.
- [ ] Try deleting a task with subtasks and confirm deletion is blocked with a visible message.
- [ ] Create a new task and a new subtask and confirm end date defaults to the same day as start date.
