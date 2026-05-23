# Regression Cases: windows-desktop-build

## Batch Test Endpoint
- command_or_url: `flutter build windows --release`（在项目根目录执行）
- auth: 无
- env: 本地 Windows 开发机，需要 Flutter 3.41.9+ 和 Visual Studio 2022 BuildTools（含 C++ 工具链）

## Cases
| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---------|------|---------|-----------------|------|------|------|
| WIN-001 | 构建命令正常退出 | flutter build windows --release | exit_code=0 | equals | spec | pass |
| WIN-002 | 主可执行文件存在 | 构建完成后检查产物路径 | build/windows/x64/runner/Release/smart_assistant.exe 存在 | exists | spec | pass |
| WIN-003 | DLL 完整性 | 检查 Release/ 目录 | flutter_windows.dll 存在 | exists | spec | pass |
| WIN-004 | ZIP 分发包生成 | 打包 Release 目录 | smart_assistant_windows.zip 存在，大小 > 5MB | exists+size | spec | pass |

## Notes
- 本次构建发现 flutter_local_notifications_windows 依赖 ATL 头文件（atlbase.h），VS BuildTools 中 ATL 组件未安装导致编译失败
- 处理方式：该插件在代码中未实际使用，已在 pubspec.yaml 中注释掉
- 如后续需要恢复通知功能，需安装 VS 2022 ATL 组件后重新构建
