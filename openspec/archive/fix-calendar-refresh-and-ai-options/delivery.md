# Delivery: fix-calendar-refresh-and-ai-options

## Completed
- Added a `refreshToken` input to `CalendarPage`.
- `HomePage` now increments the Calendar refresh token after create/update/delete and when opening the Calendar tab.
- `CalendarPage.didUpdateWidget` reloads `_events` when the refresh token changes.
- AI responses with `[OPTIONS: ...]` are parsed into clickable suggestion chips.
- Raw `[OPTIONS: ...]` marker lines are removed from the displayed AI bubble.
- Added regression case file: `regression-tests/cases/fix-calendar-refresh-and-ai-options.md`.
- Added regression run file: `regression-tests/runs/fix-calendar-refresh-and-ai-options-latest.md`.

## Verification
- `flutter analyze`: 4 info issues, no errors.
- `flutter analyze --no-fatal-infos`: pass.
- `flutter test`: pass.
- `gitnexus detect-changes --scope all -r smart-assistant`: executed. Result reported CRITICAL because the worktree already contains broad pre-existing changes outside this bugfix scope.

## Manual Checks Pending
- Home creates schedule -> Calendar week view shows it immediately.
- AI goal breakdown renders clickable option chips instead of raw `[OPTIONS: ...]`.
- Clicking an option sends that option as the next user reply.
