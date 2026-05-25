# 设计：create-windows-pack-script

## 需求澄清依据
为 Flutter Windows 项目创建一键打包 `.bat` 脚本，自动构建并输出到 `smart_assistant_windows_release/` 目录，版本号自动从 `pubspec.yaml` 读取。

## 当前状态
- Windows 平台目录 `windows/` 已就绪
- `flutter build windows` 可以正常构建
- 现有 `smart_assistant_windows_release/` 目录手动维护，版本号不一致

## 方案

### 脚本逻辑（`build_windows.bat`）
1. 读取项目根目录 `pubspec.yaml`，用 findstr 提取 `version:` 行（格式：`version: 1.0.0+3`）
2. 执行 `flutter build windows --release` 构建 release 版本
3. 清空或创建 `smart_assistant_windows_release/` 目录
4. 从 `build/windows/runner/Release/` 复制以下文件到输出目录：
   - `smart_assistant.exe`
   - `flutter_windows.dll`
   - 各插件的 `.dll` 文件
   - `data/` 目录
5. （可选）在输出目录旁写一个 `version.txt` 记录当前版本号

### 文件结构
```
smart_assistant/
├── build_windows.bat          # 一键打包脚本（新增）
├── smart_assistant_windows_release/   # 输出目录（已有）
│   ├── smart_assistant.exe
│   ├── flutter_windows.dll
│   ├── *.dll
│   └── data/
```

## 业务规则处理
- 无现有业务规则变更，纯 DevOps 工具脚本

## 回归测试方案
- 运行 `build_windows.bat`，验证 `smart_assistant_windows_release/smart_assistant.exe` 存在且可执行
- 验证 exe 版本号与 `pubspec.yaml` 一致

## 回滚方案
删除 `build_windows.bat` 文件即可。
