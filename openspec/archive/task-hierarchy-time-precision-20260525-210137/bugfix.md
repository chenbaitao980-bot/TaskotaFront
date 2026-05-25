# BugFix Log: task-hierarchy-time-precision

## Bug Index

| bug_id | 现象 | 关联文件/函数 | bugfix_count | 当前状态 | 是否需沉淀 |
|---|---|---|---:|---|---|
| subtask-delete-refresh | 同前 | lib/presentation/blocs/task_new/task_bloc.dart;lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart | 4 | fixed | 是 |

## Bug Events

### subtask-delete-refresh / 第 1 次修复

- 触发时间：2026-05-25 21:01
- 用户现象：删除子任务后全部子任务消失或刷新不及时
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：TBD
- 修复点：TBD
- 验证结果：pending
- 是否同一 bug：-

### subtask-delete-refresh / 第 4 次修复

- 触发时间：2026-05-25 21:01
- 用户现象：TBD
- 复现路径：TBD
- 触发条件：TBD
- 失败验证：TBD
- 本轮根因假设：TBD
- 最终根因：BLoC事件队列时序导致 LoadTasks 覆盖子树状态；编辑页返回后不触发刷新；DeleteSubTask 专用事件在一个handler内完成操作+刷新
- 修复点：TBD
- 验证结果：pending
- 是否同一 bug：是（计数自动递增）
