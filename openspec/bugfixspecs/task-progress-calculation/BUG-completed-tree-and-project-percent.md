# BUG-completed-tree-and-project-percent: Completed tasks did not preserve parent-child hierarchy, and project progress showed 40% after completing a parent and child because checklist items were overweighted.

## 适用范围
- Capability: task-progress-calculation
- 关联 change: task-progress-calculation
- 关联文件/函数: lib/presentation/pages/tasks/widgets/task_list_view.dart,lib/domain/tasks/task_progress_calculator.dart,test/task_progress_calculator_test.dart

## 用户可见现象
Completed tasks did not preserve parent-child hierarchy, and project progress showed 40% after completing a parent and child because checklist items were overweighted.

## 根本原因
The completed section rendered a flat TaskCard list instead of rebuilding the filtered task tree, and project progress used checklist items as a global denominator instead of counting each task work unit once.

## 为什么会反复修不好
The repeated fix happened because completed-list rendering and project progress were treated as isolated surfaces instead of one task-tree plus work-unit progress model.

## 正确修复模型
For each visible task group, rebuild a filtered task tree and promote children when their parent is absent. For project totals, count each task as one work unit; checklist completion only determines that task's own progress.

## 复盘教训（供参考）
- Do not flatten completed task groups when parent-child task hierarchy matters
- Do not use checklist-item count as a project-wide denominator
- Add a unit test for checklist overweighting before archiving progress changes


## 防复发检查项
- [ ] Run flutter test test\task_progress_calculator_test.dart
- [ ] Check completed task groups render with parent-child hierarchy
- [ ] Check a task with many checklist items does not dominate project progress


## 最小验证集
```bash
# TBD
```

## 相关历史
| change | bugfix_count | 归档时间 |
|---|---:|---|
| task-progress-calculation | 2 | 2026-05-26 13:43 |
