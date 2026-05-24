# fix-calendar-refresh-and-ai-options

## Why
1. Home creates a schedule successfully, but the week calendar keeps stale events until the user switches month/week and triggers a reload.
2. AI goal breakdown responses may include `[OPTIONS: ...]` text, but the chat UI renders it as plain text instead of clickable suggestion buttons.

## Impact
GitNexus impact, refreshed on 2026-05-24:
- `CalendarPage`: LOW risk. Direct upstream importers: `app_router.dart`, `home_page.dart`; depth 2 reaches `main.dart`, `login_page.dart`, `register_page.dart`; no affected process groups.
- `_CalendarPageState`: LOW risk. Same upstream surface as `CalendarPage`.
- `_HomePageState`: LOW risk. Direct upstream importers: `main.dart`, `app_router.dart`; depth 2 reaches widget smoke test and auth pages.
- `HomePage._createSchedule`: LOW risk. No upstream callers detected beyond widget callback wiring.
- `CalendarPage._createSchedule`: LOW risk. No upstream callers detected beyond widget callback wiring.
- `_AiChatPageState`: LOW risk. Direct upstream importers: `app_router.dart`, `home_page.dart`; no high-risk processes.
- `_callAI`: LOW risk. Direct callers: `_sendMessage`, `_quickAction`, `_suggestionClicked`; affected processes: AI page build / quick actions.
- `_generateSuggestions`: LOW risk. Direct caller: `_callAI`; affected processes: AI page build / quick actions.
- `_buildBubble`: LOW risk. Direct caller: `_buildMessageList`; affected process: AI page build.

## Business Context
- Main spec hit: `openspec/specs/smart-butler/spec.md`
- Requirements hit: Calendar view, AI task breakdown.
- Active change collision:
  - `claude-ui-and-progressive-ai`: same AI suggestion button capability; current bug is a sibling issue, not a conflicting behavior.
  - `schedule-status-checkbox-control`: touches calendar schedule rendering; refresh fix is additive and does not change status behavior.
- Historical BugFixSpecs hit: none for these two capabilities. Existing auth bugfixspec is unrelated.

## Change Scope
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/presentation/pages/ai_chat/ai_chat_page.dart`
- `regression-tests/cases/fix-calendar-refresh-and-ai-options.md`
- `openspec/changes/fix-calendar-refresh-and-ai-options/*`

## Acceptance
- [x] Creating a schedule from Home, then opening Calendar week view, shows the new schedule without switching month/week.
- [x] AI response containing `[OPTIONS: a | b | c]` displays clickable option chips and hides the raw marker line.
- [x] Clicking an AI option sends that option as the next user message.
- [x] `flutter analyze --no-fatal-infos` has no errors.
- [x] `flutter test` passes.
- [x] `gitnexus detect-changes --scope all -r smart-assistant` executed; scope is broad because of pre-existing dirty worktree changes and is recorded in delivery.

## Bug Fix Log
See `bugfix.md`.
