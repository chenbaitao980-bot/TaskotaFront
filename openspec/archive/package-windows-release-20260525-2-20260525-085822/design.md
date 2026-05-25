# 设计：package-windows-release-20260525-2

## 当前状态
项目是 Flutter Windows 桌面应用。上一次打包产物已存在，但当前工作区又包含新的 AI 计划表相关修改，因此需要基于当前代码重新构建 release，并覆盖生成最新交付包。

## 方案
1. 检查当前工作区，确认不会回滚用户已有改动。
2. 执行 `flutter pub get`，确保依赖完整。
3. 执行 `flutter analyze --no-fatal-infos` 和 `flutter test`，确认基础质量门禁通过。
4. 执行 `flutter build windows --release`。
5. 将 `build/windows/x64/runner/Release` 复制为 `smart_assistant_windows_release`。
6. 生成 `smart_assistant_windows_release.zip`。
7. 解压检查压缩包结构，确认 `smart_assistant.exe`、`flutter_windows.dll`、插件 dll 和 `data` 目录存在。
8. 记录回归测试 run 和产物摘要。

## 业务规则处理
- 原 Requirement / Scenario：无。
- 本次处理方式：不改变业务规则，只更新交付产物。

## 回归测试方案
- 用例文件：`regression-tests/cases/package-windows-release-20260525-2.md`。
- 命令验证：`flutter analyze --no-fatal-infos`、`flutter test`、`flutter build windows --release`。
- 产物验证：检查 zip 解压后的 exe、dll、data 目录。

## 回滚方案
删除本次新生成的 `smart_assistant_windows_release`、`smart_assistant_windows_release.zip` 和本 change 相关回归记录即可；不回滚任何用户已有源码改动。
