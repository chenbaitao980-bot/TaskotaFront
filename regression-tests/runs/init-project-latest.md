# Regression Run: init-project

- run_time: 2026-05-23T10:30:00+08:00
- endpoint_or_command: flutter analyze
- status: pass

| case_id | 入参摘要 | 期望关键出参 | 实际关键出参 | 断言结果 | 失败原因 |
|---------|---------|-------------|-------------|---------|---------|
| INIT-001 | flutter analyze | no errors | 10 info/warning, 0 errors | pass | - |
| INIT-002 | 检查 lib/ 目录 | core/, models/, presentation/, services/ 存在 | 全部存在 | pass | - |
| INIT-003 | flutter pub get | exit_code=0 | exit_code=0 | pass | - |
