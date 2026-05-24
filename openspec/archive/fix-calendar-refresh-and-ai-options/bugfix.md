# BugFix Log: fix-calendar-refresh-and-ai-options

## Bug Index

| bug_id | Symptom | Related files/symbols | bugfix_count | Current state | Needs sinking |
|---|---|---|---:|---|---|
| calendar-home-create-stale-week | Home-created schedule does not show in Calendar week view until month/week toggle | `home_page.dart` / `_createSchedule`, `calendar_page.dart` / `_loadEvents` | 1 | open | No |
| ai-options-raw-text | AI options render as raw `[OPTIONS: ...]` text and cannot be clicked | `ai_chat_page.dart` / `_callAI`, `_buildBubble`, `_generateSuggestions` | 1 | open | No |

## Bug Events

### calendar-home-create-stale-week / fix 1
- Trigger time: 2026-05-24
- User symptom: "刚刚在首页创建了日程 周日历上不会显示日程，需要切换月然后切回来才显示"
- Repro path: Home -> create schedule -> open Calendar week view -> schedule absent -> switch month then week -> schedule appears.
- Trigger condition: schedule is created outside `CalendarPage`, while Calendar keeps old `_events`.
- Failure verification: code inspection shows Home calls `_loadStats()` after create; Calendar reloads only on its own format/page/today/create/edit/delete/move interactions.
- Root cause hypothesis: missing cross-tab state invalidation.
- Final root cause: `CalendarPage` cached `_events` and had no invalidation signal when `HomePage` wrote schedules to the same storage.
- Fix point: `HomePage` increments a Calendar refresh token after schedule writes and when opening the Calendar tab; `CalendarPage.didUpdateWidget` reloads events when the token changes.
- Verification result: `flutter analyze --no-fatal-infos` passed; `flutter test` passed; manual UI confirmation remains pending.
- Same bug: first known occurrence.

### ai-options-raw-text / fix 1
- Trigger time: 2026-05-24
- User symptom: screenshot shows `[OPTIONS: 零基础 | 会一点点 | 有基础]` inside the AI bubble; options cannot be clicked.
- Repro path: AI goal breakdown -> AI asks level question -> LLM returns explicit `[OPTIONS]` protocol line -> UI renders raw text.
- Trigger condition: response contains explicit options protocol rather than relying only on local keyword suggestion generation.
- Failure verification: `_callAI` adds the raw response as message text and only calls `_generateSuggestions` based on trailing question punctuation.
- Root cause hypothesis: UI lacks parser for prompt-level option protocol.
- Final root cause: the UI did not parse the explicit `[OPTIONS: ...]` protocol line emitted by the AI prompt and therefore rendered it as normal bubble text.
- Fix point: `_callAI` now extracts explicit options before adding the AI message; `_extractExplicitOptions` removes the marker line and stores parsed options as `suggestions`.
- Verification result: `flutter analyze --no-fatal-infos` passed; `flutter test` passed; manual UI confirmation remains pending.
- Same bug: related to `claude-ui-and-progressive-ai` AI suggestion capability, but distinct visible symptom from keyword mismatch.
