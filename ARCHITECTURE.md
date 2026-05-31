# Architecture

> 2026-05-31: 本次修复保留现有 Drift `tasks.parentId` ↔ Supabase `user_tasks.parent_id` 逐行同步架构；`TaskNewBloc` 的任务同步入口改为调用 `TaskSyncService.syncAll()`，不再通过旧 `local_task_sync.tasks_data` JSON 路径同步任务树。`TaskSyncService` 暴露纯映射方法用于验证 `parent_id`/`parentId` 转换。中国节假日展示在 `HolidayService` 中增加 2026 年劳动节本地兜底覆盖，补齐 2026-05-01 至 2026-05-05 休息日和 2026-04-26、2026-05-09 补班日。移动端首页任务详情资源区保持同一数据来源，但窄屏下附件和检查项改为纵向分区展示；桌面端仍为横向布局。我的页退出登录由 `ProfilePage` 派发 `AuthBloc.LoggedOut`。

> 2026-05-31: 思维导图任务视图新增一次性“自动锁定”视角定位。`lib/presentation/pages/tasks/widgets/mind_map_view.dart` 复用 `TransformationController`，按当前可见节点的 `startDate ?? dueDate` 与当前时间距离选择最近任务，并在保持当前缩放比例的情况下平移画布到该节点中心；节点坐标使用 `_positionNotifiers`，因此支持手动拖动后的实际位置。

> 2026-05-31: 新增独立静态站点 `personal_admin_site/`，用于个人动态密钥、动态数据和 App 管理。站点由 `index.html`、`styles.css`、`app.js`、`config.js`、`config.example.js`、`supabase.sql` 和 `README.md` 组成，不接入现有 Flutter 应用运行时。前端通过 Supabase JS CDN 使用 Email OTP 登录；`supabase.sql` 定义 `allowed_users`、`dynamic_secrets`、`dynamic_data`、`managed_apps` 四张表，启用 RLS，并要求登录邮箱存在于 allowlist。密钥值在浏览器端使用 WebCrypto PBKDF2 + AES-GCM 加密后保存，口令不上传、不落库。推荐部署结构为 Cloudflare Pages 静态托管 + Supabase 免费层。

> 2026-05-31: `personal_admin_site/` 补充 Cloudflare Pages 发布配置和上线检查。`_headers` 定义静态站安全响应头；`DEPLOYMENT_PLAN.md` 记录 Cloudflare Pages + Supabase 免费层的 0 美元固定成本方案、官方依据链接和上线步骤；`deploy-check.ps1` 在发布前检查必要文件、阻止占位 Supabase 配置、阻止 `sbp_`/`service_role` 等敏感密钥进入前端，并执行 `node --check app.js`。

> 2026-05-31: `personal_admin_site/` 补充两种配置生成路径：Cloudflare Pages 仓库部署时执行 `build-cloudflare.sh`，从 `PUBLIC_SUPABASE_URL` 和 `PUBLIC_SUPABASE_ANON_KEY` 生成 `config.js`；本地 Direct Upload 前可执行 `build-local.ps1` 生成同样配置。根目录生成 `personal_admin_site_template.zip` 作为上传模板包，仍需真实 Supabase `anon public key` 替换后才能发布为可用站点。

> 2026-05-31: 首页任务详情卡的 DB 任务资源区由独立的“子任务在上、附件/检查项在下”结构调整为同一横向资源行：`_buildResourceRow` 在 `lib/presentation/pages/home/home_page.dart` 中并列承载子任务树、`AttachmentSection`、`ChecklistSection`，仍仅对 `source == 'db'` 任务显示。

> 2026-05-30: 多主题切换。`lib/core/theme/app_theme.dart` 抽出 `AppPalette` 调色板模型（全部颜色 token + `ThemeData build()`），三套实例 `claude`(默认暖珊瑚)/`auroraBlue`(Google Material 3 蓝)/`obsidian`(深色)。`AppTheme` 颜色由 `static const` 改为委托 `_current` 的 `static get`（对外名不变，全 App 653 处引用零改动；代价是 215 处 const 上下文去 const）。`lib/core/theme/theme_controller.dart` 的 `ThemeController`(ChangeNotifier，全局单例 `themeController`)负责持久化(SharedPreferences via `LocalStorageService.themeId`)+ 通知重建；`main.dart` 用 `ListenableBuilder` 包 `MaterialApp`，`themeMode` 随调色板亮/暗切换。选择页 `theme_settings_page.dart`，入口在 profile"主题"菜单。
> 2026-05-31: 我的模块补全。`profile_page.dart` 移除空的"提醒设置"菜单入口，"设置/帮助与反馈/关于"改为页面跳转。`app_settings_page.dart` 承载 AI 排程跳过周末开关（复用 `LocalStorageService.skipWeekends`）、主题入口、通知和数据说明；`help_feedback_page.dart` 记录任务管理、AI 拆解、日历提醒、主题切换、常见问题和反馈说明；`about_page.dart` 展示智能小管家、版本 `1.0.0+3`、核心能力、数据同步和隐私权限说明。

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

### 任务创建时间冲突处理（2026-05-31）

- `TaskCreateSheet` 在传入 `TaskRepository` 时对所有新建任务做时间冲突检测，弹窗支持取消、并行、自动延后、自动插入。
- 自动插入由 `SubtaskScheduler.autoInsert` 计算：以新任务原始时间段作为占用区间，只移动未完成、未删除且有开始/截止时间的既有任务；被移动任务保持原持续时长，按 09:00-21:00 工作时段和 15 分钟缓冲级联后移。
- `CreateTask.shiftedTasks` 携带自动插入产生的后移结果；`TaskNewBloc._onCreateTask` 先创建新任务，再逐条更新被后移任务的 `startDate`/`dueDate`，之后执行原有云同步和列表刷新。
- 任务页新建、任务详情子任务新建、日历时间轴新建均传递 `shiftedTasks` 到 `CreateTask`；日历创建入口同步传入 `TaskRepository` 以启用同样的冲突处理。

### 日历节假日与休息日展示（2026-05-31）

- `CalendarPage` 接入 `HolidayService`，按当前节假日国家与年份加载并缓存节假日数据。
- AppBar 提供节假日国家切换；切换后清空页面内节假日缓存并重新加载当前年份。
- 周视图日期头和月视图日期格展示调休补班、法定节假日、普通周末休息日；中国补班日优先于周末休息标记。
- `HolidayService` 对中国节日增加本地补充：妇女节、植树节、青年节、儿童节、建党节、建军节、教师节；这些使用 `HolidayType.observance`，只展示节日名，不按休息日处理。
# 2026-05-31 上线与变现准备文档

- 新增 `docs/launch/` 作为上线准备资料目录，不参与运行时构建，不改变 Flutter 业务代码。
- `PLATFORM_RESEARCH_CN.md` 记录中国大陆个人开发者的上线平台选择：首发建议 Windows 官网/私域分发 + 国内安卓渠道引流，暂缓 Google Play 和平台内购。
- `LAUNCH_CHECKLIST.md`、`RISK_REGISTER.md`、`RELEASE_EVIDENCE.md` 记录上线材料、风险和当前发布证据。
- `PRIVACY_POLICY_DRAFT.md`、`TERMS_OF_SERVICE_DRAFT.md`、`STORE_LISTING_COPY.md`、`PRICING_AND_GO_TO_MARKET.md` 记录隐私政策草案、用户协议草案、商店文案和定价/获客方案。
- 本次未更换 DeepSeek Key，未修改 Android 签名、包名、业务代码或构建脚本。

### 首页启动引导（2026-05-31）

- `HomePage` 启动后仍会调用 `PermissionService.showNotificationGuideIfNeeded` 做通知权限引导。
- `HomePage` 不再自动跳转 `OnboardingPage`，`LocalStorageService.onboardingCompleted` 不再参与首页启动导航判断。

### 子任务创建默认项目（2026-05-31）

- `TasksPage` 从任务树/思维导图父节点新增子任务时，创建弹窗的默认项目优先使用父任务 `projectId`，再回退当前项目筛选。
- `TaskCreateSheet` 在初始化和父任务下拉切换时，会按所选父任务同步 `_selectedProjectId`，确保子任务默认归属父任务项目。

### 首页任务详情移动端资源区（2026-05-31）

- `HomePage._buildResourceRow` 按可用宽度切换布局：桌面保持子任务/附件/检查项横排；窄屏下子任务单独一行，附件和检查项组成独立资源行。

### 任务删除跨端同步（2026-05-31）

- `TaskRepository.syncFromJson` 对远端 `deleted=1` 墓石使用 `updatedAt` 做 LWW：远端更新时覆盖本地活任务，本地更新时跳过过期墓石。
- `TaskSyncService.syncAll` 不再用本地活任务无条件覆盖云端墓石，避免重启全量对账时把另一端已删除的思维导图节点复活。
- `TaskSyncService` 增加 `changes` 广播；`HomePage` 监听任务同步变更并 debounce 触发 `LoadTasks`，让任务页/思维导图在远端新增、更新、删除后刷新。

### 手机验证码登录（2026-05-31）

- `SupabaseService` 封装 `signInWithOtp(phone: ...)` 发送短信验证码，封装 `verifyOTP(type: OtpType.sms)` 校验验证码并返回 Supabase 用户会话。
- `AuthBloc` 新增 `PhoneOtpRequested`、`PhoneOtpVerified`、`PhoneOtpSent`，手机号验证码登录成功后进入现有 `Authenticated` 状态。
- `LoginPage` 增加邮箱/手机验证码登录模式切换；手机号不带 `+` 且为中国大陆 11 位手机号时自动补 `+86`。

### 全局排除项目（2026-05-31）

- `LocalStorageService.excludedProjectIds` 使用 SharedPreferences 持久化排除项目 ID 列表。
- `TaskNewBloc._onLoadTasks` 在加载任务列表和计算进度前排除这些项目；被排除项目不进入任务页列表、思维导图和进度计算。
- `HomePage` 构建首页时间轴数据前排除这些项目，因此时间轴、统计和四象限均使用排除后的任务集合；首页项目筛选状态使用项目 ID 集合，计算按集合过滤，UI 保留快速单选下拉并提供多选弹窗入口。
- `CalendarPage` 加载日历任务时排除这些项目；日历项目筛选状态使用项目 ID 集合，菜单项可多选/取消。
- `TaskNewBloc` 的 `LoadTasks.projectIds` 与 `TaskNewLoaded.selectedProjectIds` 承载任务模块多项目筛选；任务页 AppBar 提供项目多选筛选入口和“排除项目”多选设置入口。

### 提醒通知（2026-05-31）

- `NotificationService` 负责本地提醒调度。移动端使用 `flutter_local_notifications` 的 `zonedSchedule`，调度前兜底请求通知权限；Android 同步请求精确闹钟权限，iOS 前台展示显式启用 alert/badge/sound。
- 桌面端仍用进程内 `Timer` 触发提醒；Windows 触发后改为 PowerShell `MessageBox` 常驻弹窗，用户点击 OK 前不会自动消失。
- `PermissionService.showNotificationGuideIfNeeded` 仍只在移动端首次展示通知权限引导；Android 确认后同时申请通知权限和精确闹钟权限。
