# Design: fix-schedule-create-feedback

## Current State
`HomePage` and `CalendarPage` create schedules directly through `LocalStorageService.createSchedule()`. They do not show success messages, do not catch save/reminder failures, and do not explicitly ensure storage is initialized immediately before save. `HomePage` also caches `_HomeContent` inside `_pages` in `initState`, so state-derived values passed to the home content can become stale.

## Approach
- Ensure local storage is initialized before schedule create/read operations that depend on it.
- Wrap create schedule flows in `try/catch`.
- Show a success SnackBar after a schedule is saved.
- Show a clear error SnackBar if saving fails.
- Rebuild the `IndexedStack` pages from current state in `build()` instead of caching `_HomeContent` with stale constructor values.
- Keep the storage model and dialog fields unchanged.

## Business Rule Handling
- Existing Requirement / Scenario: calendar schedule creation should save to local and cloud. The current app's MVP path saves to local storage.
- Handling: bug fix against existing schedule creation behavior; no new capability.

## Historical BugFixSpecs
- Hit files: none found under `openspec/bugfixspecs`.
- Historical root cause: none.
- Prevention check: every user-triggered save must have visible success/error feedback and refresh the affected view.

## Bug Root Cause Analysis
- User-visible symptom: tapping create schedule has no visible result.
- Failure layer: UI feedback and refresh after local persistence.
- Root cause hypothesis:
  - Save errors are not caught or shown.
  - Storage initialization can race with user actions.
  - Home content is cached in `_pages`, so refreshed state can fail to propagate.
- Excluded causes: the FloatingActionButton and dialog save button have `onPressed` handlers; local storage has a create method.

## Data Lifecycle
Write chain: tap create -> dialog returns form data -> ensure storage init -> create local schedule -> schedule reminders -> refresh visible list -> show success.

Read/render chain: page build -> storage reads schedules for selected/today range -> widget rebuild displays list or empty state.

## Regression Test Plan
- Case file: `regression-tests/cases/fix-schedule-create-feedback.md`
- Commands: `flutter test`, `flutter build windows --release`
- Manual/UI case: create today's schedule from Home and verify success SnackBar plus list item.

## Rollback
Revert changes in `home_page.dart`, `calendar_page.dart`, and remove this change's regression artifacts.
