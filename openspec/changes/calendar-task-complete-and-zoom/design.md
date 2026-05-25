# 设计：calendar-task-complete-and-zoom

## 需求澄清依据
已确认目标是在日历周视图中让已完成任务和日程置灰区分，为任务/子任务块增加直接勾选完成能力，并支持 Ctrl+鼠标滚轮缩放时间轴；范围限定为日历交互和视觉状态，不改任务业务规则、数据结构或通知逻辑；验收标准为勾选后状态持久化并刷新置灰，Ctrl+前滚显示更多时段、Ctrl+后滚显示更少但更清晰。

## 当前状态
TBD

## 方案
TBD

## 业务规则处理
- 原 Requirement / Scenario：无
- 本次处理方式：MODIFIED

## 回归测试方案
- 用例文件：`regression-tests/cases/calendar-task-complete-and-zoom.md`
- 批量测试接口 / 命令：TBD

## 回滚方案
删除 `openspec/changes/calendar-task-complete-and-zoom/` 目录。
