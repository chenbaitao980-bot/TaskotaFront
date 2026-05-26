# calendar-filter-and-sync-fix

## 需求澄清摘要
修复日历项目筛选无法切回全部项目(bug1)、日历拖拽时间后切换任务页面时间未同步(bug2)、优化时间线拖拽热区太小及跨日任务不可拖拽(优化1)。范围：calendar_page.dart / home_page.dart，不改bloc只加通知调用。

## 为什么
日历与任务页面状态不同步，用户操作体验差

## 影响面
未提供影响面；实施前需要用 context plan / impact 补齐。

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability
- 推荐动作：MODIFIED

## 改动范围
<AI 实施时填写>

## 验收
- [ ] 实现本次需求的最小改动
- [ ] 已维护 `regression-tests/cases/calendar-filter-and-sync-fix.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
