# fix: 思维导图完成状态不同步到日历

## Goal

在思维导图视图完成任务后，切换到日历视图时任务状态仍显示为未完成。需要修复跨视图的状态同步问题。

## What I already know

- 架构：`IndexedStack` 底部导航，`TasksPage`（含 MindMap）和 `CalendarPage` 同时挂载，始终在后台存活
- 数据流：
  1. MindMap 点击完成 → `onTaskToggle` → `_handleToggleTaskStatus` → `ToggleTaskStatus` Bloc 事件
  2. Bloc `_onToggleTaskStatus` → DB 更新 → `_emitTaskSnapshot` → emit 新 `TaskNewLoaded`
  3. CalendarPage `BlocListener` 接收 → 调用 `_reloadData()`
  4. **2秒节流**：`_reloadData()` 头部有节流保护，2秒内不重复加载
- **根本原因**：当用户在日历页做了任何操作（任务开关/编辑/删除等），`_reloadData()` 会更新 `_lastReloadTime`。若 2 秒内切换到 MindMap 并点击完成，BlocListener 触发的 `_reloadData()` 会因节流被静默跳过，`_allTasks` 不刷新，切回日历后仍显示旧状态。

## Requirements

- 从 BlocListener 触发的 `_reloadData()` 必须绕过节流，确保外部状态变更立即同步到日历

## Acceptance Criteria

- [ ] MindMap 标记任务完成后，切换到日历视图，任务显示为已完成
- [ ] 节流保护依然对 CalendarPage 内部自触发的快速连续刷新有效

## Technical Approach

给 `_reloadData` 添加 `bool force = false` 参数。节流检查改为：`if (!force && ...)` 。  
BlocListener 调用时传 `force: true`，绕过节流。

影响文件：`lib/presentation/pages/calendar/calendar_page.dart`

## Out of Scope

- 其他视图（列表视图）的完成状态同步（与日历同样走 BlocListener，同样修复）
- 状态管理架构重构

## Technical Notes

- 文件：`calendar_page.dart` 第 117 行 `_reloadData()`，第 130 行节流条件，第 768-773 行 BlocListener
