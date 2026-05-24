# Regression Run: schedule-status-checkbox-control

- run_time: 2026-05-24
- endpoint_or_command: `flutter analyze --no-fatal-infos`; `flutter test`; `flutter build windows --release`
- status: success with analyze infos

| case_id | input summary | expected key output | actual key output | assertion result | failure reason |
|---|---|---|---|---|---|
| automated-analyze | static analysis | no analyzer errors | 4 info issues, no errors | pass | - |
| automated-test | widget smoke test | tests pass | 1 test passed | pass | - |
| automated-build | Windows release build | exit_code=0 | built `build\windows\x64\runner\Release\smart_assistant.exe` | pass | - |
| schedule-checkbox-home | manual UI path | Home checkbox toggles persisted status | pending manual check | pending | manual UI required |
| schedule-checkbox-calendar-week | manual UI path | week event checkbox toggles persisted status | pending manual check | pending | manual UI required |
| schedule-checkbox-calendar-list | manual UI path | event list checkbox toggles persisted status | pending manual check | pending | manual UI required |
