# 设计：windows-desktop-build

## 当前状态
项目已包含 Windows 桌面平台支持代码（`windows/` 目录存在，含 CMakeLists.txt、runner/ 等），
Flutter 版本 3.41.9，支持 `flutter build windows`。
项目依赖：flutter_bloc、supabase_flutter、table_calendar、speech_to_text、flutter_local_notifications 等。

## 方案
执行标准 Flutter Windows Release 构建：
```
flutter build windows --release
```
产物位置：`build/windows/x64/runner/Release/`

构建产物包括：
- `smart_assistant.exe`：主可执行文件
- `*.dll`：Flutter 引擎和插件所需动态库
- `data/` 目录：Flutter assets 和字体资源

**分发方式选择：**
- 方案 A（直接分发目录）：将 `Release/` 目录整体打包为 zip 提供给用户，双击 exe 即可运行
- 方案 B（NSIS/Inno Setup 安装包）：制作带安装向导的 .exe 安装包，需额外工具
- **默认采用方案 A**（直接分发目录），无需额外安装工具，简单快速

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：ADDED（首次建立 Windows 构建规范）
- 证明不是重复能力：openspec/specs/ 为空，没有任何既有规范，确认新增

## 历史 BugFixSpecs 命中
- 命中文件：无
- 历史根因：无
- 本次防重蹈覆辙措施：无

## Bug 根因分析
无（非 bugfix change）

## 回归测试方案
- 用例文件：`regression-tests/cases/windows-desktop-build.md`
- 批量测试接口 / 命令：`flutter build windows --release`（本地构建验证）
- 入参来源：无需入参，只需构建命令通过
- 期望出参：`build/windows/x64/runner/Release/smart_assistant.exe` 文件存在
- 断言规则：文件存在 + 文件大小 > 0

## 回滚方案
删除 `build/windows/` 目录即可，不影响任何源码。
