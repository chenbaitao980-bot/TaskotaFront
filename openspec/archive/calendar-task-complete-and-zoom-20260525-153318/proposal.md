# calendar-task-complete-and-zoom

## 需求澄清摘要
已确认目标是在日历周视图中让已完成任务和日程置灰区分，为任务/子任务块增加直接勾选完成能力，并支持 Ctrl+鼠标滚轮缩放时间轴；范围限定为日历交互和视觉状态，不改任务业务规则、数据结构或通知逻辑；验收标准为勾选后状态持久化并刷新置灰，Ctrl+前滚显示更多时段、Ctrl+后滚显示更少但更清晰。

## 为什么
日历任务完成态缺少视觉区分，子任务块不能直接完成，时间轴默认可视时段太少影响排期浏览。

## 影响面
### GitNexus impact: `_CalendarPageState._buildTaskBlock` (depth=2)
{
  "error": "Target '_CalendarPageState._buildTaskBlock' not found",
  "target": {
    "name": "_CalendarPageState._buildTaskBlock"
  },
  "direction": "upstream",
  "impactedCount": 0,
  "risk": "UNKNOWN"
}

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 改动范围
<AI 实施时填写>

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/calendar-task-complete-and-zoom.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
