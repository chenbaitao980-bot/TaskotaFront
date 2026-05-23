# 任务：windows-desktop-build

## 实施
- [x] 1. 在项目根执行 `flutter build windows --release`
- [x] 2. 验证产物存在：`build/windows/x64/runner/Release/smart_assistant.exe`
- [x] 3. 将 Release 目录整体打包为 zip 方便分发
- [x] 4. 维护回归测试用例

## 验证
- [x] 历史 BugFixSpecs 命中的防复发检查项已执行或确认无命中（本次无命中）
- [x] bugfix_count 已按本轮触发情况更新（本次无 bugfix）
- [x] 已维护本 change 的回归测试用例 `regression-tests/cases/windows-desktop-build.md`
- [x] `flutter build windows --release` 退出码为 0
- [x] `build/windows/x64/runner/Release/smart_assistant.exe` 文件存在
- [x] `gitnexus detect-changes --scope all`（可选，本次无源码变更，跳过）
