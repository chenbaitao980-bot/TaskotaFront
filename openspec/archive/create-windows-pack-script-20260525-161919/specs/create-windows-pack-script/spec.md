# Delta: create-windows-pack-script

## 与主规范关系
New Capability（DevOps 工具能力）

## 命中的主规范
- Capability: `create-windows-pack-script`
- Requirement: `一键打包 Windows 桌面版`
- Scenario: `开发者运行 build_windows.bat -> 自动读取版本号 -> flutter build windows --release -> 复制产物到 smart_assistant_windows_release/`

## 变更类型
ADDED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无 |
| 关系判断 | 新增 |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是 |
| 归档完整性 | ✅ |

## 原规则
无

## 新规则
一键打包脚本 `build_windows.bat` 位于项目根目录，执行以下流程：
1. 从 `pubspec.yaml` 自动读取版本号
2. 运行 `flutter build windows --release`
3. 将构建产物（exe、dll、data 目录）复制到 `smart_assistant_windows_release/`
4. 写入版本标识文件

## 改动明细
- 文件：`build_windows.bat`
- 位置：项目根目录
- 改前：无（新增文件）
- 改后：一键打包脚本
