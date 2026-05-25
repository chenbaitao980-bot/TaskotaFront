# Capability Spec

## 变更类型
- MODIFIED：`_parsePlanDate` 增加 `_clampToThisWeek`
- MODIFIED：`_defaultPlanStart` 溢出时错峰分布
- MODIFIED：`_buildTimelineView` 排序加二级键

## 场景

### SC-01：AI 显式日期被夹到本周
**Given** AI 输出包含 "06-02" 或 "6月2日" 等未来日期
**Then** `_parsePlanDate` 返回的日期 ≤ 本周日

### SC-02：超量计划错峰分布
**Given** 计划行数 > 本周剩余天数
**Then** 溢出行的 start 时间分布在最后一天的不同小时（9~23），非全部 23:59

### SC-03：时间线同天有序
**Given** 多个计划行在同一天
**Then** 时间线按 start 时间 + 原始索引升序排列
