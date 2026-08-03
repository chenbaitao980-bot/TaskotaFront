# brainstorm: 首页全部项目筛选无法切换

## Goal

修复首页项目筛选弹层中“全部项目”无法正确切换的问题，让用户能够直观看到“全选 / 取消全选 / 改选子集”的状态变化，并且保持首页项目筛选的现有过滤语义与持久化行为稳定。

## What I already know

* 问题发生在首页的项目筛选弹层，入口在 `lib/presentation/pages/home/home_page.dart`。
* 首页筛选当前使用 `_filterProjectIds` 保存已选项目；业务层把“空集合”解释成“不过滤项目 = 全部项目”。
* `home_page.dart` 的“全部项目”头部复选框当前以 `draft.isEmpty` 作为选中条件，并在点击时直接执行 `draft.clear()`。
* 共享组件 `lib/presentation/widgets/project_picker_content.dart` 中，每个项目和分组的勾选状态都基于 `draft.contains(id)` 渲染。
* 这导致 UI 语义冲突：顶部“全部项目”被勾选时，下面的分组/项目仍然显示未勾选，看起来像“没有选中任何项目”；再次点击也无法稳定表达“取消全选”。
* 日历页和任务页存在相同实现模式，首页不是唯一使用方。

## Assumptions (temporary)

* 这次先以修复筛选弹层交互一致性为目标，不改变现有筛选结果语义：最终“全部项目”仍可继续映射为现有的无筛选状态。
* 用户期望“全部项目”在弹层内表现为真正的全选 UI，而不是仅顶部复选框勾选、子项全空。

## Requirements (evolving)

* 首页项目筛选弹层中的“全部项目”需要与分组/项目复选框显示一致。
* 用户点击“全部项目”后，应能看到所有可选项目同步进入选中态。
* 用户取消“全部项目”后，应进入未选中任何项目的中间态，并可继续手动选择项目子集。
* 当未选中任何具体项目时，不直接允许提交该弹层。
* 保持首页已有筛选应用与本地持久化链路不被破坏。
* 如共享组件已被多个页面复用，优先在复用层收敛实现，避免同类弹层继续分叉。

## Acceptance Criteria (evolving)

* [ ] 首页筛选弹层打开时，如果当前为“全部项目”，顶部和项目列表显示一致的全选状态。
* [ ] 点击“全部项目”可以切换到明确的全选 UI；再次取消后不会出现“顶部选中、子项未选中”的矛盾状态。
* [ ] 用户取消全选后仍能勾选若干项目并确认，首页筛选结果正确生效。
* [ ] 未选择任何具体项目时，“确定”按钮不可用。
* [ ] 首页原有筛选持久化恢复行为保持可用。

## Decision (ADR-lite)

**Context**: 首页当前把“全部项目”持久化为“空集合”，数据过滤能工作，但弹层 UI 不能表达真实全选，导致切换语义混乱。

**Decision**: 仅在首页弹层内部使用“真实全选集合”驱动勾选 UI；点击确定时，再把“全选”映射回现有的空集合语义。取消全选后进入空草稿态，并禁止直接提交。

**Consequences**: 首页现有过滤与持久化链路可以保持不变，改动范围小；任务页和日历页仍保留原实现，后续若要统一交互可另起任务收敛。

## Definition of Done (team quality bar)

* Tests added/updated where appropriate
* Lint / typecheck / CI green for touched scope
* Docs/notes updated if behavior changes
* Rollout/rollback considered if risky

## Out of Scope (explicit)

* 不在这次任务中重做整个任务/日历/首页三处筛选状态模型。
* 不调整项目筛选之外的首页交互。

## Technical Notes

* 关键文件：
  * `lib/presentation/pages/home/home_page.dart`
  * `lib/presentation/widgets/project_picker_content.dart`
  * `lib/services/local_storage_service.dart`
  * 参考同类实现：`lib/presentation/pages/calendar/calendar_page.dart`、`lib/presentation/pages/tasks/tasks_page.dart`
* 相关规范：
  * `.trellis/spec/frontend/state-management.md`
  * `.trellis/spec/frontend/quality-guidelines.md`
