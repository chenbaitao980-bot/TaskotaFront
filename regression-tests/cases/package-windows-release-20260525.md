# package-windows-release-20260525 回归用例

## 目标
验证 Windows 桌面发布包按规范完成全量构建、复制和压缩。

## 步骤
1. 执行 `flutter clean` 清理缓存。
2. 执行 `flutter pub get` 恢复依赖。
3. 执行 `flutter build windows --release` 生成 Release 产物。
4. 将 `build/windows/x64/runner/Release` 复制到 `smart_assistant_windows_release`。
5. 将发布目录压缩为 `smart_assistant_windows_release.zip`。
6. 解压 ZIP，确认存在 `smart_assistant.exe` 和 `flutter_windows.dll`。

## 预期
- Release 构建命令成功。
- ZIP 文件存在。
- ZIP 解压后可以看到应用主程序和 Flutter 运行库。
