# 设计：fix-obsidian-link-bugs

## 需求澄清依据
修复两个 Bug: (1) URI 中的 & 被 cmd 解释为命令分隔符导致启动失败; (2) DB 写入 Value(null) 类型推断可能失败

## 方案
执行本次最小改动，不扩大范围。

## 回归测试
- 用例文件：`regression-tests/cases/fix-obsidian-link-bugs.md`
- 运行记录：`regression-tests/runs/fix-obsidian-link-bugs.json`
