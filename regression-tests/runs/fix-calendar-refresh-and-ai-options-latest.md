# Regression Run: fix-calendar-refresh-and-ai-options

- run_time: 2026-05-24
- endpoint_or_command: `flutter analyze`; `flutter analyze --no-fatal-infos`; `flutter test`
- status: success with analyze infos

| case_id | input summary | expected key output | actual key output | assertion result | failure reason |
|---|---|---|---|---|---|
| automated-analyze | static analysis | no analyzer errors | 4 info issues, no errors | pass | - |
| automated-test | widget smoke test | tests pass | 1 test passed | pass | - |
| calendar-home-create-refresh | manual UI path | schedule visible in Calendar week view without toggling | pending manual check | pending | manual UI required |
| ai-explicit-options-clickable | manual AI response path | chips visible, raw marker hidden | pending manual check | pending | manual UI required |
| ai-option-click-sends | manual chip click | selected text sent as user message | pending manual check | pending | manual UI required |
