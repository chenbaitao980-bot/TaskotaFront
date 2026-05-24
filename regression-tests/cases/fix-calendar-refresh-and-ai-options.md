# Regression Cases: fix-calendar-refresh-and-ai-options

## Batch Test Endpoint
- command_or_url: `flutter analyze`; `flutter test`
- auth: local authenticated or existing test setup
- env: Flutter Windows development environment

## Cases
| case_id | target | input summary | expected key output | assertion | source | status |
|---|---|---|---|---|---|---|
| calendar-home-create-refresh | Home-created schedule appears in Calendar week view | create schedule on Home, open Calendar tab | new schedule is visible without toggling month/week | manual/ui contains title | bugfix | pending |
| ai-explicit-options-clickable | AI explicit options become chips | AI response includes `[OPTIONS: zero | some | strong]` | raw marker hidden and three chips visible | manual/ui chips clickable | bugfix | pending |
| ai-option-click-sends | AI option click sends selected reply | click one rendered option chip | selected text is added as user message | manual/ui contains selected text | bugfix | pending |

## Notes
- Do not store personal schedule details beyond minimal test summaries.
- The automated gate covers compile/test regressions; the two UI interaction bugs require manual verification in the running app.
