# task-archive-feature: 任务归档功能

## Goal

为任务管理系统增加任务级别的归档功能：用户可在任务详情、任务模块（列表/思维导图）、日历模块、首页右键菜单中将任务归档；归档的任务从所有正常视图和计算中排除，只在任务模块「已归档」专区查看。

## What I already know

* `Tasks` 表目前没有 `archived` 列（`Projects` 表已有 `archived`），需要加字段并迁移（当前 schemaVersion = 10）
* 任务有子任务关系：`parentId` 字段，子任务未完成不允许归档需前端+后端双重拦截
* 子任务完成状态：`status == 2` 代表完成
* 上下文菜单：
  * `task_card.dart` `_showContextMenu`：当前有「编辑」「删除」
  * `calendar_page.dart` `_showTaskContextActions`：当前有「详情」「删除」（含 PopupMenuButton 形式）
  * `home_page.dart` `_showDeleteContextMenu`：当前有删除相关操作
  * `mind_map_view.dart`：也有 `_showContextMenu`
* BLoC 模式：`TaskNewBloc` / `TaskNewEvent` / `TaskNewState`
* Drift ORM，数据库操作在 `TaskRepository`
* 有 Supabase 同步服务（`TaskSyncService`）

## Assumptions (temporary)

* 归档操作针对单个任务（而非批量）
* 取消归档（恢复）功能需要提供
* Supabase 同步需要同步 `archived` 字段

## Open Questions

*(无)*

## Decision Log

| # | 问题 | 决定 | 理由 |
|---|------|------|------|
| 1 | 归档时子任务如何处理 | **跟随归档**：父任务归档 → 所有子任务也自动归档；恢复父任务 → 子任务一并恢复 | 避免孤悬子任务，逻辑最干净 |
| 2 | 已归档专区 UI 位置 | **侧边栏底部固定入口**：左侧 `project_sidebar` 最底部加「📦 已归档」固定项，点击后右侧显示归档任务列表 | 与现有项目筛选逻辑一致，不污染状态 tab |
| 3 | 子任务能否单独归档 | **可以**：子任务可从其详情页单独归档，归档后从父任务子树消失；恢复后回到原父任务下（`parentId` 保留） | 灵活性高，父子关系字段不丢失 |

## Requirements (evolving)

* R1: `Tasks` 表新增 `archived` 字段（INTEGER, DEFAULT 0），DB schema v11
* R2: 子任务有未完成项时，归档被拦截并弹提示
* R3: 以下入口均可触发归档：任务详情编辑页、任务模块右键菜单（列表+思维导图）、日历模块右键/操作菜单、首页右键菜单
* R4: 归档任务不出现在：任务列表、首页、日历、进度计算、统计等所有正常查询中
* R5: 已归档任务只在任务模块「已归档」专区可查看（新增筛选 tab 或 section）
* R6: 支持从「已归档」区取消归档（恢复正常状态）

## Acceptance Criteria (evolving)

* [ ] 任务详情页有归档按钮，点击后触发归档流程
* [ ] 有未完成子任务时弹出拦截提示，归档不执行
* [ ] 归档后任务从列表、日历、首页消失
* [ ] 所有进度计算（project progress, group progress）不包含已归档任务
* [ ] 任务模块有「已归档」入口，可查看所有已归档任务
* [ ] 已归档区域可执行取消归档操作
* [ ] Supabase 同步包含 archived 字段

## Definition of Done

* DB 迁移脚本写入 app_database.dart，schemaVersion = 11
* 归档/取消归档 Event + Handler 在 TaskNewBloc 中实现
* TaskRepository 新增 archiveTask / unarchiveTask 方法
* 所有现有查询（getAll、getRootTasks、getByProject、getToday 等）过滤 archived = 0
* 进度计算（task_progress_calculator.dart）过滤 archived
* 上下文菜单（4 处）均添加「归档」选项
* TaskSyncService 同步 archived 字段

## Out of Scope (explicit)

* 批量归档
* 按项目归档（项目级别已有 archived，本次只做任务级别）
* 归档历史记录 / 审计日志

## Technical Notes

* 文件位置：
  * DB: `lib/data/database/app_database.dart`（需重新运行 build_runner）
  * 仓库: `lib/data/repositories/task_repository.dart`
  * BLoC: `lib/presentation/blocs/task_new/task_bloc.dart` + `task_event.dart` + `task_state.dart`
  * 进度: `lib/domain/tasks/task_progress_calculator.dart`
  * UI 入口:
    * `lib/presentation/pages/tasks/widgets/task_card.dart`（`_showContextMenu`）
    * `lib/presentation/pages/tasks/widgets/mind_map_view.dart`（`_showContextMenu`）
    * `lib/presentation/pages/calendar/calendar_page.dart`（`_showTaskContextActions`）
    * `lib/presentation/pages/home/home_page.dart`（`_showDeleteContextMenu`）
    * `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`（详情页新增按钮）
  * 同步: `lib/services/task_sync_service.dart`
