# Regression Cases: planner-flow-multiday-task-ui

## Batch Test Endpoint
- command_or_url: `flutter analyze --no-fatal-infos`; `flutter test`
- auth: local test/default user
- env: Flutter desktop/web test environment

## Cases
| case_id | Goal | Input Summary | Expected Key Output | Assert | Source | Status |
|---|---|---|---|---|---|---|
| onboarding-three-goals | Goal step validation | enter 3 trimmed non-empty goals | next enabled immediately | UI state visible | user | automated-pass/manual-pending |
| onboarding-skip-profile | Optional occupation skip | launch optional profile prompt, skip/back | one action returns Home, no immediate re-prompt | manual | user | automated-pass/manual-pending |
| schedule-time-clarity | Time selection clarity | create/edit time in 12-hour locale | 上午/下午 or HH:mm visible | manual/widget | user | automated-pass/manual-pending |
| ai-current-options | Relevant AI chips | AI asks current question | chips match current question, stale chips absent | widget/manual | user | automated-pass/manual-pending |
| ai-plan-table-flow | Structured plan display | final AI plan text | table rows and flowchart hierarchy visible | widget/manual | user | automated-pass/manual-pending |
| ai-plan-no-pipes | Markdown artifact cleanup | final AI plan contains `|` table rows | rendered table and mind-map do not show raw `|` separators | widget/manual | user | pending |
| schedule-edit-add-subtask | Schedule edit subtask entry | edit an existing schedule | Add Subtask opens task creation and stores parentScheduleId | manual/widget | user | pending |
| nested-subtasks | Unlimited subtasks | add child under child under child | parent references retained, UI allows next child | manual/unit | user | automated-pass/manual-pending |
| calendar-task-open-detail | Calendar task interaction | tap task/subtask bar in week calendar | task detail opens and Add Subtask is available | manual/widget | user | automated-pass/manual-pending |
| subtask-exact-time | Subtask exact time | create/edit subtask with start/end time | stored DateTime keeps selected HH:mm | manual/widget | user | automated-pass/manual-pending |
| ai-plan-assign-preview | AI plan assignment | right-click final plan card and assign | editable preview opens, saved tasks have concrete date/time | manual/widget | user | automated-pass/manual-pending |
| calendar-single-day-task-visible | Calendar task visibility | create one-hour subtask or assigned AI task today | task appears in hourly grid | manual/widget | user | automated-pass/manual-pending |
| ai-question-markdown-options | AI question formatting/options | AI question contains bold markdown | bubble hides `**`, suggestion chips appear | manual/widget | user | automated-pass/manual-pending |
| ai-assign-button-position | Plan assignment placement | final plan card with mind-map | 一键分配任务 button appears at mind-map lower-right | manual/widget | user | automated-pass/manual-pending |
| multiday-task-range | Multi-day task storage | May 24-30, 2026 | start/end retained | unit/manual | user | automated-pass/manual-pending |
| calendar-multiday-bar | Week spanning bar | item May 24-30, 2026 in week view | top horizontal bar spans matching days | widget/manual | user | automated-pass/manual-pending |
| ai-plan-rendering-stable | Stable plan rendering | final answer with table/list plan | plan card shows table and mind-map actions | manual/widget | user | automated-pass/manual-pending |
| ai-no-stale-plan-options | No stale final-plan chips | long/final plan ending with a question | no old answer chips shown | manual/widget | user | automated-pass/manual-pending |
| calendar-drag-resize | Calendar resize drag | drag timed item top/bottom | start/end changes in 15-minute slots | manual/widget | user | automated-pass/manual-pending |
| calendar-drag-change-day | Calendar day drag | drag Monday timed item to Tuesday | item date becomes Tuesday and duration is preserved | manual/widget | user | automated-pass/manual-pending |
| parent-task-delete-blocked | Parent delete guard | parent has at least one child task | delete throws/blocks and parent remains | unit/manual | user | automated-pass |
| task-default-same-day | Same-day default task range | create task/subtask without explicit end date | end defaults one hour later on same day | manual/widget | user | automated-pass/manual-pending |

## Notes
- Do not store full AI responses or screenshots here.
- Keep expected outputs to key fields and visible behavior only.
