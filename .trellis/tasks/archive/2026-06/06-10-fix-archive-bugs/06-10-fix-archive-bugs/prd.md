# fix: 归档功能闪退及交互问题修复

## Goal

修复 task archive 功能中的三个核心 bug：归档视图闪退、视图切换失效、搜索/筛选对归档任务不生效。

## Requirements

1. **归档视图不再闪退** — `_onLoadTasks` 保留 `showArchivedView`，外部触发的 `LoadTasks` 在归档视图下应改为加载归档任务
2. **归档视图下支持思维导图/列表切换** — body 渲染不跳过 viewMode 判断，`_buildArchivedView` 支持 mindmap 模式
3. **归档任务搜索/筛选正常工作** — `_onSetSearchQuery` 在归档视图下发 `LoadArchivedTasks`，repo 搜索支持归档任务

## Root Causes (from exploration)

| Bug | Root Cause |
|-----|-----------|
| #1 Flashback | `_onLoadTasks` emit 未保留 `showArchivedView`（默认 false）；`_debounceLoadTasks` 无条件触发 |
| #2 View switch | body 渲染在 `showArchivedView` 时短路到硬编码 ListView |
| #3 Search/filter | `_onSetSearchQuery` 无视归档状态发 `LoadTasks`；`searchTaskIds` 硬编码 `archived=0`；`LoadArchivedTasks` 缺 search/date 参数 |

## Acceptance Criteria

- [x] 归档后不会闪退回思维导图页面
- [x] 归档视图下可在思维导图/列表间切换
- [x] 归档视图下搜索、状态筛选、日期筛选正常工作
- [x] `_debounceLoadTasks` 在归档视图下不重置为普通视图

## Definition of Done

- Lint/typecheck 通过
- 三个 bug 全部修复

## Technical Approach

1. `_onLoadTasks`: 保留 `showArchivedView` 从 previous state
2. `tasks_page.dart` body: 归档视图下也根据 `viewMode` 渲染 mindmap/list
3. `_onSetSearchQuery`: 归档视图下发 `LoadArchivedTasks`
4. `LoadArchivedTasks` event: 加 `searchKeyword`/`dateFrom`/`dateTo` 参数
5. `_onLoadArchivedTasks`: 支持搜索和日期过滤
6. `task_repository.dart`: `searchTaskIds` / `getArchived` 支持搜索和日期过滤
7. `home_page.dart` `_debounceLoadTasks`: 检查是否在归档视图
8. `calendar_page.dart` `_notifyBloc`: 同理

## Out of Scope

- 性能优化
- UI 重新设计
