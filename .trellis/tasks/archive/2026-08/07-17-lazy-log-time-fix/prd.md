# brainstorm: 懒人日志时间选取bug修复

## Goal

修复懒人日志两个 bug：
1. 输入包含"下班"等隐含时间语义时，自动创建的任务时间没有选到五点以后（用户 AI 配置里写了"下班时间是五点"）
2. 偶发的拖动任务导致任务消失

## What I already know

### Bug 1 — 时间选取
- 懒人日志调用 AI 分析输入，`system prompt` 注入了 `userInstructions`（含用户偏好"下班时间是五点"）
- AI prompt 规则 3 说"结合当前日期转换为 ISO-8601"，但没有针对"下班后"这类隐含时间语义做特殊处理
- `_hasExplicitClock` 检查 `下午|晚上` 等词，但"下班"不在匹配列表中
- 当用户说"下班送路由器"时，AI 可能没有把时间和"五点后"关联起来

### Bug 2 — 拖动消失
- 用户反馈偶发出现，需进一步看 task 拖拽逻辑

## Assumptions (temporary)

* Bug 1 根因可能在 prompt 层面（AI 不知道下班 = 17:00+）
* Bug 2 可能是列表 state 更新问题

## Open Questions

* Bug 1: 修复方式？改 prompt vs 前端后处理修正时间
* Bug 2: 需要进一步复现和分析

## Requirements (evolving)

* 输入"下班"相关语义时，任务时间自动设在 17:00 之后
* 拖动任务不应导致任务消失

## Acceptance Criteria (evolving)

* [x] Bug 2 修复：拖动任务不消失（单源化：DB 主源 + storage fallback 去重）
* [x] 输入"我给舅舅下班送路由器"，任务时间在 17:00 之后（prompt 规则 13 + 前端后处理）
* [ ] 用户可配置关键字→时间映射（配置系统）

## Out of Scope (explicit)

* 其他语言/时区支持

## Expansion Sweep (DIVERGE)

**用户确认：全做** — bug修复 + 关键字配置 + prompt增强

### Future Evolution
* 配置系统可扩展为更多语义映射（如"明天上午"→具体时间规则）

### Related Scenarios
* 自定义映射规则也可用于项目分组/项目路由（不只是时间）
* 配置UI可复用于其他AI相关配置

### Failure & Edge Cases
* 关键字映射规则冲突（多条规则匹配同一输入）
* 配置为空时的降级行为

## Decision (ADR-lite)

**Context**: 懒人日志两个bug — 时间选取不准 + 拖动消失

**Decision (Bug 2)**: 单源化 + storage fallback — `_loadData` 以 SQLite DB 为主源，storage 只补充 DB 中没有的任务，去掉去重逻辑。

**Decision (Bug 1)**: 综合方案 — AI prompt增强 + 前端后处理修正 + 用户可配置关键字→时间/项目映射

**Consequences**:
* 用户可通过配置自行调整，不依赖prompt工程调优
* 维护两套逻辑（prompt + 前端后处理），需保证一致性
* 配置系统为未来更多语义映射奠定基础
