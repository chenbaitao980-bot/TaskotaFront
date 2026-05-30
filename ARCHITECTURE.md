# Architecture

> 2026-05-30: 多主题切换。`lib/core/theme/app_theme.dart` 抽出 `AppPalette` 调色板模型（全部颜色 token + `ThemeData build()`），三套实例 `claude`(默认暖珊瑚)/`auroraBlue`(Google Material 3 蓝)/`obsidian`(深色)。`AppTheme` 颜色由 `static const` 改为委托 `_current` 的 `static get`（对外名不变，全 App 653 处引用零改动；代价是 215 处 const 上下文去 const）。`lib/core/theme/theme_controller.dart` 的 `ThemeController`(ChangeNotifier，全局单例 `themeController`)负责持久化(SharedPreferences via `LocalStorageService.themeId`)+ 通知重建；`main.dart` 用 `ListenableBuilder` 包 `MaterialApp`，`themeMode` 随调色板亮/暗切换。选择页 `theme_settings_page.dart`，入口在 profile"主题"菜单。

> 2026-06-06: 四象限模块改为列溢出模式——每列最多 5 条，超出自动新开列，象限内 `SingleChildScrollView` 横向滚动，列间 1px 分隔线。移除硬上限截断 `q.removeRange(5)`、逾期横幅、`"N 逾期"` 提示，保留单条任务前逾期 `!` 图标。

> 2026-07-17: 修复思维导图点击空白处取消框选不生效。根因：取消框选的 `Listener` 原本放在 `InteractiveViewer` 内部 Stack，桌面端 `InteractiveViewer` 的 `ScaleGestureRecognizer` 拦截指针事件导致子级 `onPointerUp` 不触发。修复：将 `Listener` 移到 `InteractiveViewer` 外层 Stack（`_buildMindMapCanvas` 返回值），绕开手势竞技场。

> 2026-06-06: 思维导图增加桌面端 Ctrl+框选多节点功能。`_MindMapViewState` 新增 `_ctrlPressed`/`_selectedIds`/`_isSelecting` 状态，通过 `HardwareKeyboard` 监听 Ctrl 键，`Listener` 捕获指针事件绘制选择矩形。`_SelectionRectPainter` 绘制半透明选择框。选中后拖拽时 `onDragUpdate` 对 `_selectedIds` 内所有节点应用相同位移。

> 2026-05-30: 首页新增统计卡片（今日任务数/完成率/逾期数），详见「首页统计卡片」
> 2026-05-30: Realtime DELETE 回调增加墓碑保护，防止历史删除事件回放导致子任务消失

## Overview

`smart_assistant` is a Flutter application with shared UI code for mobile and desktop platforms. The main entrypoint is [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart), which initializes Supabase, the local notification service, the Drift database, repositories, and the root `MaterialApp`.

## Core Modules

- `lib/main.dart`
  Bootstraps platform services, desktop window management, and the system tray on Windows/macOS/Linux.
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
  A heavy task-editing surface that combines title/description inputs, reminder controls, subtask tree, checklist, attachments, and AI decomposition in one scrollable page. Heavy child sections (SubtaskTreeSection, ChecklistSection, AttachmentSection, AiDecomposeSection) are wrapped in `RepaintBoundary` to isolate repaints. `BlocListener` uses `listenWhen` to avoid unnecessary setState on unrelated BLoC changes.
- `lib/services/holiday_service.dart`
  节假日数据服务。中国优先用 `timor.tools/api/holiday/year/{year}`（含法定假日 + 调休补班），失败或返回空时回退 `date.nager.at/api/v3`（CN，仅法定假日）；其他国家用 `date.nager.at/api/v3`。结果以 `Map<"yyyy-MM-dd", HolidayInfo>` 形式返回，并用 `SharedPreferences` 缓存 7 天，断网时降级读过期缓存。支持 `HolidayCountry`（中/美/日/英/韩）枚举，用户选择持久化。
- `lib/services/notification_service.dart`
  Centralizes reminder scheduling. Android/iOS 端用 `zonedSchedule`（系统 AlarmManager），进程死亡后系统仍可触发；桌面端保留 Timer。需 `timezone` 包初始化（`tz.initializeTimeZones()`）。
- `lib/services/permission_service.dart`
  运行时通知权限申请封装（Android/iOS），`showNotificationGuideIfNeeded` 在首次启动时弹出引导 dialog，`SharedPreferences` 防重复。
- `lib/core/desktop/desktop_runtime.dart`
  Holds desktop-only runtime decisions used by the app, including tray event mapping and desktop notification channel selection.
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
  思维导图任务视图。用 InteractiveViewer + Stack + Positioned 实现水平树形布局，CustomPaint 绘制贝塞尔曲线连接线。每个节点是完整的交互卡片（Draggable + DragTarget + Slidable）。通过 BLoC state 的 `viewMode` 字段切换列表/导图视图。
  **自由拖拽模式**：`_freeDragMode` 状态控制，节点用 `GestureDetector.onPanDown/onPanUpdate/onPanEnd/onPanCancel` 自由拖动（`onPanDown` 比 `onPanStart` 更早触发以尽早禁用画布平移，`onPanCancel` 清理状态防止残留）；坐标钳制 `dx>=0/dy>=6` 防止越出画布无法命中。`InteractiveViewer.panEnabled = !_nodeDragging`：拖节点期间禁用画布平移，避免画布整体联动；空闲时仍可平移/缩放。+ 按钮用 `HitTestBehavior.opaque` + 28×28 热区避免手势竞技场吞事件。
  **性能优化 (2026-06-04)**：布局结果缓存在 `_cachedPendingNodes/Lines/CanvasSize` 中，`initState`/`didUpdateWidget` 中一次性计算，`build()` 直接读缓存。拖拽用 `ValueNotifier<Offset>` 每节点独立 + `ValueListenableBuilder`，只重建被拖节点。连线层用 `AnimatedBuilder` + `Listenable.merge` 监听所有 notifier，只重绘 `CustomPaint`。每个节点外包 `RepaintBoundary`。已移除 `_lineAnimController` 动画。
- `lib/presentation/pages/home/home_page.dart`
  首页。`_HomeContent` 自上而下：问候语 → **统计卡 `_buildStatsCard`** → 项目筛选 → 时间轴 → 任务详情卡 → 四象限。统计卡（2026-05-30）三项：今日任务数 / 完成率(`完成/总`，周期 `_statsPeriod` 可切日周月年，由 `_periodRange` 取 `[start,end)`) / 逾期数。全部基于内存 `_filteredTasks` 按 `_TimelineTask.date` 计算、尊重项目筛选、随 `_loadData` 刷新，无新增数据层。逾期数可点 → `_showOverdueSheet` 底部弹窗 → 点任务复用 `_selectTask`（时间轴切换 + 详情卡展开）。任务详情卡末尾新增「资源区」（2026-05-30）：左列 `AttachmentSection`、右列 `ChecklistSection`，通过 `_dbTaskCache`（懒加载 Task 对象）和六个 `_home*` 方法对接 `ChecklistRepository`，仅 `source=='db'` 任务显示。
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
7. Windows 单实例保护通过 `main.cpp` 中的 Named Mutex 实现，第二个实例激活已有窗口后退出。

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

## UI 工具层

- `lib/core/utils/snackbar_helper.dart`：全局 `showAppSnackBar(context, message)` — 所有提示消息统一使用此函数，内置点击消失功能（GestureDetector + hideCurrentSnackBar）。

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

### 全业务数据双端同步（软删除墓石 + 双向 LWW，2026-05-29）

- **墓石软删除**：`Tasks/Projects/ProjectGroups/ChecklistItems` 及对应云表（`user_tasks/projects/project_groups/checklist_items`）均含 `deleted`（0/1）。删除一律 `deleted=1, updatedAt=now` 并推送，不物理删除；所有读查询过滤 `deleted=0`。删除靠墓石跨端传播、重启不复活。schemaVersion=7。
- **双向 LWW 对账**：`{Task,Project,Checklist,Attachment}SyncService.syncAll()` = 拉云端（含墓石）合并本地（仅当 remote `updatedAt` 更新才覆盖）+ 本地（含墓石，`getAllRaw()`）凡云端缺失或本地更新则 upsert 上云。不依赖 Realtime 即可补齐子任务树与传播删除；Realtime 仅作加速。
- **checklist 上云**：新 `ChecklistSyncService` + 云表 `checklist_items`（RLS `auth.uid()=user_id` + REPLICA IDENTITY FULL + 在 supabase_realtime publication）。`ChecklistRepository` 注入 syncService，增删改 push + `syncFromJson`。
- **级联**：project 软删 → 级联软删其下 tasks/checklist；远端项目墓石到达 `_upsertProjectFromRow` 时本地同样级联。
- **启动门控**：`home_page` 所有 `syncAll()+subscribe()` 仅在 Supabase 登录后启动，`signedIn/initialSession` 每次重跑全量对账（移除了未登录即触发的 task pull）。
- **清空**：`AppDatabase.wipeAllData()` 事务清空各表并重建 inbox；云端经 Management API 已清空。SQL 留痕 `database/migration_004_soft_delete_checklist_realtime.sql`。
- ⚠ 本地若未清空，下次启动 `syncAll` 会把旧数据反推回云端 —— 清空云端后须同步清空两端本地（关 App 后跑 `clear_data.bat` / 移动端卸载重装）。
- **syncFromJson 保留远端时间戳**：合并时写入远端 `updatedAt` 而非 `now`，避免下次对账反推旧数据覆盖云端。墓石保护：本地 `deleted=1` 且 `updatedAt>=远端` 时不被未删除状态覆盖。
- **Realtime 串行化**：`TaskSyncService._enqueue()` 串行执行 Realtime 回调的数据库操作，防止并发写入导致 SQLite `database is locked`。

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

### TaskNewBloc 状态保留规则（2026-05-31）

`_onLoadTasks` 在 emit `TaskNewLoading` 前从当前 `TaskNewLoaded` 保留以下字段，并在最终 `emit TaskNewLoaded` 时写回：
- `subTrees` / `expandedNodes`（已有）
- `viewMode`（新增，避免每次 LoadTasks 后回退为 'mindmap'）
- `dateFrom` / `dateTo`（新增，避免日期筛选丢失）

调用方传入的 `event.dateFrom`/`event.dateTo` 优先于保留值（`event.dateFrom ?? preservedDateFrom`）。`LoadTasks(clearDateRange: true)` 时强制把 `dateFrom/dateTo` 置 null（用于"清除日期筛选"，否则 `?? preserved` 会保留旧筛选导致清不掉）。
