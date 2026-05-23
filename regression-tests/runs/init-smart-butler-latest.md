# Regression Run: init-smart-butler

- run_time: 2026-05-23T10:30:00+08:00
- endpoint_or_command: flutter analyze + flutter build windows --release
- status: pass

| case_id | 入参摘要 | 期望关键出参 | 实际关键出参 | 断言结果 | 失败原因 |
|---------|---------|-------------|-------------|---------|---------|
| BUTLER-001 | flutter analyze | no errors | 0 errors (10 info/warning) | pass | - |
| BUTLER-002 | 检查 lib/models/ | schedule.dart 等存在 | 全部存在 | pass | - |
| BUTLER-003 | 检查 lib/presentation/blocs/ | auth/, schedule/, task/, ai_chat/ 存在 | 全部存在 | pass | - |
| BUTLER-004 | 检查 lib/core/router/app_router.dart | 文件存在 | 存在 | pass | - |
| BUTLER-005 | flutter build windows --release | exit_code=0 | exit_code=0, exe 已生成 | pass | - |
