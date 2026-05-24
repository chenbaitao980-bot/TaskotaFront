# Design: planner-flow-multiday-task-ui

## Current State
Onboarding stores goals in a raw list updated by text fields, but button enablement can miss state refresh. Home auto-pushes onboarding/profile collection, so dismissing can leave an extra navigation layer. Schedule creation uses date plus start/end `TimeOfDay`, so cross-day ranges are not supported from the dialog. AI chat stores plain messages plus optional suggestions, but the final plan has no structured table/flowchart presentation. `TaskBreakdown` already has `parentGoalId`, `startDate`, and `endDate`, but UI/storage do not expose unlimited nested subtasks as a first-class workflow. Calendar week view renders all overlapping events in the hourly grid, including multi-day ranges that should become spanning bars.

## Plan
1. Fix onboarding validation and navigation by making goal text controllers/state reactive, adding an explicit skip path for optional profile fields, and replacing stacked push behavior with a single dismissible flow.
2. Update schedule creation/editing so users choose start date/time and end date/time. Use either 24-hour text or platform 12-hour labels with clear 上午/下午.
3. Improve AI option relevance by deriving suggestions from the latest assistant question or explicit `[OPTIONS]` only, clearing stale suggestions after a final plan, and preferring semantic categories over broad keyword hits.
4. Detect final plan responses and render them with a task table plus a flowchart-style hierarchy. Keep the original text available but visually secondary.
5. Treat tasks as a tree: each task can have `parentGoalId` or another parent task id, and UI offers “add subtask” at every level. Avoid hard depth limits.
6. Allow task start/end dates to span multiple days. Store the range on `TaskBreakdown`; for schedules, keep exact start/end timestamps.
7. Split calendar rendering into timed events and multi-day bars. Multi-day items render in a top lane above the hourly grid, spanning day columns from max(rangeStart, weekStart) to min(rangeEnd, weekEnd).
8. Preserve existing status checkbox interactions and drag/resize behavior for same-day timed schedules.

## Data Lifecycle
Onboarding write chain:
`Home check onboarding -> OnboardingPage controllers -> skip or complete -> LocalStorageService.saveExplicitProfile/setOnboardingCompleted -> pop once -> Home`

AI plan chain:
`AIService.chat -> response text/options -> AiChatPage parse -> suggestions or final-plan model -> table rows + flow nodes -> optional task creation`

Task tree write chain:
`user/AI create parent task -> LocalStorageService.createTask(parentGoalId/parentTaskId) -> nested UI -> child create repeats without depth limit`

Multi-day calendar read chain:
`LocalStorageService.getSchedules/getTasks(range overlap) -> CalendarPage classify multi-day vs timed -> top bar lane + hourly grid`

## Business Rule Handling
- Existing Requirement: AI task breakdown SHALL ask necessary information and output structured tasks.
- Existing Requirement: Calendar view SHALL show schedules in week/month views and support direct create/edit/delete.
- Existing Requirement: user profile/onboarding data helps AI personalize plans.
- Handling: MODIFIED existing smart-butler capability, not a new capability.

## Historical BugFixSpecs
- Hit files: none.
- Unrelated: `openspec/bugfixspecs/auth/register-click-no-response.md`.

## Bug Root Cause Analysis
- Onboarding symptom: three goals filled but next stays unavailable. Failure layer: UI state. Root cause: goal values are mutated without guaranteed rebuild/trimmed validation.
- Profile/back symptom: optional occupation prompt blocks Home and back needs two taps. Failure layer: navigation. Root cause: optional onboarding/profile route is pushed on top of Home without an explicit skip/dismiss contract.
- Time symptom: 12-hour selection lacks AM/PM. Failure layer: form display. Root cause: formatted time is ambiguous for the current locale/string rendering.
- AI options symptom: chips answer the wrong question after a plan. Failure layer: suggestion derivation. Root cause: fallback keyword matching can use broad/stale categories when explicit options are absent or plan text includes old keywords.
- Plan rendering symptom: plan is plain text only. Failure layer: presentation model. Root cause: no structured plan parser/view model.
- Multi-day task symptom: only one-day time ranges exist. Failure layer: data entry/calendar render. Root cause: dialog and timeline assume one date plus hourly placement.

## UI/UX Rules
- Use app theme tokens; avoid ad-hoc colors.
- Touch targets >= 48dp.
- Calendar multi-day bars use clear contrast, compact labels, and stable height lanes.
- Table rows and flow nodes wrap text rather than overflow.
- Icon-only controls need semantic labels/tooltips where Flutter supports them.
- Do not add in-app explanatory marketing copy; controls should be self-evident.

## Regression Plan
- Case file: `regression-tests/cases/planner-flow-multiday-task-ui.md`
- Commands: `flutter analyze --no-fatal-infos`; `flutter test`; `gitnexus detect-changes --scope all -r smart-assistant`
- Manual checks: onboarding skip/back, three-goal next button, AM/PM or 24-hour clarity, final plan table/flowchart rendering, nested subtasks, cross-day bar spanning 24-30 May 2026.

## Rollback
Revert onboarding navigation/validation, schedule dialog date-time range changes, AI plan parser/view changes, task tree UI/model changes, and calendar multi-day bar rendering.
