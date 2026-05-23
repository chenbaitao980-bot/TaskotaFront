# Regression Run: windows-desktop-build

- run_time: 2026-05-23 14:20
- endpoint_or_command: `flutter build windows --release`
- status: pass

| case_id | 入参摘要 | 期望关键出参 | 实际关键出参 | 断言结果 | 失败原因 |
|---------|---------|------------|------------|---------|---------|
| WIN-001 | flutter build windows --release | exit_code=0 | exit_code=0, 99.9s | pass | - |
| WIN-002 | 检查 exe 产物 | smart_assistant.exe 存在 | 文件存在 | pass | - |
| WIN-003 | 检查 DLL | flutter_windows.dll 存在 | 文件存在 | pass | - |
| WIN-004 | 检查 ZIP | smart_assistant_windows.zip > 5MB | 存在 | pass | - |

## 历史构建记录
- 第一次构建失败：flutter_local_notifications_windows 需要 ATL（atlbase.h），已注释该依赖
- 第二次构建成功（5/23 上午）：产物 13MB ZIP
- 第三次构建成功（5/23 下午）：确认持续可用
