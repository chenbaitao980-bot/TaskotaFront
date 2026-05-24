# planner-flow-multiday-task-ui

## Why
1. Onboarding 填写 3 个目标后仍可能无法进入下一步，且职业信息弹出/返回链路不符合“暂不填写也能回首页”的预期。
2. 新建日程只显示 12 小时制但没有上午/下午区分，用户无法可靠选择时间。
3. AI 给出计划后，建议选项仍可能与当前问题不匹配；最终计划需要渲染成表格和流程图，而不是只给大段文本。
4. 任务拆解需要支持无限层级子任务，并允许大任务跨多天；日历周视图应把跨天任务渲染成顶部横向长条。

## Impact
GitNexus impact, checked on 2026-05-24:
- `OnboardingPage`: LOW risk. Direct upstream importer: `home_page.dart`; depth 2 reaches `main.dart`, `app_router.dart`.
- `ProfilePage`: LOW risk. Direct upstream importers: `app_router.dart`, `home_page.dart`; depth 2 reaches auth pages and `main.dart`.
- `AiChatPage` / `_AiChatPageState`: LOW risk. Direct upstream importers: `app_router.dart`, `home_page.dart`.
- `_generateSuggestions`: LOW risk. Direct caller `_callAI`; affected AI build / quick action flows.
- `CalendarPage` / `_CalendarPageState`: LOW risk. Direct upstream importers: `app_router.dart`, `home_page.dart`.
- `CreateScheduleDialog`: HIGH risk. Direct callers include Home and Calendar create/edit flows; affected processes include week/month render, event block render, and schedule edit/create.
- `TaskBreakdown`: HIGH risk. Direct impacts task entity generation, local/Supabase task storage, task create/update, task list/detail, AI chat, calendar, schedule bloc.

## Business Context
- Main spec hit: `openspec/specs/smart-butler/spec.md`
- Requirements hit: Calendar view, AI task breakdown, user registration/login onboarding profile.
- Existing active changes:
  - `fix-calendar-refresh-and-ai-options`: already fixed explicit `[OPTIONS: ...]` parsing and calendar refresh. This change extends option relevance and plan rendering.
  - `claude-ui-and-progressive-ai`: already covers visual theme and progressive AI. This change extends the final plan surface and task model.
  - `schedule-status-checkbox-control`: touches calendar rendering; this change adds multi-day all-day-style bars and must preserve checkbox/status behavior.
  - `mvp-core-features` and `smart-butler-core-intelligence`: broader MVP work; this change is a focused modification to existing smart-butler capability.
- Historical BugFixSpecs hit: `auth/register-click-no-response.md` is unrelated.

## Change Scope
- `lib/presentation/pages/onboarding/onboarding_page.dart`
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/profile/profile_page.dart`
- `lib/presentation/pages/ai_chat/ai_chat_page.dart`
- `lib/services/ai_service.dart`
- `lib/presentation/widgets/create_schedule_dialog.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/models/entities/task_breakdown.dart`
- generated model files for `TaskBreakdown`, if the model changes require code generation
- `lib/services/local_storage_service.dart`
- task create/list/detail pages if hierarchical subtasks need visible add/manage controls
- `regression-tests/cases/planner-flow-multiday-task-ui.md`

## Acceptance
- [x] Onboarding can proceed after three non-empty goals; validation updates as the user types and never depends on stale widget state.
- [x] User can skip/close the occupation/profile prompt and return to Home with one back action.
- [x] Schedule time picker clearly distinguishes 12-hour AM/PM or uses an unambiguous 24-hour display.
- [x] AI suggestion chips match the current AI question and do not reuse stale/default options after a plan is produced.
- [x] Final AI plan renders as a structured table and a readable flowchart/step graph.
- [x] Tasks can contain unlimited-depth subtasks through parent-child relationships.
- [x] Tasks can span multiple days with start/end dates.
- [x] Week calendar renders multi-day tasks as top horizontal bars spanning the relevant days, while same-day timed schedules remain in the hourly grid.
- [x] Touch targets are at least 48dp; text does not overflow on small screens; colors come from the app theme.
- [x] `flutter analyze --no-fatal-infos` has no errors.
- [x] `flutter test` passes.
- [x] `gitnexus detect-changes --scope all -r smart-assistant` is executed before delivery.

## Bug Fix Log
See `bugfix.md`.
