# Regression Run: windows-desktop-build

- run_time: 2026-05-24 10:39:01 +08:00
- endpoint_or_command: `flutter clean`; `flutter build windows --release`; copy `build/windows/x64/runner/Release` to `smart_assistant_windows`; compress to `smart_assistant_windows.zip`
- status: success

| case_id | 入参摘要 | 期望关键出参 | 实际关键出参 | 断言结果 | 失败原因 |
|---|---|---|---|---|---|
| WIN-001 | `flutter clean` | exit_code=0 | exit_code=0 | pass | - |
| WIN-002 | `flutter build windows --release` | exit_code=0 | exit_code=0; built `build\windows\x64\runner\Release\smart_assistant.exe` | pass | - |
| WIN-003 | Release file check | `smart_assistant.exe` and `flutter_windows.dll` exist | exe exists; `flutter_windows.dll` exists | pass | - |
| WIN-004 | ZIP package | `smart_assistant_windows.zip` exists and size > 5MB | zip exists; size 13,294,715 bytes | pass | - |
| WIN-005 | Dist folder shape | no duplicate nested dist folder | `smart_assistant_windows\smart_assistant_windows` removed/absent | pass | - |

## GitNexus
- command: `gitnexus detect-changes --scope all -r smart-assistant`
- status: success
- result: CRITICAL, 25 files / 145 symbols / 58 affected processes
- note: result reflects the existing dirty worktree and prior code changes, not only this packaging operation.
