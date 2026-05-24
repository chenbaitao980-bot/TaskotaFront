# Regression Run: mvp-core-features

- run_time: 2026-05-24
- endpoint_or_command: flutter analyze + flutter build windows --release
- status: pass

| case_id | 入参摘要 | 期望关键出参 | 实际关键出参 | 断言结果 | 失败原因 |
|---------|---------|-------------|-------------|---------|---------|
| MVP-001 | flutter analyze | 0 errors | 0 errors (6 info) | pass | - |
| MVP-002 | flutter build windows --release | exit_code=0 | exit_code=0, built `build\windows\x64\runner\Release\smart_assistant.exe` | pass | - |
| MVP-003 | 手动验证：首页按钮 | 弹出对话框/跳转 | 待手动验证 | pending | - |
| MVP-004 | 手动验证：日历切换 | 周/月视图切换 | 待手动验证 | pending | - |
| MVP-005 | 手动验证：日历CRUD | 增删改日程 | 待手动验证 | pending | - |
| MVP-006 | 手动验证：AI对话 | DeepSeek非空回复 | 待手动验证 | pending | - |
| MVP-007 | 手动验证：登录注册 | 跳转首页 | 待手动验证 | pending | - |
| MVP-008 | 手动验证：未登录拦截 | 展示登录页 | 待手动验证 | pending | - |

## GitNexus detect-changes
- 17 files, 41 symbols changed
- 2 affected processes (Build)
- Risk: medium, scope: expected
