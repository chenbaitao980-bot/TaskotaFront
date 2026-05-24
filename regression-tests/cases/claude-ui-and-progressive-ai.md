# Regression Cases: claude-ui-and-progressive-ai

## Batch Test Endpoint
- command_or_url: `flutter analyze --no-fatal-infos`; `flutter test`
- auth: local authenticated or existing test setup
- env: Flutter Windows development environment

## Cases
| case_id | target | input summary | expected key output | assertion | source | status |
|---|---|---|---|---|---|---|
| claude-theme-analyze | Claude dark theme compiles | run analyzer after theme/page updates | no analyzer errors | exit_code=0 with no fatal infos | spec | pass |
| ai-progressive-question | Progressive AI asks one key question | enter a goal in AI chat | AI asks one focused follow-up | manual/ui contains one question | spec | pending |
| ai-suggestion-time-priority | Time-context suggestions match prompt | AI asks daily/weekly time availability | time duration chips render | manual/ui chips | bugfix | pending |
| ai-suggestion-goal-priority | Goal-context suggestions match prompt | AI asks desired level and mentions time expectation | goal/level chips render, not duration chips | manual/ui chips | bugfix | pending |
| home-today-overview-two-stats | Home overview shows only two stats | open Home today overview | pending and completed only | manual/ui text absent | spec | pending |

## Notes
- The automated gate verifies no compile regressions.
- Suggestion cases protect `ai-suggestion-mismatch` from broad keyword matching regressions.
