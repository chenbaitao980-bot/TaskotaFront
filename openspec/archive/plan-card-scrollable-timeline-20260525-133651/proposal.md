# plan-card-scrollable-timeline

## 需求澄清摘要
AI 计划卡片内包含"计划表"和"时间线"两个模块。当前当计划项数量较多时（如 7+ 项），时间线（horizontal Row）和计划表（表格列）内容被遮挡，用户无法查看完整内容。

## 为什么
- 时间线使用 `SingleChildScrollView(horizontal)` + `Row`，大量计划项时横向滚动，用户感知不到后面还有内容
- 计划表使用 `Column` 堆叠所有行，行数过多时整个卡片变得非常高，下方消息被推离可视区域
- 用户无法有效查看全部计划内容，交互体验差

## 影响面
`lib/presentation/pages/ai_chat/ai_chat_page.dart`

- `_buildTimelineView`（line 1647-1697）：改为固定高度 + 垂直可滚动
- `_buildPlanTable`（line 1334-1348）：添加分页控件

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED（`specs/plan-card-scrollable-timeline/spec.md` 追加）

## 改动范围
- `lib/presentation/pages/ai_chat/ai_chat_page.dart` 中的 `_buildTimelineView` 和 `_buildPlanTable`
- 不涉及其他文件

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/plan-card-scrollable-timeline.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
