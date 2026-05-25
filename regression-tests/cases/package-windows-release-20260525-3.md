# 回归用例：package-windows-release-20260525-3

## 背景
用户要求按照项目规范重新打包当前 Flutter Windows 应用。发布包需要包含当前工作区的日历交互改动，并生成可直接分发的 Windows release 压缩包。

## 验证步骤
1. 执行 `flutter pub get`。
2. 执行 `flutter analyze --no-fatal-infos`。
3. 执行 `flutter test`。
4. 执行 `flutter clean`。
5. 执行 `flutter build windows --release`。
6. 将 `build/windows/x64/runner/Release` 复制为 `smart_assistant_windows_release`。
7. 将发布目录压缩为 `smart_assistant_windows_release.zip`。
8. 解压压缩包并检查运行所需文件。

## 通过标准
- `smart_assistant_windows_release.zip` 存在且大小合理。
- 解压后包含 `smart_assistant.exe`。
- 解压后包含 `flutter_windows.dll`。
- 解压后包含插件 DLL：`app_links_plugin.dll`、`speech_to_text_windows_plugin.dll`、`url_launcher_windows_plugin.dll`。
- 解压后包含 `data/app.so` 和 `data/flutter_assets`。
