# create-windows-pack-script

## 需求澄清摘要
为 Flutter Windows 项目创建一键打包 bat 脚本，每次发布 Win10 桌面版时一键构建并输出到 `smart_assistant_windows_release/`，版本号自动从 `pubspec.yaml` 读取。

## 为什么
目前每次打包需要手动执行 `flutter build windows` 然后手动复制文件到 `smart_assistant_windows_release/`，效率低且版本号容易忘记更新。一个一键脚本可以规范发布流程、减少人为错误。

## 影响面
- 新增一个 `build_windows.bat` 脚本文件
- 不修改任何现有代码
- 不影响现有打包流程

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability（新增 DevOps 工具能力）
- 推荐动作：ADDED

## 改动范围
- 新增 `build_windows.bat`：一键打包脚本

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/create-windows-pack-script.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
