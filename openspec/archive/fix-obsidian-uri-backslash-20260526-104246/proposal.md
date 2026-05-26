# fix-obsidian-uri-backslash

## 需求澄清摘要
修复: Process.run 传参数中的双引号被 Windows 转义为反斜杠，导致 URI 变成 \obsidian://...；切换到 rundll32 url.dll FileProtocolHandler 直接调用 ShellExecute

## 为什么
用户截图显示 Windows 错误 \obsidian://open?vault=obsidian，前面多出反斜杠

## 影响面
未提供影响面；实施前需要用 context plan / impact 补齐。

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 验收
- [ ] 完成本次最小改动
- [ ] 回归测试最近一次运行通过
