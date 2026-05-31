# 发布证据记录

日期：2026-05-31

## 已确认

- 当前仓库为 Flutter 项目。
- 存在 Windows release 目录：`smart_assistant_windows_release/`。
- 存在 Android release APK：`android_build_release/app-release.apk`。
- `pubspec.yaml` 当前版本：`1.0.0+3`。
- `android/app/build.gradle.kts` 当前 release 使用 debug 签名。
- `android/app/build.gradle.kts` 当前 applicationId 为 `com.example.smart_assistant`。
- `lib/core/constants/app_constants.dart` 当前包含 Supabase URL/anon key 和 DeepSeek API Key。

## 本次未改动

- 未改业务代码。
- 未更换 DeepSeek Key。
- 未改 Android 签名配置。
- 未改包名。
- 未重新构建 APK/Windows 包。

## 待补证据

- `flutter analyze` 完整输出。
- `flutter test` 完整输出。
- Windows release 实机启动截图或验收记录。
- Android 真机安装验收记录。
- 国内应用市场后台材料截图。
- 隐私政策和用户协议线上 URL。

