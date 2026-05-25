# 任务：package-windows-release-20260525-3

## 实施
- [ ] 1. 确认当前打包规范和工作区范围，保留现有日历交互改动并基于当前代码打包。
- [ ] 2. 按规范递增 `pubspec.yaml` 中的版本号，避免发布包覆盖时无法区分版本。
- [ ] 3. 执行 `flutter pub get`、`flutter analyze --no-fatal-infos` 和 `flutter test`，记录验证结果。
- [ ] 4. 执行 `flutter clean` 后运行 `flutter build windows --release`，确保 release 为全量构建产物。
- [ ] 5. 整理 `smart_assistant_windows_release` 目录并生成 `smart_assistant_windows_release.zip`。
- [ ] 6. 解压验证 ZIP 结构，并记录回归用例与本次 run。

## 验证
- [ ] `smart_assistant_windows_release.zip` 存在且大小合理。
- [ ] 解压后包含 `smart_assistant.exe` 和 `flutter_windows.dll`。
- [ ] 解压后包含 `app_links_plugin.dll`、`speech_to_text_windows_plugin.dll`、`url_launcher_windows_plugin.dll`。
- [ ] 解压后包含 `data/app.so` 和 `data/flutter_assets`。
- [ ] 用户已提前确认：打包成功后可直接归档。
