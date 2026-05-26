# BugFix Log: task-tree-drag-reorder

## Bug Index

| bug_id | 现象 | 关联文件/函数 | bugfix_count | 当前状态 | 是否需沉淀 |
|---|---|---|---:|---|---|
| bug-003 | 同前 | 同前 | 1 | fixed | 否 |

## Bug Events

### bug-003 / 第 1 次修复

- 触发时间：2026-05-26 08:35
- 用户现象：拖到此处移为根任务拖放区不生效，子任务无法移回根级别
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：TBD
- 修复点：TBD
- 验证结果：pending
- 是否同一 bug：-

### bug-003 / 第 1 次修复

- 触发时间：2026-05-26 08:35
- 用户现象：TBD
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：taskRepository.moveTask 中 Value.absent() 在 Drift 中表示'跳过此列不更新'而非'设为NULL'。拖到根节点时 newParentId=null，parentId 列未被更新，任务保留旧的父级关系。修复：Value.absent() -> const Value(null)
- 修复点：TBD
- 验证结果：pending
- 是否同一 bug：是（计数自动递增）
