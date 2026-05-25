# Delta: package-windows-release-20260525-2

## 与主规范关系
本次变更不新增业务能力，只规范化 Windows release 交付流程和产物验证记录。

## 命中的主规范
- Capability：Windows release 打包交付
- Requirement：当前 Flutter Windows 应用必须能生成可运行的 release 压缩包。
- Scenario：用户要求打包时，系统应生成 release 目录、zip 压缩包，并验证必要运行文件存在。

## 变更类型
MODIFIED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 否 |
| 关系判断 | 交付流程记录 |
| 其他 active change 撞车 | 无直接冲突 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否 |
| 归档完整性 | 待实施后检查 |

## 新规则
### Requirement: Windows release 打包交付
当用户要求按照规范打包 Windows 版本时，必须基于当前代码生成 release 产物，并记录构建、测试、压缩包结构验证结果。

#### Scenario: 生成 Windows release 压缩包
- Given 当前 Flutter 项目可以构建 Windows release
- When 执行规范打包流程
- Then 应生成 `smart_assistant_windows_release.zip`
- And 压缩包内应包含 `smart_assistant.exe`、`flutter_windows.dll`、插件 dll 和 `data` 目录
- And 应记录回归测试 run，说明本次打包通过

## 改动明细
- 文件：`smart_assistant_windows_release/`
- 文件：`smart_assistant_windows_release.zip`
- 文件：`regression-tests/cases/package-windows-release-20260525-2.md`
- 文件：`regression-tests/runs/package-windows-release-20260525-2.json`
