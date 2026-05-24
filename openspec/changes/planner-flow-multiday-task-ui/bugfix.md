# BugFix Log: planner-flow-multiday-task-ui

## Bug Index

| bug_id | Symptom | Files/Symbols | bugfix_count | Status | Needs BugFixSpec |
|---|---|---|---:|---|---|
| onboarding-goals-next-disabled | Filling three goals still cannot proceed | `OnboardingPage` | 1 | fixed | No |
| onboarding-profile-back-stack | Optional occupation/profile prompt requires two backs to Home | `HomePage`, `OnboardingPage`, `ProfilePage` | 2 | fixed | Yes on archive |
| schedule-time-ambiguous | 12-hour time lacks AM/PM distinction | `CreateScheduleDialog` | 1 | fixed | No |
| ai-options-off-topic | AI option chips mismatch current plan/question | `AiChatPage`, `AIService` | 1 | fixed | No |
| plan-not-structured | AI final plan/table/flow renders with raw markdown artifacts or weak structure | `AiChatPage` | 2 | fixed | Yes on archive |
| task-no-unlimited-subtasks | Tasks do not expose unlimited-depth subtasks | `TaskBreakdown`, task pages, storage | 1 | fixed | No |
| schedule-edit-no-subtask-entry | Editing a schedule does not expose add-subtask action | `CreateScheduleDialog`, `HomePage`, `CalendarPage`, `CreateTaskPage`, storage | 1 | fixed | No |
| subtask-calendar-no-detail | Tapping calendar task/subtask bar does not open task detail | `CalendarPage`, `TaskDetailPage` | 1 | fixed | No |
| subtask-no-exact-time | Task/subtask create only supports dates, not exact times | `CreateTaskPage`, `TaskDetailPage` | 1 | fixed | No |
| ai-plan-no-assignment | AI final plan cannot be one-click assigned into dated tasks | `AiChatPage`, `LocalStorageService` | 1 | fixed | No |
| calendar-single-day-task-hidden | Single-day subtasks and assigned AI tasks do not appear in calendar | `CalendarPage` | 1 | fixed | No |
| ai-question-markdown-breaks-options | AI question bubble shows `**` and suggestions can be hidden | `AiChatPage` | 1 | fixed | No |
| ai-assign-action-position | One-click assignment action is not positioned in mind-map lower-right | `AiChatPage` | 1 | fixed | No |
| task-no-multiday-bars | Multi-day tasks cannot render as week-spanning bars | `CalendarPage`, `TaskBreakdown`, storage | 1 | fixed | No |
| ai-plan-rendering-regressed | AI final plan no longer renders Excel-style table and mind-map | `AiChatPage` | 3 | fixed | Yes on archive |
| ai-options-regressed | AI option chips can answer stale/previous questions | `AiChatPage`, `AIService` | 2 | fixed | Yes on archive |
| calendar-drag-resize-regressed | Calendar items can no longer drag vertically to resize time | `CalendarPage`, `CreateScheduleDialog`, storage | 1 | fixed | No |
| calendar-drag-day-move | Calendar items cannot drag to another day and update date | `CalendarPage`, storage | 1 | fixed | No |
| task-delete-parent-with-children | A task with subtasks can still be deleted | `TaskDetailPage`, `LocalStorageService` | 1 | fixed | No |
| task-default-cross-day | New tasks/subtasks default to cross-day ranges | `CreateTaskPage` | 1 | fixed | No |

## Bug Events

### onboarding-goals-next-disabled / first fix
- Trigger time: 2026-05-24
- User symptom: “填了三个目标后依然无法进行下一步”
- Repro path: onboarding -> goals step -> fill three goals -> next disabled.
- Root cause hypothesis: raw list mutation without rebuild/trimmed validation.
- Final root cause: goal text lived in a raw list and did not force reactive validation on each text edit.
- Fix points: `OnboardingPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual UI check remains.

### onboarding-profile-back-stack / first fix
- Trigger time: 2026-05-24
- User symptom: “打开后弹出填写个人职业，我暂时不想填写，返回要点两下才能返回首页”
- Repro path: app launch -> profile/onboarding prompt -> back.
- Root cause hypothesis: pushed optional prompt route creates stacked navigation and re-prompt.
- Final root cause: Home checked onboarding before storage finished initializing and the optional prompt had no skip contract.
- Fix points: `HomePage`, `OnboardingPage`, maybe `ProfilePage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual clean-state check remains.

### onboarding-profile-back-stack / second fix
- Trigger time: 2026-05-24
- User symptom: Close icon exists but still needs two taps to return Home.
- Repro path: onboarding -> advance to later step -> tap leading back/close.
- Root cause hypothesis: the leading control still changed into step-back on later steps.
- Final root cause: close-to-home was not persistent across all onboarding steps.
- Fix points: `OnboardingPage`.
- Verification: pending current run.

### schedule-time-ambiguous / first fix
- Trigger time: 2026-05-24
- User symptom: “新建流程的小时为何只有十二小时，如果是十二小时给一个上午下午区分”
- Repro path: create schedule -> choose time.
- Root cause hypothesis: locale time formatting/picker display ambiguous.
- Final root cause: one-date plus `TimeOfDay.format` flow relied on locale display and did not support an explicit end date.
- Fix points: `CreateScheduleDialog`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual picker check remains.

### ai-options-off-topic / first fix
- Trigger time: 2026-05-24
- User symptom: “给出了这个计划以后选项为何还是答非所问”
- Repro path: AI goal breakdown -> final plan -> suggestion chips remain unrelated.
- Root cause hypothesis: broad fallback keyword suggestions survive after final plan.
- Final root cause: fallback keyword suggestions were still allowed after complete plans.
- Fix points: `AiChatPage`, `AIService`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; live LLM output check remains.

### plan-not-structured / first fix
- Trigger time: 2026-05-24
- User symptom: “计划要渲染成excel表格和流程图的形式”
- Repro path: AI final plan response.
- Root cause hypothesis: no structured plan renderer.
- Final root cause: chat messages had no final-plan view model or renderer.
- Fix points: `AiChatPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual plan rendering check remains.

### plan-not-structured / second fix
- Trigger time: 2026-05-24
- User symptom: plan table and flow still show ugly `|` markdown separators; flow should be a mind-map.
- Repro path: AI final plan response containing markdown table pipes.
- Root cause hypothesis: renderer consumed row strings after only light markdown cleanup.
- Final root cause: table lines were not parsed into cells before rendering and the flow renderer was still linear.
- Fix points: `AiChatPage`.
- Verification: pending current run.

### schedule-edit-no-subtask-entry / first fix
- Trigger time: 2026-05-24
- User symptom: editing a schedule still has no add-subtask option.
- Repro path: calendar/home schedule card -> edit dialog.
- Root cause hypothesis: subtask entry was added only to task detail, not schedule editing.
- Final root cause: `CreateScheduleDialog` exposed only delete/cancel/save edit actions.
- Fix points: `CreateScheduleDialog`, `HomePage`, `CalendarPage`, `CreateTaskPage`, `LocalStorageService.createTask`.
- Verification: pending current run.

### task-no-unlimited-subtasks / first fix
- Trigger time: 2026-05-24
- User symptom: “任务允许无限添加子任务，AI拆解分配任务也需要从大任务到小任务依次分配”
- Repro path: task create/detail/AI decomposition.
- Root cause hypothesis: UI only exposes flat or fixed-level task model.
- Final root cause: parent-child relationship was not represented as a task parent id in UI/storage creation.
- Fix points: `TaskBreakdown`, storage, task pages, AI plan import.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual nested task check remains.

### subtask-calendar-no-detail / first fix
- Trigger time: 2026-05-24
- User symptom: “点击子任务没有反应”.
- Repro path: calendar week view -> tap task/subtask horizontal bar.
- Root cause hypothesis: task bar tap callback is empty.
- Final root cause: calendar multi-day task items used an empty `onTap` callback instead of opening task detail.
- Fix points: `CalendarPage`, `TaskDetailPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual calendar tap check remains.

### subtask-no-exact-time / first fix
- Trigger time: 2026-05-24
- User symptom: “子任务无法选择具体时间，只能选择日期”.
- Repro path: create/edit subtask -> date range section.
- Root cause hypothesis: `CreateTaskPage` only exposes date pickers although model uses `DateTime`.
- Final root cause: task creation/edit UI only exposed date pickers and preserved default time implicitly.
- Fix points: `CreateTaskPage`, `TaskDetailPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual time picker check remains.

### ai-plan-no-assignment / first fix
- Trigger time: 2026-05-24
- User symptom: AI final plan lacks right-click one-click assignment; generated plan lacks exact date/time and detail adjustment.
- Repro path: AI final plan card -> right-click/action menu.
- Root cause hypothesis: plan card is display-only with no preview/save workflow.
- Final root cause: final-plan card had no context menu/action menu and no draft task preview before storage creation.
- Fix points: `AiChatPage`, `LocalStorageService`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual right-click and save check remains.

### calendar-single-day-task-hidden / first fix
- Trigger time: 2026-05-24
- User symptom: “添加完子任务后日历上并没有显示”; “一键分配的任务并没有出现在日历上面”.
- Repro path: create subtask or assign AI plan -> calendar week view.
- Root cause hypothesis: calendar renders only schedules in the hourly grid and only multi-day tasks in the top lane.
- Final root cause: calendar rendered tasks only in the multi-day lane; same-day/short tasks were never mapped into hourly blocks.
- Fix points: `CalendarPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual calendar visibility check remains.

### ai-question-markdown-breaks-options / first fix
- Trigger time: 2026-05-24
- User symptom: AI options do not appear; question text shows raw `**`.
- Repro path: AI asks a question with bold markdown around the question.
- Root cause hypothesis: display and question detection use raw AI markdown text.
- Final root cause: AI display and question detection used raw markdown text, so trailing `**` could prevent question matching and leaked into bubbles.
- Fix points: `AiChatPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual live AI response check remains.

### ai-assign-action-position / first fix
- Trigger time: 2026-05-24
- User symptom: 一键分配按钮 should be in the mind-map lower-right.
- Repro path: final AI plan card.
- Root cause hypothesis: action was placed in the plan table header instead of the mind-map action area.
- Final root cause: the primary assignment action was attached to the plan table header rather than the mind-map action area.
- Fix points: `AiChatPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual placement check remains.

### task-no-multiday-bars / first fix
- Trigger time: 2026-05-24
- User symptom: “任务跨多天，比如24号到30号；日历样式改成长条”
- Repro path: create large task with range -> calendar week view.
- Root cause hypothesis: schedule dialog/calendar timeline assumes same-day hourly placement.
- Final root cause: storage filtering used containment semantics and calendar rendering treated all ranges as hourly blocks.
- Fix points: `CalendarPage`, `TaskBreakdown`, storage, task UI.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual week-span check remains.

### ai-plan-rendering-regressed / third fix
- Trigger time: 2026-05-24
- User symptom: Final AI plan used to render Excel-style table and mind-map, but now shows plain text again.
- Repro path: AI chat -> final planning answer.
- Root cause hypothesis: final-plan detection is too strict and misses long plan answers without exact marker text.
- Final root cause: final-plan detection only matched narrow step keywords and missed table/list plan answers.
- Fix points: `AiChatPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual live AI check remains.

### ai-options-regressed / second fix
- Trigger time: 2026-05-24
- User symptom: AI answer chips are again not matching the current question.
- Repro path: AI chat -> answer a planning question -> chips shown after long/final response.
- Root cause hypothesis: fallback suggestion generation still derives chips from broad content instead of explicit options/current question.
- Final root cause: fallback suggestion generation still ran for long plan answers that ended with a question.
- Fix points: `AiChatPage`, `AIService`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual live AI check remains.

### calendar-drag-resize-regressed / first fix
- Trigger time: 2026-05-24
- User symptom: Calendar used to support dragging top/bottom range to adjust time, but no longer does.
- Repro path: week calendar -> drag a timed item vertically.
- Root cause hypothesis: event block rendering lost resize handles during multi-day/hourly rendering changes.
- Final root cause: only schedule blocks exposed drag handles; task blocks rendered as static timeline cards.
- Fix points: `CalendarPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual drag check remains.

### calendar-drag-day-move / first fix
- Trigger time: 2026-05-24
- User symptom: Dragging a Monday item to Tuesday should update it to Tuesday.
- Repro path: week calendar -> drag a timed item into another day column.
- Root cause hypothesis: drag target only supports opening/editing, not date mutation.
- Final root cause: timeline drag data was schedule-only, so task movement could not update stored dates.
- Fix points: `CalendarPage`, `LocalStorageService`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual drag check remains.

### task-delete-parent-with-children / first fix
- Trigger time: 2026-05-24
- User symptom: A task with subtasks should not be deletable.
- Repro path: task detail -> task with child tasks -> delete.
- Root cause hypothesis: delete action does not check child references before removing parent.
- Final root cause: task deletion did not check `parentTaskId` children before removing the parent.
- Fix points: `TaskDetailPage`, `LocalStorageService`.
- Verification: added `local_storage_service_test.dart`; `flutter test` passed.

### task-default-cross-day / first fix
- Trigger time: 2026-05-24
- User symptom: New task/subtask should not default to a cross-day range.
- Repro path: create task or subtask.
- Root cause hypothesis: default end date is derived from tomorrow or inherited multi-day parent range.
- Final root cause: create task defaults used a seven-day fallback end date for new tasks and subtasks.
- Fix points: `CreateTaskPage`.
- Verification: `flutter analyze --no-fatal-infos` and `flutter test` passed; manual create form check remains.
