# Delta: planner-flow-multiday-task-ui

## Relation To Main Spec
MODIFIED `smart-butler` existing requirements.

## Hit Main Spec
- Capability: `smart-butler`
- Requirement: `AI任务拆解`
- Requirement: `日历视图`
- Requirement: `用户注册与登录`

## Change Type
MODIFIED

## Business Conflict Check
| Dimension | Status |
|---|---|
| Main spec req hit | AI task breakdown, calendar view, profile/onboarding |
| Relation | Same Requirement / Behavior Override |
| Other active change collision | `fix-calendar-refresh-and-ai-options`, `claude-ui-and-progressive-ai`, `schedule-status-checkbox-control` |
| Conflict status | No direct conflict; this change extends existing behavior and must preserve completed fixes |
| ADDED allowed | No; use MODIFIED existing smart-butler behavior |
| Archive completeness | Pending implementation |

## Old Rules
- AI task breakdown outputs three levels: goal -> month -> week.
- Calendar week view displays timed blocks in hourly grid.
- New schedule dialog creates one-day time ranges.
- Onboarding gathers profile/goals and then returns to Home.

## New Rules
### Requirement: Onboarding Optional Profile Flow
The app SHALL allow optional profile fields, including occupation, to be skipped without blocking access to Home.

#### Scenario: User skips occupation
- WHEN onboarding/profile collection asks for occupation
- AND the user chooses skip/back/close
- THEN the app SHALL return to Home with one navigation action
- AND SHALL not immediately push the same prompt again in the same session.

#### Scenario: Three goals entered
- WHEN the user enters three non-empty goals
- THEN the next/continue action SHALL become enabled immediately
- AND validation SHALL trim whitespace before deciding emptiness.

### Requirement: Unambiguous Schedule Time Selection
New and edited schedules SHALL display start/end times without ambiguity.

#### Scenario: 12-hour picker is used
- WHEN the UI displays a 12-hour time
- THEN it SHALL show 上午/下午 or AM/PM with the time.

#### Scenario: 24-hour picker is used
- WHEN the UI displays a 24-hour time
- THEN it SHALL show `HH:mm`.

### Requirement: Structured AI Plan Rendering
AI final plans SHALL render as both a table and a flowchart-style hierarchy.

#### Scenario: AI returns a complete plan
- WHEN the AI response contains a final multi-step plan
- THEN the UI SHALL render a table with at least task, time/range, level, and notes/status columns
- AND SHALL render a flowchart-style hierarchy from large goal to subtasks
- AND suggestion chips SHALL be hidden or changed to plan-level actions, not stale answer options.

#### Scenario: AI asks a question
- WHEN the AI response is a question
- THEN suggestion chips SHALL match that specific question
- AND stale suggestions from previous turns SHALL NOT be shown.

### Requirement: Unlimited Subtask Tree
Tasks SHALL support unlimited-depth subtasks.

#### Scenario: Add subtask to any task
- WHEN the user opens a task at any level
- THEN the UI SHALL allow adding another child subtask
- AND the child SHALL retain a parent reference
- AND the app SHALL NOT impose a fixed maximum nesting depth.

#### Scenario: Open subtask from calendar
- WHEN a task or subtask bar is shown in Calendar
- THEN tapping the bar SHALL open the corresponding task detail page
- AND the detail page SHALL allow adding another child subtask.

#### Scenario: Subtask exact time
- WHEN the user creates or edits a task or subtask
- THEN the UI SHALL allow selecting start date/time and end date/time
- AND the stored task SHALL retain the selected exact `DateTime` values.

### Requirement: AI Plan Assignment
AI final plans SHALL be assignable into concrete task records after user review.

#### Scenario: Assign final AI plan
- WHEN the AI renders a final plan card
- THEN right-clicking or opening the card action menu SHALL offer one-click task assignment
- AND the user SHALL see an editable preview of generated task titles and exact date/time ranges before saving.

#### Scenario: Generated task precision
- WHEN AI plan rows are converted to tasks
- THEN each generated task SHALL include a concrete start date/time and end date/time
- AND the user SHALL be able to adjust the generated details before tasks are created.

### Requirement: Multi-day Tasks And Calendar Bars
Tasks and schedules SHALL support ranges spanning multiple days.

#### Scenario: Create multi-day task
- WHEN the user creates a task from May 24, 2026 to May 30, 2026
- THEN the task SHALL store both dates
- AND it SHALL remain visible on each relevant day/week view.

#### Scenario: Render cross-day item in week view
- WHEN an item overlaps multiple days in the displayed week
- THEN Calendar SHALL render it as a horizontal bar above the hourly grid
- AND the bar SHALL span the matching day columns
- AND same-day timed events SHALL remain in the hourly grid.

## Change Details
- File: `lib/presentation/pages/onboarding/onboarding_page.dart`
- Before: optional profile flow can trap user in stacked navigation; goal validation may not refresh.
- After: skip/dismiss and reactive validation.

- File: `lib/presentation/widgets/create_schedule_dialog.dart`
- Before: one date plus start/end `TimeOfDay`.
- After: explicit start date/time and end date/time with unambiguous display.

- File: `lib/presentation/pages/ai_chat/ai_chat_page.dart`
- Before: final plans are text; chips can fall back to broad keyword matching.
- After: final plans render as table + flowchart; chips derive from current question or explicit options.

- File: `lib/models/entities/task_breakdown.dart`
- Before: parent fields exist but unlimited child task workflow is not exposed.
- After: parent-child tree is first-class in UI/storage, with no depth cap.

- File: `lib/presentation/pages/calendar/calendar_page.dart`
- Before: all overlapping ranges render in hourly grid.
- After: multi-day ranges render as top horizontal bars.
