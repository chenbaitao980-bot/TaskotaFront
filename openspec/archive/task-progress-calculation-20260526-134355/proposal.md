# task-progress-calculation

## 需求澄清摘要
目标：为任务模块增加进度概念；范围：任务/项目进度计算、检查项和子任务状态变更后的刷新、必要 UI 展示与测试；非目标：不重做任务模块交互、不改无关样式或数据结构；验收：无子任务按检查项/自身状态计算，有子任务递归纳入子任务、自身检查项与无检查项任务，项目按任务完成度汇总。

## 为什么
任务模块当前缺少基于检查项与子任务的统一进度计算

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
- [ ] 已维护 `regression-tests/cases/task-progress-calculation.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更

> 验收项由 AI 在实施中完成并打勾；用户只确认 `tasks.md` 的验证项。
