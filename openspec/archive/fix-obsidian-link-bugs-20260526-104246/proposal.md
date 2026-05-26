# fix-obsidian-link-bugs

## 需求澄清摘要
修复两个 Bug: (1) URI 中的 & 被 cmd 解释为命令分隔符导致启动失败; (2) DB 写入 Value(null) 类型推断可能失败

## 为什么
用户反馈: 绑定后数据未保存, 点击提示未安装 Obsidian

## 影响面
未提供影响面；实施前需要用 context plan / impact 补齐。

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 验收
- [ ] 完成本次最小改动
- [ ] 回归测试最近一次运行通过
