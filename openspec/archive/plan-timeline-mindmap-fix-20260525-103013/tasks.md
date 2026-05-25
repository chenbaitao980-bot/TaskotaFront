# 任务清单：plan-timeline-mindmap-fix

## 实施任务

- [x] 1. 定位时间约束解析相关代码（`_defaultPlanStart`、`_weekdayIndex`、`_parsePlanDate`、`_extractEditablePlanRows`）并确认影响范围
- [ ] 2. 新增 `_clampToThisWeek` 工具方法，将超出本周的日期截断到本周日
- [ ] 3. 在 `_defaultPlanStart` 和 `_parsePlanDate` 中插入 `_clampToThisWeek` 调用
- [ ] 4. 更新 AI Prompt 指令，加入显式的日期范围约束（当前日期、本周边界）
- [ ] 5. 将"思维导图"标签改为"时间线"（第 1086 行）
- [ ] 6. 优化时间线 Widget：缩小尺寸（160×56px），按 start 升序排列，保留横向布局
- [ ] 7. 新增 `_buildWBSMindMap` 方法，实现按 `stage` 分组的树状布局
- [ ] 8. 在计划视图底部插入 WBS 组件（在"一键分配"按钮和"查看原始计划"之间）
- [ ] 9. 将计划表开始/结束时间合并到同一行显示（格式：MM-dd HH:mm ~ HH:mm）
- [ ] 10. 运行 `flutter analyze --no-fatal-infos`
- [ ] 11. 运行 `flutter test`
- [ ] 12. 运行 GitNexus 变更检测

## 验证项

- [ ] 1. 用户验证时间约束修复：输入"只在早上踢球并且只在这周踢球"后，无计划行超出本周日
- [ ] 2. 用户验证"思维导图"已改为"时间线"
- [ ] 3. 用户验证时间线节点按时间正确排序、横向排列、紧凑（≤160×56px）
- [ ] 4. 用户验证 WBS 思维导图显示任务分层结构
- [ ] 5. 用户验证计划表开始/结束时间合并到同一行展示

## 回归用例

见 `regression-tests/cases/plan-timeline-mindmap-fix.md`
