# BugFix Log: task-progress-calculation

## Bug Index

| bug_id | 现象 | 关联文件/函数 | bugfix_count | 当前状态 | 是否需沉淀 |
|---|---|---|---:|---|---|
| BUG-completed-tree-and-project-percent | 同前 | 同前 | 2 | fixed | 是 |

## Bug Events

### BUG-completed-tree-and-project-percent / 第 1 次修复

- 触发时间：2026-05-26 13:30
- 用户现象：已完成区未按任务父子关系展示；完成父任务和子任务后，项目完成度仍显示 40%，不符合按任务完成数统计的直觉
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：TBD
- 修复点：TBD
- 验证结果：pending
- 是否同一 bug：-

### BUG-completed-tree-and-project-percent / 第 2 次修复

- 触发时间：2026-05-26 13:33
- 用户现象：TBD
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：已完成分组直接 flat map 渲染 TaskCard，没有复用树结构；项目完成度把检查项数量作为全局分母，导致一个含多个检查项的未完成任务把 2/3 的任务完成度压成 40%
- 修复点：完成分组改为树形渲染；过滤分组里父节点缺失时子节点提升为根节点，避免漏显；项目完成度改为每个任务等权一次，检查项只影响该任务自身百分比
- 验证结果：pending
- 是否同一 bug：是（计数自动递增）
