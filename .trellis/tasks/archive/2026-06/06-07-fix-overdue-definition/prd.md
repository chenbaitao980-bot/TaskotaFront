# fix-overdue-definition：修复逾期任务的判断基准

## Goal

当前代码在多处以 **startDate（开始时间）** 判断任务是否逾期，但正确定义是：
**当前时间超过任务的 endDate（结束日期/截止日期）才算逾期。**
需要统一修正统计面板、逾期 Sheet、通知服务三个位置。

## What I already know

- Task 模型字段：`startDate`（可空 int 毫秒）、`dueDate`（可空 int 毫秒，即结束日期）
- `_TimelineTask.date` = startDate；`_TimelineTask.endDate` = dueDate
- **Bug 1 — `home_page.dart` 统计卡（~L1453）**：
  ```dart
  final overdueByDay  = _filteredTasks.where((t) => t.date.isBefore(today) && !t.isCompleted);
  final overdueByHour = _filteredTasks.where((t) => _isSameDayDate(t.date, today) && t.date.isBefore(now) && !t.isCompleted);
  ```
  用的是 `t.date`（startDate），应改为 `t.endDate`。
- **Bug 2 — `home_page.dart` `_showOverdueSheet`（~L1630）**：
  三个 mode 都用 `t.date` 而非 `t.endDate`。
- **Bug 3 — `notification_service.dart` `rescheduleTaskReminders`（~L663）**：
  ```dart
  if (startTime.isBefore(now)) { overdueTaskIds.add(task.id); continue; }
  ```
  `startTime` 来自 `task.startDate`，应改用 `task.dueDate`。
- `task_card.dart` 的 `_isOverdue(task.dueDate!)` **已经是正确的**（用 dueDate），只需保持一致。

## Assumptions (temporary)

- 无 dueDate 的任务 **永不逾期**：不计入统计、不触发逾期通知

## Open Questions

（已全部解答）

## Requirements (evolving)

- [ ] home_page.dart 统计面板逾期数改为按 endDate 判断
- [ ] home_page.dart `_showOverdueSheet` 逾期列表改为按 endDate 判断
- [ ] notification_service.dart 通知调度改为按 dueDate 判断
- [ ] 行为一致性：task_card 已正确，保持不变

## Acceptance Criteria (evolving)

- [ ] 有 startDate = 昨天、dueDate = 明天 的未完成任务，不计入逾期
- [ ] 有 startDate = 昨天、dueDate = 昨天 的未完成任务，计入逾期
- [ ] 无 dueDate 的任务逾期判断符合确认后的规则
- [ ] 逾期通知触发时机与统计面板口径一致

## Definition of Done

- Lint / typecheck 绿
- 三处 bug 全部修正，逻辑一致
- 手动验证逾期统计数字正确

## Out of Scope

- task_card.dart 的逾期着色（已正确，不动）
- 新增"无截止日期任务"UI 提示

## Technical Notes

- 文件：`lib/presentation/pages/home/home_page.dart`（L1453, L1630）
- 文件：`lib/services/notification_service.dart`（L658-664）
- `_TimelineTask.endDate` 对应 Task.dueDate（nullable）
- notification_service 中 `startTime = DateTime.fromMillisecondsSinceEpoch(task.startDate!)`，改为读 `task.dueDate`
