# Delta: smart-butler

## MODIFIED Requirements

### Requirement: AI任务拆解
AI SHALL guide the user through a TaskFlow-style planning conversation before producing final tasks.

#### Scenario: Missing planning information
- WHEN the user gives a broad goal
- AND current level, available time, deadline, or constraints are missing
- THEN AI SHALL ask exactly one highest-value question
- AND AI SHALL provide three relevant Chinese quick-reply options.

#### Scenario: Final executable plan
- WHEN enough information has been collected
- THEN AI SHALL output a Markdown table with stage, task, time range, and notes
- AND AI SHALL output a hierarchy suitable for mind-map rendering
- AND each row SHALL be specific enough to create a task with title, notes, start time, and end time.

#### Scenario: Assign final plan to tasks
- WHEN the user chooses one-click assignment from a final plan
- THEN generated tasks SHALL retain task title, notes, start/end time, and parent-child relationship where available
- AND generated tasks SHALL be visible in task pages and the calendar.

### Requirement: 用户提示
User-facing transient prompts SHALL be Chinese and dismissible.

#### Scenario: Parent task has subtasks
- WHEN the user tries to delete a task that still has subtasks
- THEN the app SHALL show a Chinese prompt explaining that child tasks must be handled first
- AND the prompt SHALL be dismissible by user action.
