---
name: code-gate
description: 改代码前强制门禁：graphify query + codegraph_explore → impact → callers，缺一步硬拒绝
---
# Code Gate — 改代码强制门禁（内联版）

## 触发规则
**每次 edit_file / multi_edit / write_file 前自动触发**。不等用户提醒。

## 门禁四步（严格顺序，无豁免）

### ⚠️ 第一步：追溯本轮调用证据
在回复中输出**实际调用过的工具清单**（基于本轮会话追溯，非注册状态）：

```
[图谱工具] 可用工具检查:
  codegraph MCP:
    - codegraph_impact:   ❌（本轮从未调用过）  ← 填实际证据
    - codegraph_explore:  ❌（本轮从未调用过）
    - codegraph_callers:  ❌（本轮从未调用过）
  graphify index/query:   ❌
```

**任一 ❌ → 硬拒绝修改代码。**

### 第二步：graphify query
```bash
run_command("npx -y @nodesify/graphify query "要改的功能关键词"")
```
即使"概念已经很清楚了"也要跑。query 结果输出到思考中即可。

### 第三步：codegraph 三件套
1. `codegraph_explore(符号名)` → 批量源码（替代 read_file）
2. `codegraph_impact(符号名)` → 影响半径，HIGH/CRITICAL 先告知用户
3. `codegraph_callers(符号名)` → d=1 调用方同步检查

### 第四步：改后同步
```bash
run_command("npx -y @nodesify/graphify update .")
```

## 禁止
- 禁止用 `read_file` / `search_content` 替代 codegraph 语义分析
- 禁止跳过 impact 分析，无论改动多小
- 禁止改完不跑 graphify update
- 禁止自检时把工具注册状态当作调用证据

## Why
违规历史：2026-06-05 认为"改动太小不用走流程"跳过三步 → 引入 bug；2026-06-10 自检标记 ✅ 但实际从未调用 → 门禁形同虚设。追溯调用证据是唯一可靠的硬门禁。
