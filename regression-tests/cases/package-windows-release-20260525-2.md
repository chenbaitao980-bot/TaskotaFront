# 回归用例：package-windows-release-20260525-2

## 背景
用户要求按规范重新打包当前 Flutter Windows 应用，需要确保 release 构建、压缩包生成和产物结构验证都通过。

## 验证步骤
1. 执行 `flutter pub get`。
2. 执行 `flutter analyze --no-fatal-infos`。
3. 执行 `flutter test`。
4. 执行 `flutter build windows --release`。
5. 将 `build/windows/x64/runner/Release` 复制为 `smart_assistant_windows_release`。
6. 生成 `smart_assistant_windows_release.zip`。
7. 解压压缩包并检查关键文件。

## 通过标准
- `smart_assistant_windows_release.zip` 成功生成。
- 解压后包含 `smart_assistant.exe`。
- 解压后包含 `flutter_windows.dll`。
- 解压后包含插件 dll：`app_links_plugin.dll`、`speech_to_text_windows_plugin.dll`、`url_launcher_windows_plugin.dll`。
- 解压后包含 `data/app.so` 和 `data/flutter_assets`。
