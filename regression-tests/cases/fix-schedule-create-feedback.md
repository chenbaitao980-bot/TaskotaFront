# Regression Cases: fix-schedule-create-feedback

## Batch Test Endpoint
- command_or_url: `flutter test`; `flutter build windows --release`
- auth: any authenticated or local-auth state with access to Home/Calendar
- env: Flutter Windows development environment

## Cases
| case_id | Target | Input Summary | Expected Key Output | Assertion | Source | Status |
|---|---|---|---|---|---|---|
| home-create-schedule-visible | Home create schedule | title, today start/end time, priority | success message and today's schedule item visible | manual/ui contains new title | bugfix | pending |
| calendar-create-schedule-visible | Calendar create schedule | selected day, title, start/end time | success message and event appears for selected day | manual/ui contains new event | spec | pending |
| schedule-create-error-visible | Save failure handling | storage or notification failure | clear error SnackBar | manual/ui contains failure message | bugfix | pending |

## Notes
- Do not store personal schedule content beyond minimal test summaries.
- Automated widget coverage can be added later around `CreateScheduleDialog` and local storage.
