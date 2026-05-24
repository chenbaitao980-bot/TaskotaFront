# Regression Run: claude-ui-and-progressive-ai

- run_time: 2026-05-24
- endpoint_or_command: `flutter analyze --no-fatal-infos`; `flutter test`; `flutter build windows --release`
- status: success with analyze infos

| case_id | input summary | expected key output | actual key output | assertion result | failure reason |
|---|---|---|---|---|---|
| automated-analyze | static analysis | no analyzer errors | 4 info issues, no errors | pass | - |
| automated-test | widget smoke test | tests pass | 1 test passed | pass | - |
| automated-build | Windows release build | exit_code=0 | built `build\windows\x64\runner\Release\smart_assistant.exe` | pass | - |
| claude-theme-analyze | theme/page compile gate | no analyzer errors | no analyzer errors, 4 infos | pass | - |
| ai-progressive-question | manual AI path | one focused follow-up question | pending manual check | pending | manual UI required |
| ai-suggestion-time-priority | manual AI path | duration chips for availability question | pending manual check | pending | manual UI required |
| ai-suggestion-goal-priority | manual AI path | goal/level chips for goal question | pending manual check | pending | manual UI required |
| home-today-overview-two-stats | manual Home path | only pending and completed stats | pending manual check | pending | manual UI required |
