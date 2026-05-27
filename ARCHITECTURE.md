# Architecture

## Overview

`smart_assistant` is a Flutter application with shared UI code for mobile and desktop platforms. The main entrypoint is [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart), which initializes Supabase, the local notification service, the Drift database, repositories, and the root `MaterialApp`.

## Core Modules

- `lib/main.dart`
  Bootstraps platform services, desktop window management, and the system tray on Windows/macOS/Linux.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  A heavy task-editing surface that combines title/description inputs, reminder controls, subtask tree, checklist, attachments, and AI decomposition in one scrollable page. Heavy child sections (SubtaskTreeSection, ChecklistSection, AttachmentSection, AiDecomposeSection) are wrapped in `RepaintBoundary` to isolate repaints. `BlocListener` uses `listenWhen` to avoid unnecessary setState on unrelated BLoC changes.
- `lib/services/notification_service.dart`
  Centralizes reminder scheduling. It uses timers to trigger reminders and dispatches platform-specific notifications.
- `lib/core/desktop/desktop_runtime.dart`
  Holds desktop-only runtime decisions used by the app, including tray event mapping and desktop notification channel selection.
- `lib/presentation/widgets/create_schedule_dialog.dart`
  Schedule creation/edit dialog, including reminder settings UI.
- `lib/presentation/pages/task/task_detail_page.dart`
  Legacy task detail page with reminder settings UI.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  Task detail page in the newer tasks area, also with reminder settings UI.

## Data Flow

1. `main()` initializes Supabase, `NotificationService`, the Drift database, and repositories.
2. UI actions in pages such as `HomePage` create or update schedules/tasks.
3. Reminder settings are passed into `NotificationService.scheduleReminderForSchedule(...)`.
4. `NotificationService` creates timers for future reminders.
5. When a timer fires on desktop:
   - Windows now prefers the native Windows notification plugin path.
   - If the Windows native path is unavailable, the service falls back to the existing PowerShell toast script.
   - macOS and Linux continue to use shell-based native notification commands.
6. On desktop, tray icon events are routed through `desktop_runtime.dart`, then handled in `main.dart` to show the window or open the tray context menu.

## Mobile Performance Notes

- The newer task detail page keeps many editing and data sections in a single `ListView`.
- Text edits in that page eventually flow through `TaskDetailPage._saveTask()` into `TaskNewBloc._onUpdateTask()`, which performs repository writes and then reloads task data.
- During this task, text-input dirty tracking on that page was adjusted so typing no longer schedules the debounced save pipeline on every pause. Text changes are now saved when editing completes, focus leaves the field, or the page closes.

## Local Android Debugging Status

- Flutter and the Android SDK are installed on this machine and `flutter doctor -v` reports the Android toolchain as healthy.
- `E:\android-sdk\platform-tools\adb.exe` exists locally.
- At inspection time there were no connected Android devices, `flutter emulators` found no AVD images, and `adb` was not on the shell `PATH`.
- Result: this computer can support Android debugging after either connecting a device or creating an emulator and, ideally, adding platform-tools to `PATH`.

## Dependencies Relevant To This Change

- `flutter_local_notifications`
  Cross-platform notification API already used by the project. Updated to `^19.5.0`.
- `flutter_local_notifications_windows`
  Added to provide a native Windows desktop notification implementation.
- `system_tray`
  Used for the desktop tray icon and context menu.
- `window_manager`
  Used to show, focus, and destroy the desktop window.

## Important Implementation Decisions

- Windows desktop reminders are no longer limited to the PowerShell toast fallback. The app now prefers the native Windows notification plugin path when available.
- Tray menu visibility is controlled explicitly from tray events. Right-click popup behavior is mapped in `desktop_runtime.dart` and executed in `main.dart`.
- Reminder UI sections use taller `SwitchListTile` layouts (`isThreeLine: true`) in the affected desktop surfaces to reduce bottom overflow risk on shorter windows.

## 2026-05-27 批量优化 — 新增模块

### 数据模型（Drift v5）

- `Projects.groupId`：可空，指向 `ProjectGroups.id`
- 新表 `ProjectGroups(id, name, color, sortOrder, createdAt, updatedAt)`
- `Tasks.estimatedMinutes`：可空，AI 估时分钟数
- onUpgrade(4→5)：addColumn + createTable

### 云同步（Supabase）

- 新表 `projects`、`project_groups`（含 user_id + RLS）。SQL 见 `database/migration_002_groups_and_estimate.sql`
- 已有 `user_tasks` 加 `estimated_minutes` 列
- 新 `ProjectSyncService` (`lib/services/project_sync_service.dart`)：仿 `TaskSyncService` 结构，pull/push/subscribe，绑定 `ProjectRepository` 与 `ProjectGroupRepository` 的写操作
- `home_page` 初始化时 `pullAll()` + `subscribe()`，登录用户共享 projects/groups

### AI 拆分排程

- 输入：父任务（含描述 / 附件）；AI 端只产 WBS + 叶子 minutes
- 排程：`SubtaskScheduler`（`lib/services/subtask_scheduler.dart`）
  - 9:00–21:00 工作时段、5 分钟吸附、15 分钟缓冲、避让已有 task 的 `[start, due]`
  - `skipWeekends` 来自 `LocalStorage`
  - 不允许单段跨日，当日剩余不够则整段推次日
- 父任务跨天回写：`computeParentSpans` → `startOfDay(minLeafStart)` 到 `endOfDay(maxLeafEnd)`，被 `_isMultiDayTask` 识别为顶部长条

### 日历拖动重写

- 抛弃 `Draggable` / `DragTarget`，改 `Listener` + 状态机：
  - `onPointerDown` 记录起点
  - `onPointerMove` 累积 delta → `Transform.translate` 保持原尺寸跟手
  - `onPointerUp` 把 delta 换算为 5 分钟吸附时间 + dayWidth 列偏移，调 `_moveTask` / `_resizeTaskStart` / `_resizeTaskEnd`
- 多日 bar 同样改写，按 `dayWidth` 计算整天偏移
- 移动端 resize hot zone (`_ResizeHotZone`) 仍 36px 高度但去 `Draggable` 后获得手势优先权
- 父任务长条 lane 自适应：按层级深度排序（根上），lane 数动态，>6 时容器固定高度内部纵向滚动
