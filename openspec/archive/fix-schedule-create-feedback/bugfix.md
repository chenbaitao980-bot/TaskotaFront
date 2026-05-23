# BugFix Log: fix-schedule-create-feedback

## Bug Index

| bug_id | Symptom | Related files/symbols | bugfix_count | Status | Needs BugFixSpec |
|---|---|---|---:|---|---|
| schedule-create-no-visible-result | Clicking create schedule has no visible result or data reflection | `home_page.dart` / `_createSchedule`; `calendar_page.dart` / `_createSchedule`; `LocalStorageService` | 1 | open | No |

## Bug Events

### schedule-create-no-visible-result / Attempt 1
- Trigger time: 2026-05-23
- User symptom: "点击创建日程没有反应 没有任何数据体现"
- Reproduction path: open app, click create schedule/new schedule, save a schedule, observe no visible result.
- Trigger conditions: schedule creation flow through Home or Calendar local storage path.
- Failed verification: no success message, no visible list/calendar update, and failures would not be shown.
- Root-cause hypothesis: missing save feedback/error handling, possible storage initialization race, and stale cached Home content.
- Final root cause: schedule creation saved through local storage without visible success/error feedback, did not explicitly guard against storage initialization races, and Home cached `_HomeContent` inside `_pages` so refreshed state could fail to propagate to the visible content.
- Fix points: `lib/presentation/pages/home/home_page.dart`, `lib/presentation/pages/calendar/calendar_page.dart`
- Verification result: `flutter test` passed; `flutter build windows --release` passed; `flutter analyze` completed with only pre-existing deprecated API info.
- Same bug: yes; first recorded attempt.
