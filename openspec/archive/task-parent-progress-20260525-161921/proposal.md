# task-parent-progress

## 需求澄清摘要
已确认目标、用户场景、范围、非目标、验收标准和关键取舍

## 为什么
任务详情页增加父任务展示与跳转，父任务进度按子任务完成比例计算

## 影响面
- 任务详情页 UI：增加父任务展示区域、进度计算展示
- 本地存储服务：增加递归获取所有子任务、计算进度方法
- 任务模型：无变更，复用现有 `parentTaskId` 字段

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 改动范围
1. `lib/services/local_storage_service.dart`：增加 `getAllDescendantTasks()`、`calculateTaskProgress()` 方法
2. `lib/presentation/pages/task/task_detail_page.dart`：增加父任务展示区域、跳转逻辑、进度计算展示

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/task-parent-progress.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
