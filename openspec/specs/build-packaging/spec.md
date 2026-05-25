# Spec: build-packaging

## 概述
SmartAssistant Windows 发布包的构建与打包规范。

## 构建命令
```powershell
# 前置：设置环境变量（沙箱环境缺失）
$env:ProgramFiles = "C:\Program Files"
${env:ProgramFiles(x86)} = "C:\Program Files (x86)"

# 完整构建
flutter build windows --release
```

## 已知问题：cmake INSTALL 步骤失败

### 现象
`flutter build windows --release` 在沙箱环境中编译通过（生成 `build/windows/app.so` 和 `build/windows/x64/runner/Release/smart_assistant.exe`），但 cmake INSTALL 步骤报错：

```
error MSB3073: 命令"setlocal ... cmake.exe -DBUILD_TYPE=Release -P cmake_install.cmake"已退出，代码为 1
```

### 根因
沙箱/纯 CLI 环境缺少 Windows 桌面环境的部分环境变量，`cmake_install.cmake` 中的 `setlocal` 命令无法正常执行。

### 影响
INSTALL 步骤负责拷贝以下文件到 `Release` 目录：
- `build/flutter_assets/` → `Release/data/flutter_assets/`
- `build/windows/app.so` → `Release/data/app.so`

INSTALL 失败后 Release 目录**缺少 app.so（AOT 编译的 Dart 代码）和 flutter_assets**，导致打包产物无法运行新代码。

### 手动修复步骤
```powershell
# 创建目标目录
mkdir -p build/windows/x64/runner/Release/data/flutter_assets

# 拷贝 flutter_assets
cp -r build/flutter_assets/* build/windows/x64/runner/Release/data/flutter_assets/

# 拷贝 app.so（AOT 编译的 Dart 代码，核心）
cp build/windows/app.so build/windows/x64/runner/Release/data/app.so
```

### 产物验证
最终 `Release` 目录结构应为：
```
Release/
├── smart_assistant.exe          # C++ runner (90KB)
├── app_links_plugin.dll         # 插件 DLL
├── flutter_windows.dll          # Flutter 引擎 (20MB)
├── speech_to_text_windows_plugin.dll
├── url_launcher_windows_plugin.dll
└── data/
    ├── icudtl.dat               # ICU 数据 (862KB)
    ├── app.so                   # AOT 编译 Dart 代码 (8MB) ← 最容易遗漏
    └── flutter_assets/
        ├── AssetManifest.bin
        ├── FontManifest.json
        ├── NOTICES.Z
        └── fonts/
```

### 打包命令
```powershell
cd build/windows/x64/runner/Release
zip -r ../../../../../../smart_assistant_windows_release.zip . -x "*.pdb"
```

### 版本管理
每次打包前递增 `pubspec.yaml` 中的 `version` 字段（如 `1.0.0+1` → `1.0.0+2`），避免覆盖安装时无法区分版本。

## 回归测试
每次打包后应在真机上验证：
1. 应用能正常启动
2. 当前 change 的功能已包含在产物中
