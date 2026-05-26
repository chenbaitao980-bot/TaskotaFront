# 设计：fix-obsidian-uri-backslash

## 需求澄清依据
修复: Process.run 传参数中的双引号被 Windows 转义为反斜杠，导致 URI 变成 \obsidian://...；切换到 rundll32 url.dll FileProtocolHandler 直接调用 ShellExecute

## 方案
执行本次最小改动，不扩大范围。

## 回归测试
- 用例文件：`regression-tests/cases/fix-obsidian-uri-backslash.md`
- 运行记录：`regression-tests/runs/fix-obsidian-uri-backslash.json`
