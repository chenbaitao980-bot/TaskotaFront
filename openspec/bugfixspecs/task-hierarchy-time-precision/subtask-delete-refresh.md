# subtask-delete-refresh: TBD

## 适用范围
- Capability: task-hierarchy-time-precision
- 关联 change: task-hierarchy-time-precision
- 关联文件/函数: TBD

## 用户可见现象
TBD

## 根本原因
BLoC事件链时序问题：子任务的增删改操作与状态刷新不放在同一个handler里，导致LoadTasks事件覆盖子树状态

## 为什么会反复修不好
反复出现4次，且每次修复方式不同，最终确定为专用DeleteSubTask事件模式

## 正确修复模型
TBD

## 复盘教训（供参考）
- TBD

## 防复发检查项
- [ ] TBD

## 最小验证集
```bash
# TBD
```

## 相关历史
| change | bugfix_count | 归档时间 |
|---|---:|---|
| task-hierarchy-time-precision | 1 | 2026-05-25 21:01 |
