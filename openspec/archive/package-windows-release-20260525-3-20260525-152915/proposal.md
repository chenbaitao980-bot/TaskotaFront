# package-windows-release-20260525-3

## 需求澄清摘要
已确认用户要求按照项目 Windows release 打包规范，基于当前工作区生成可交付 Windows 桌面发布包；目标用户是在 Windows 机器上运行智能助手应用的使用者；范围包括依赖获取、静态检查、测试、flutter clean、全量 release 构建、复制 Release 目录、生成 smart_assistant_windows_release.zip、解压结构验证和回归记录；不修改业务代码、不回滚当前工作区已有改动、不创建安装器；验收标准为 ZIP 存在且包含 smart_assistant.exe、flutter_windows.dll、插件 DLL、data/app.so 和 data/flutter_assets。

## 为什么
用户要求按既有规范重新打包当前 Flutter Windows 应用，确保最新日历交互改动进入可分发产物。

## 影响面


## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 改动范围
<AI 实施时填写>

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/package-windows-release-20260525-3.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
