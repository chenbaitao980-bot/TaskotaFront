# Design: fix-calendar-refresh-and-ai-options

## Current State
Home and Calendar own separate page state. Home writes schedules to shared local storage and refreshes its own stats, while Calendar caches `_events` and reloads only on Calendar interactions. AI chat renders the complete LLM message and only generates chips from local keyword matching when the message ends like a question.

## Plan
1. Add a small refresh signal from `HomePage` to `CalendarPage`.
2. Increment the signal after Home creates/updates/deletes schedules and when the Calendar tab is opened.
3. Let `CalendarPage.didUpdateWidget` reload `_events` when the signal changes.
4. Parse an explicit `[OPTIONS: ...]` line from AI responses in `_callAI`.
5. Store parsed options in message `suggestions` and render the message without the marker line.
6. Keep `_generateSuggestions` as fallback when no explicit options line exists.

## Data Lifecycle
Schedule write chain:
`Home create dialog -> LocalStorageService.createSchedule -> SharedPreferences -> Home refresh signal increment -> CalendarPage.didUpdateWidget -> _loadEvents -> week/month render`

Schedule read chain:
`Calendar tab visible or refresh signal changes -> _loadEvents with focused range -> _events -> _buildWeekTimeline/_buildEventList`

AI option chain:
`AIService.chat -> response text with optional [OPTIONS] -> _extractExplicitOptions -> _addMessage(displayText) -> message.suggestions -> _buildBubble ActionChip -> _suggestionClicked -> _callAI`

## Business Rule Handling
- Existing Requirement: Calendar view SHALL show schedules in week/month views.
- Existing Requirement: AI task breakdown SHALL ask necessary information and support suggested replies.
- Handling: bugfix against existing behavior; no new capability.

## Historical BugFixSpecs
- Hit files: none.
- Unrelated: `openspec/bugfixspecs/auth/register-click-no-response.md`.

## Bug Root Cause Analysis
- Calendar visible symptom: schedule created on Home is persisted but not visible on Calendar week view until month/week toggle.
- Calendar failure layer: UI state cache.
- Calendar root cause: Calendar keeps `_events` in page state and has no invalidation signal when another page writes to storage.
- AI visible symptom: `[OPTIONS: 零基础 | 会一点点 | 有基础]` appears as text and cannot be clicked.
- AI failure layer: response parsing / UI rendering.
- AI root cause: prompt allows explicit option protocol, but UI only handles internally generated suggestions and never parses the protocol line.
- Not root cause: storage write failure; schedule appears after manual reload. LLM option content itself is present; only UI conversion is missing.

## Regression Plan
- Case file: `regression-tests/cases/fix-calendar-refresh-and-ai-options.md`
- Command: `flutter analyze`; `flutter test`
- Manual UI checks remain required for cross-tab refresh and clickable AI chips unless a widget test can be added without broad harness changes.

## Rollback
Revert the Home refresh signal, Calendar `didUpdateWidget` reload, and AI explicit option parser changes.
