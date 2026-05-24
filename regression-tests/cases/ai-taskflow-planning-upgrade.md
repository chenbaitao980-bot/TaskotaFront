# Regression Cases: ai-taskflow-planning-upgrade

## Batch Test Endpoint
- command_or_url: `flutter analyze --no-fatal-infos`; `flutter test`
- auth: local test/default user
- env: Flutter desktop/web test environment

## Cases
| case_id | Goal | Input Summary | Expected Key Output | Assert | Source | Status |
|---|---|---|---|---|---|---|
| ai-taskflow-diagnose-first | TaskFlow step1: diagnose goal | user: "我想今年学会日语" | AI does NOT ask questions before confirming goal understanding | manual/widget | spec | pending |
| ai-taskflow-one-question | TaskFlow step3: one question at a time | AI asks about current level | only one question with [OPTIONS:] appended; no other question in same reply | manual/widget | spec | pending |
| ai-plan-table-marker | Plan detection via [TABLE_BEGIN] | AI plan with [TABLE_BEGIN]...[/TABLE_END] markers | plan card renders table rows from marker content | widget/manual | spec | pending |
| ai-plan-hierarchy-marker | Hierarchy detection via [HIERARCHY_BEGIN] | AI plan with [HIERARCHY_BEGIN]...[/HIERARCHY_END] markers | mind-map renders hierarchy from marker content | widget/manual | spec | pending |
| ai-plan-no-raw-markers | Marker cleanup in display | message contains [TABLE_BEGIN] [HIERARCHY_BEGIN] markers | bubble text does not show raw markers | widget/manual | spec | pending |
| ai-plan-assign-parent-child | Assignment preserves hierarchy | plan has 战略层(2 items) + 执行层(3 items under 1st parent) | created tasks: 2 parents, 3 children with correct parentTaskId | manual/unit | spec | pending |
| parent-task-delete-chinese | Chinese dismissal guard | attempt delete task with child subtask | SnackBar shows Chinese text "该任务仍有子任务"，action "知道了" dismisses | manual/widget | spec | pending |
| ai-plan-render-table-plus-hierarchy | Dual output format | AI final plan completes | both table and hierarchy sections rendered | manual/widget | spec | pending |

## Notes
- AI response nondeterministic: cases marked `manual/widget` rely on visual confirmation plus widget tests where applicable.
- `parent-task-delete-chinese` is fully deterministic and should be automated in widget test.
