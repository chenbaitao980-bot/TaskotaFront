# Regression Cases: schedule-status-checkbox-control

## Batch Test Endpoint
- command_or_url: `flutter analyze --no-fatal-infos`; `flutter test`
- auth: local authenticated or existing test setup
- env: Flutter Windows development environment

## Cases
| case_id | target | input summary | expected key output | assertion | source | status |
|---|---|---|---|---|---|---|
| schedule-checkbox-home | Home schedule checkbox toggles status | tap checkbox on a Home schedule card | checkbox checked/unchecked and schedule status persists | manual/ui status | spec | pending |
| schedule-checkbox-calendar-week | Calendar week event checkbox toggles status | tap compact checkbox on a week event block | event status changes without leaving week view | manual/ui status | spec | pending |
| schedule-checkbox-calendar-list | Calendar event list checkbox toggles status | tap checkbox in selected-day event list | event status changes and remains after reload | manual/ui status | spec | pending |

## Notes
- Automated gates cover compile/test regressions.
- Manual UI cases avoid storing personal schedule details.
