# fix-schedule-create-feedback

## Why
Clicking "创建日程/新建" appears to do nothing and no schedule data is visibly reflected. The schedule creation flow currently saves through local storage without visible success/error feedback and can run before storage initialization has completed.

## Impact
GitNexus impact:
- `ScheduleBloc`: LOW risk, 2 direct upstream references from `lib/main.dart`, 0 affected processes.
- `_createSchedule`: not indexed by GitNexus; located in `home_page.dart` and `calendar_page.dart` via source search.
- BugFixSpecs: no historical hits under `openspec/bugfixspecs`.

## Business Spec Relationship
- Main spec: `openspec/specs/smart-butler/spec.md`
- Requirement: Calendar view / schedule creation
- Scenario: Calendar schedule creation
- Relationship: Bug Against Spec
- Action: code fix only; business rule unchanged.

## Scope
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- Potentially `regression-tests/cases/fix-schedule-create-feedback.md`

## Acceptance
- [ ] Clicking the create schedule action opens the schedule dialog.
- [ ] Saving a valid schedule persists it after ensuring local storage is initialized.
- [ ] A success SnackBar is shown after save.
- [ ] Save failures show a clear error SnackBar instead of failing silently.
- [ ] Home "今日日程" updates after creating a schedule for today.
- [ ] Calendar events refresh after creating a schedule.
- [ ] Regression case maintained.
- [ ] `flutter test` passes.
- [ ] `flutter build windows --release` passes and Windows package is refreshed.
- [ ] `gitnexus detect-changes --scope all -r smart-assistant` is run.

## Bug Fix Record
| bug_id | Symptom | First Seen | bugfix_count | Status |
|---|---|---|---:|---|
| schedule-create-no-visible-result | Clicking create schedule has no visible result or data reflection | 2026-05-23 | 1 | open |

## Bug Trigger History
- Attempt 1: User reports "点击创建日程没有反应 没有任何数据体现". Initial diagnosis indicates missing feedback/error handling, possible storage initialization race, and stale cached home page content.
