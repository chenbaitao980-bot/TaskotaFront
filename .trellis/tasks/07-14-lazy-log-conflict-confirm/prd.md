# 懒人日志冲突任务确认

## Goal

通过懒人日志创建任务时，如果目标时间段和已有任务冲突，不再自动延后，而是弹出与正常创建任务一致的冲突确认，让用户选择插入、延迟或跳过。

## What I already know

* 用户反馈：懒人日志创建任务遇到冲突时目前自动延后，没有弹框确认。
* 目标行为要和正常创建任务一致。
* 必须支持跳过冲突任务。
* 当前仓库有未提交 WIP，本任务只改懒人日志冲突创建相关代码。

## Requirements

* 懒人日志批量创建任务时，遇到时间冲突必须弹出确认对话框。
* 对话框选项与正常创建任务保持一致：插入、延迟、跳过。
* 用户选择插入时，按现有插入语义处理时间冲突。
* 用户选择延迟时，按现有延后语义处理时间冲突。
* 用户选择跳过时，不创建该冲突任务，并继续处理后续任务。
* 非冲突任务保持原有创建行为。

## Acceptance Criteria

* [ ] 懒人日志创建冲突任务时不再静默自动延后。
* [ ] 冲突确认 UI 出现且包含插入、延迟、跳过。
* [ ] 选择跳过不会创建当前冲突任务，后续任务仍可继续。
* [ ] 正常创建任务的冲突行为不退化。
* [ ] Dart analyze 或相关测试通过；若无法全量通过，记录原因和已验证范围。

## Definition of Done

* Tests added/updated where practical.
* Lint / typecheck / analyzer checked for touched files.
* Docs/spec update considered.
* No unrelated dirty files are included.

## Technical Approach

Inspect the existing normal task conflict flow and reuse its service/dialog semantics from the lazy-log creation path instead of inventing a separate conflict resolver.

## Out of Scope

* Redesigning conflict detection rules.
* Changing project routing/group hint logic for lazy logs.
* Changing task sync behavior unrelated to this conflict prompt.

## Technical Notes

* CodeGraph points to `lib/services/home_lazy_log_service.dart`, `lib/presentation/pages/home/lazy_log_creation_dialog.dart`, `lib/presentation/pages/home/home_page.dart`, and `lib/services/task_conflict_service.dart` as likely impacted areas.
* Memory notes say task mutation flow often centers on `TaskNewBloc`, `TaskRepository`, and rollback; verify current code before relying on this.
