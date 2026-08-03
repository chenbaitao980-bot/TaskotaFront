# brainstorm: 懒人日志后台生成待审核任务

## Goal

让懒人日志在用户按回车或点击整理后立即返回，不再阻塞等待 AI 生成和任务创建。AI 在后台队列中生成待审核任务草稿，用户可查看、修改、批量或选择性审核，通过审核后草稿才正式创建为任务。

## What I Already Know

* 用户希望回车后不要等待 AI，改为后台队列创建。
* 前台需要显示“创建中 x 个任务”和“待审核 x 个任务”。
* 点击“待审核 x 个任务”可以打开审核列表。
* 审核列表需要展示任务时间范围、项目所属、紧急度、父任务等信息。
* 用户可以在列表直接修改信息，也可以点详情查看完整内容。
* 用户可以一键全部审核，也可以选择部分任务审核。
* 审核通过后，这些草稿才正式写入任务。
* AI 生成时需要尽量避开与其他任务的时间冲突。
* 用户建议新增一张数据库表，数据库设计由实现侧决定。
* 当前代码中 `_submitLazyLog()` 会等待 `_lazyLogService.structure(...)`、预览弹窗和 `_applyLazyLogPlan(...)`，因此回车后会阻塞在主流程。
* 当前已有 `LazyLogTaskDraft` / `LazyLogResult` / `LazyLogCreationDialog` / `LazyLogCreationPlan`，但没有持久化的待审核草稿表。
* 当前正式任务写入经过 `TaskRepository.create(...)` 和 `tasks` 表；数据库是 Drift，`AppDatabase.schemaVersion` 当前为 12。
* 现有冲突处理在 `_applyLazyLogPlan(...)` 中使用 `TaskConflictService`，会在正式创建前弹窗处理冲突。

## Assumptions (Temporary)

* MVP 以本地数据库持久化待审核草稿为主，应用重启后待审核任务仍可恢复。
* “创建中 x 个任务”中的 x 可以先按本次懒人日志请求预计生成的草稿数量或后台作业数量展示；AI 完成后转入“待审核 x 个任务”。
* 草稿审核通过时复用现有正式任务创建链路，避免绕过父任务日期扩展、祖先重开、同步等现有规则。
* 草稿表需要保存原始输入、AI 摘要、项目/父任务候选、任务字段、状态、错误信息和时间戳。

## Open Questions

* None.

## Requirements (Evolving)

* 提交懒人日志后，输入框立即清空或恢复可输入状态，不等待 AI 返回。
* 后台队列执行 AI 结构化解析，并把生成结果保存为待审核草稿。
* 前台展示后台生成中的数量。
* 前台展示待审核草稿数量，并提供入口打开审核列表。
* 后台 AI 生成完成后不再弹出原来的完整预览弹窗，统一通过“待审核 x 个任务”入口进入审核。
* 审核列表支持查看每条草稿的标题、时间范围、项目、父任务、紧急度、状态。
* 审核列表支持直接编辑关键字段。
* 草稿详情页或详情弹层支持查看和编辑完整字段，包括描述、清单等。
* 支持全选/多选审核通过。
* 审核通过后将草稿正式创建为任务，并更新列表和时间轴。
* 审核通过并成功创建正式任务后，草稿立即从待审核列表移除。
* 后台生成或审核入库失败时，用户可看到失败状态并可重试或删除草稿。
* AI 生成草稿和审核创建任务时，应尽量避免和现有任务时间冲突，优先自动调整到最近可用时间段。
* 时间冲突检测必须同时考虑正式任务和其他待审核草稿，避免两个草稿之间互相撞时间。
* 批量审核多个草稿时，按审核顺序逐个分配可用时间；前面已审核或即将创建的草稿时间也要参与后续草稿的冲突检测。

## Acceptance Criteria (Evolving)

* [ ] 用户在懒人日志输入后按回车，UI 不阻塞等待 AI 生成。
* [ ] AI 生成期间页面显示“创建中 x 个任务”或等价状态。
* [ ] AI 生成完成后，页面显示“待审核 x 个任务”。
* [ ] AI 生成完成后不会弹出原懒人日志完整预览弹窗。
* [ ] 点击待审核入口可以看到草稿审核列表。
* [ ] 审核列表能展示并编辑时间范围、项目、父任务、紧急度。
* [ ] 用户可以查看单条草稿详情。
* [ ] 用户可以审核全部草稿。
* [ ] 用户可以选择部分草稿审核。
* [ ] 审核通过的草稿会正式创建任务，并从待审核列表移除或标记为已创建。
* [ ] 审核通过并成功创建正式任务后，草稿立即从待审核列表移除，待审核计数同步减少。
* [ ] 草稿数据持久化在本地数据库，应用重启后未审核草稿不丢失。
* [ ] 冲突时间尽量自动避让，无法自动处理时保留可审核状态并提示。
* [ ] 创建或批量审核时会检查待审核草稿之间的时间冲突。
* [ ] 相关 Drift schema / migration / generated code 更新完成。
* [ ] 相关测试或最小验证覆盖后台生成、草稿持久化和审核入库。

## Definition of Done

* Tests added/updated where practical.
* Flutter analyze / targeted tests run; if repository has historical warnings, report targeted result.
* Database migration and generated files are consistent.
* Existing懒人日志正式任务创建能力不回退。
* Rollback path considered: pending drafts can be deleted or ignored without affecting正式任务表。

## Out of Scope (Explicit)

* 不在本任务中重做 AI 提示词体系，除非需要让输出包含审核草稿字段。
* 不在本任务中实现云端多人协同审核。
* 不在本任务中改造所有任务创建入口，只处理懒人日志生成任务流程。
* 不保留原懒人日志完整预览弹窗作为后台生成完成后的确认入口。
* 不在本任务中自动提交或推送代码，除非用户后续明确要求。

## Decision (ADR-lite)

**Context**: 原流程在 AI 生成完成后弹出完整预览弹窗，用户需要立即处理，无法形成真正的后台队列体验。

**Decision**: 后台 AI 生成完成后不保留原完整预览弹窗，统一进入“待审核 x 个任务”列表；所有查看、编辑、详情、批量审核和选择性审核都在审核队列完成。

**Consequences**: 用户按回车后不会被打断，审核入口更统一；实现上需要让审核列表覆盖原预览弹窗已有的编辑能力。

## Decision (ADR-lite): Time Conflict Policy

**Context**: AI 在后台生成草稿时需要尽量避开已有任务，但审核通过时正式任务和草稿队列可能已经变化；如果只检查正式任务，多个待审核草稿仍可能互相冲突。

**Decision**: 审核创建时选择“自动找最近可用时间并创建”。可用时间检查同时考虑正式任务、其他待审核草稿、以及同一批量审核中已经安排的草稿。

**Consequences**: 批量审核更省心，时间轴更少重叠；实现上需要把草稿也纳入冲突查询或在审核服务中构造合并后的占用时间表。

## Decision (ADR-lite): Review List Completion

**Context**: 待审核入口的数量应该只代表仍需用户处理的草稿。如果保留已创建记录，列表会更完整但会让计数和当前待办含义变模糊。

**Decision**: 草稿审核通过并成功创建正式任务后，立即从待审核列表移除。

**Consequences**: 审核列表保持干净，待审核计数清晰；如需回看创建结果，通过正式任务列表和时间轴查看。

## Technical Notes

* Relevant files discovered:
  * `lib/presentation/pages/home/home_page.dart`
  * `lib/services/home_lazy_log_service.dart`
  * `lib/models/assistant/lazy_log_models.dart`
  * `lib/presentation/pages/home/lazy_log_creation_dialog.dart`
  * `lib/data/database/app_database.dart`
  * `lib/data/repositories/task_repository.dart`
* Current database tables include `Projects`, `Tasks`, `ChecklistItems`, `ProjectGroups`, `TaskAttachments`, and `NodeTemplates`; new pending lazy-log draft table likely belongs in `app_database.dart`.
* Existing conflict logic lives near `_applyLazyLogPlan(...)` and uses `TaskConflictService`.
* Existing formal creation path should be reused through `TaskRepository.create(...)` where possible.
