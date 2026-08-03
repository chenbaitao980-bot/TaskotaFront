# brainstorm: 懒人日志换行与失败任务查看

## Goal

修复懒人日志两个问题：(1) Shift+Enter 无法换行 (2) 整理失败任务无入口查看和调整

## What I already know

### Issue 1: Shift+Enter 换行
- 位置: `home_page.dart:1609-1636` — `_buildLazyLogPanel()` 中的 Focus + TextField
- Focus 的 `onKeyEvent` 已经正确处理：纯 Enter → 拦截并调用 `_submitLazyLog()`，Shift+Enter → `KeyEventResult.ignored` 向下传递
- 问题根源：TextField 有 `onSubmitted: (_) => _submitLazyLog()`，这个回调在 Shift+Enter 时也会触发（IME action），导致清空输入框，新行插不进去
- **修复**: `onSubmitted` 中检查 `HardwareKeyboard.instance.isShiftPressed`，Shift 按下时不提交

### Issue 2: 失败任务查看
- `LazyLogDraftRepository` 已有 `watchReviewable()` 返回所有 `needsReview==1` 的 drafts（含 failed）
- `LazyLogDraftReviewSheet` 已支持显示失败任务（红色"失败"chip、错误信息、重试按钮）
- 但 `_buildLazyLogQueueStatus()` 只监控 `running` 和 `pending_review` 数量，无失败入口
- 需要加 `watchFailedCount()`、在面板显示失败入口、允许 failed 任务编辑后再重试

## Requirements

* [x] 修复 Shift+Enter 无法换行
* [x] 整理按钮旁增加失败任务入口（含数量）
* [x] 失败任务可查看详情、修改内容（项目等）后重试

## Acceptance Criteria

* [x] Shift+Enter 能在懒人日志输入框中换行
* [x] 纯 Enter 仍正常提交整理
* [x] 有失败任务时，整理按钮旁显示失败数量和入口
* [x] 点击失败入口可查看失败任务列表
* [x] 失败任务可编辑项目等信息后点重试

## Technical Approach

### 修改文件

1. `lib/data/repositories/lazy_log_draft_repository.dart` — +`watchFailedCount()`
2. `lib/presentation/pages/home/home_page.dart` — `onSubmitted` 加 Shift 检查 + 失败按钮
3. `lib/presentation/pages/home/lazy_log_draft_review_sheet.dart` — failed 状态允许编辑

### 关键决策

- 失败按钮使用 `OutlinedButton.icon` 红色样式，仅在 count>0 时显示
- 点击打开已有的 `LazyLogDraftReviewSheet`（已有失败任务展示、重试流程）
- `canEdit` 扩展至 failed 状态：项目/父任务/优先级/标题/描述/checklist 均可编辑
- 不新增文件、不新增依赖

## Out of Scope

* 失败时自动重试机制
* 项目路由上下文的改进
