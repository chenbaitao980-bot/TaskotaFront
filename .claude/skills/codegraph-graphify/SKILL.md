---
name: codegraph-graphify
description: "Use when the user asks about code structure, dependencies, or concept relationships in this project. Examples: \"Who calls X?\", \"What breaks if I change Y?\", \"How does auth connect to the task module?\", \"Help me understand [feature]\". Also activates automatically before any code edit to run impact analysis. Saves tokens by querying pre-indexed graphs instead of reading raw files."
---

# codegraph + graphify: 代码图谱工作流

## 核心原则

**图谱优先，文件兜底。** 所有代码理解和修改任务先查图谱，只有图谱返回不足时才 Read 源文件。

---

## 工具速查

### codegraph MCP（结构/AST 层）
| 工具 | 何时用 |
|------|-------|
| `codegraph_search(name)` | 找符号位置 |
| `codegraph_callers(symbol)` | 谁调用了它 |
| `codegraph_callees(symbol)` | 它调用了谁 |
| `codegraph_impact(symbol)` | 变更影响半径 |
| `codegraph_context(task)` | 拉取任务相关上下文 |
| `codegraph_trace(symbol)` | 完整调用路径 |
| `codegraph_node(id)` | 单符号详情+源码片段 |
| `codegraph_files` | 文件结构（替代 ls/Glob） |

### graphify MCP（语义/概念层）
| 工具 | 何时用 |
|------|-------|
| `query_graph("自然语言")` | 概念查询、跨模块关联 |
| `get_node(name)` | 节点详情 |
| `get_neighbors(name)` | 相邻节点 |
| `shortest_path(a, b)` | 两个概念/模块的连接路径 |

---

## 工作流 A：理解代码

```
判断问题类型：
├── 结构性（谁调用、依赖什么）
│     → codegraph_search → codegraph_callers/callees/trace
└── 语义性（X和Y关联、理解某功能、跨模块）
      → query_graph → get_neighbors → codegraph_context（细化）

不够时才 Read 图谱返回的具体文件和行号。
```

**决策速查：**
- "谁调用了 X" → `codegraph_callers`
- "X 依赖什么" → `codegraph_callees`
- "A 和 B 怎么连接" → `graphify shortest_path(A, B)`
- "理解[功能]" → `query_graph` → 再 `codegraph_context`
- "某功能在哪里" → `codegraph_search`

---

## 工作流 B：改代码（改前分析）

```
步骤 1 — 影响分析
  codegraph_impact(目标符号, direction="upstream")
  ├── d=1 (WILL BREAK)：必须同步修改
  ├── d=2 (LIKELY AFFECTED)：需要检查
  └── HIGH/CRITICAL → 先告知用户再继续

步骤 2 — 精准拉取上下文
  codegraph_context("修改任务描述")
  → 只 Read 图谱定位到的文件和行，不全量读

步骤 3 — 确认调用方
  codegraph_callers(符号)
  → d=1 调用方必须同步检查和更新

步骤 4 — 执行修改
  → 仅修改 impact 返回的 d=1 符号范围内的文件

步骤 5 — 验证（可选）
  codegraph sync → codegraph_impact 再次确认
```

---

## 索引检查（首次使用）

```
codegraph 未初始化？
  → Bash: npx @colbymchenry/codegraph init
  → Bash: codegraph serve --mcp（后台启动）

graphify 未构建？
  → 检查项目根目录是否有 graph.json
  → 没有则运行: graphify .（或 python -m graphify .）
```

---

## 风险等级

| 影响范围 | 风险 | 操作 |
|---------|------|------|
| d=1 < 5 个符号 | LOW | 直接改 |
| d=1 5-15 个 | MEDIUM | 列出调用方让用户确认 |
| d=1 > 15 个 | HIGH | 必须告知，等用户确认 |
| 核心路径（状态管理/数据持久化） | CRITICAL | 停下来告知 |

---

## 示例

**问："TaskBloc 的上游调用链"**
```
1. codegraph_callers("TaskBloc")
   → 直接返回调用方列表，无需读任何 .dart 文件
```

**问："认证和任务模块怎么关联"**
```
1. query_graph("authentication task module relationship")
   → 返回概念节点和语义边
2. codegraph_trace("关联符号") → 结构验证
```

**改 TaskEvent 之前：**
```
1. codegraph_impact("TaskEvent", direction="upstream")
   → d=1: TaskBloc, TaskCreateSheet, CalendarPage ... (HIGH)
2. 告知用户影响范围，确认后再改
```
