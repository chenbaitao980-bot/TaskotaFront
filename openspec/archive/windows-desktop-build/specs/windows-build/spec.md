# Delta: windows-desktop-build

## 与主规范关系
New Capability（首次建立 Windows 桌面打包流程）

## 命中的主规范
- Capability：无（specs/ 目录为空）
- Requirement：无
- Scenario：无

## 变更类型
ADDED（新增 Windows 桌面构建能力）

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无 |
| 关系判断 | New Capability |
| 其他 active change 撞车 | 无（init-smart-butler 为项目初始化 change，不冲突） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是；openspec/specs/ 为空，无任何既有规范覆盖构建能力 |
| 归档完整性 | ✅ |

## 原规则
无

## 新规则
### Requirement: Windows 桌面应用构建
项目 SHALL 支持通过 `flutter build windows --release` 构建 Windows 可执行应用。

#### Scenario: 用户请求打包 Windows 桌面应用
- WHEN 用户请求将 Flutter 项目打包为 Windows 桌面应用
- THEN 执行 `flutter build windows --release`
- AND 产物位于 `build/windows/x64/runner/Release/`
- AND 提供可直接分发的目录（含 exe + dll + data/）

## 改动明细
- 文件：无源码修改
- 操作：执行构建命令，生成产物
- 产物路径：`build/windows/x64/runner/Release/smart_assistant.exe`
