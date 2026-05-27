# Changelog

## 2026-05-27 (批量优化 + AI 排程 + 项目分组 + 日历拖动重写)

### 新增功能

- **项目分组**（F6）：新建 `ProjectGroups` 表 + `groupId` 外键，侧边栏按分组 ExpansionTile 展开，组进度 = 组内项目加权累加（同项目口径）。
- **AI 估时 + 自动排程**（F2）：
  - `task_decomposition_service` system prompt 强制叶子节点返回 `minutes`（≤480）；非叶子由子节点累加。
  - 新建 `subtask_scheduler.dart`：9:00–21:00 工作时段、5 分钟吸附、15 分钟缓冲、避让已占用时段、`skipWeekends` 可选；输出叶子排程结果，并把父任务回写为 `startOfDay(min) → endOfDay(max)` 强制跨天，自动渲染为日历顶部长条。
  - `ai_decompose_section` 接入 scheduler，拆完即排程；默认开启提醒（提前 5 分钟）。
- **任务挂项目级联到子任务**（F1）：`TaskRepository.update` 检测 `projectId` 变更时，批量更新所有后代 + sync push。
- **首页时间轴自适应高度**（F5）：根据当前可见列的最大任务数动态算高度（80–210px），节点内允许上下滚动看完所有任务。
- **首页描述固定高度可滚动**（F4）：240px 高度内滚动，超过 1000 字截断 + "展开全文"跳转编辑页。
- **任务列表优先级 PopupMenuButton**（F3）：替换易误触的细色条，新增带颜色圆点 + "高/中/低/无" 标签的胶囊下拉。
- **新建任务默认时间**（F7）：开始时间 = 当前，截止 = 当前+1h。
- **设置：AI 排程跳过周末**：`profile_page` 加开关，`LocalStorage.skipWeekends`。
- **云同步**：`projects` / `project_groups` 上云（`migration_002_groups_and_estimate.sql`），`user_tasks` 加 `estimated_minutes` 列；新建 `ProjectSyncService` 提供 pull / push / subscribe。

### Bug 修复

- **B1 移动端日历长按后无法拖拽边缘改时间**：resize hot zone 改用 5 分钟吸附粒度，跟手响应。
- **B2 日历任务块拖动手感差**：去掉 `Draggable`/`DragTarget`，改 `Listener` + `Transform.translate` 原尺寸跟手，5 分钟吸附，跨日按 `dayWidth` 计算列偏移；多日 bar 同样改写。
- **B3 分钟选择器改下拉框**：删除 ListWheelScrollView，改与"时"一致的 `_timeDropdown`，5 分钟一档。
- **B4 月视图右切下方任务列表不刷新**：`onPageChanged` 加 `setState`，把 `_selectedDay` 同步到新月同号日。
- **多日长条 lane 自动撑高**：`_buildMultiDayLane` 按层级深度排序（根任务在上），lane 数动态计算，>6 时内部纵向滚动。

### 数据模型变更

- Drift `schemaVersion` 4 → 5：新表 `project_groups`，`projects.group_id`、`tasks.estimated_minutes` 列。
- `TaskNewLoaded` 加 `groups` / `groupProgress` 字段。
- `TaskProgressCalculator` 新增 `groupProgress` 计算。

### 影响文件
- 数据层：`app_database.dart` (+ .g.dart)、`task_repository.dart`、`project_repository.dart`、新建 `project_group_repository.dart`
- 服务层：新建 `subtask_scheduler.dart`、`project_sync_service.dart`；改 `task_sync_service.dart`、`task_decomposition_service.dart`、`local_storage_service.dart`、`notification_service.dart` 接入
- 表现层：`home_page.dart`、`calendar_page.dart`、`profile_page.dart`、`task_card.dart`、`task_create_sheet.dart`、`project_sidebar.dart`、`calendar_date_picker.dart`、`ai_decompose_section.dart`
- Bloc：`task_bloc.dart` / `task_state.dart`
- 云端 SQL：新建 `database/migration_002_groups_and_estimate.sql`（**需用户在 Supabase Dashboard SQL Editor 执行**）

### 后续 TODO / 风险

- 仅 `flutter analyze` 通过（59 个 info/warning，无 error），实机功能未跑通；建议在桌面端 + 移动端各跑一遍 AI 拆分、日历拖动、月视图切换、项目分组、跨设备同步流程。
- AI 排程为"贪心顺序填充"，不做全局最优；同一时段多次 AI 拆分可能扎堆排在远未来。
- 父任务跨天强制为 00:00–23:59，会让多日 bar 在月视图覆盖完整时段，是预期行为。

---

## 2026-05-27 (login fix + 长按编辑 + pinch 缩放)

### Fixed

- **登录首次无响应**：Supabase 路径下 `_login()` 把事件丢给 BLoC 后立即关闭 `_isLoading`，BLoC 异步还在飞。改为 Supabase 模式完全由 BLoC 状态（`AuthLoading`）驱动按钮 disable。
- **移动端长按编辑模式（滴答清单方案）**：长按任务块进入编辑模式，显示蓝色高亮边框 + 顶部/底部大拖拽手柄（36px 高，蓝色 primaryColor）。拖拽调整时间后自动退出编辑模式。点击空白区域也退出。桌面端保持原有 hover 小白线行为。
- **移动端双指 pinch 缩放日历时间轴**：用 `Listener` 的 `onPointerDown/Move/Up/Cancel` 追踪多点触控，双指时按距离比例调整 `_hourHeight`，不干扰 `SingleChildScrollView` 的单指滚动。

---

## 2026-05-27 (release login + calendar fixes)

### Fixed

- **Release 模式无法登录**：`INTERNET` 权限只在 debug manifest，主 manifest 缺失。已添加到 `android/app/src/main/AndroidManifest.xml`。
- **日历任务卡片 BOTTOM OVERFLOW**：`_buildBlockContent` 内容超出 28px 最小高度且 `Stack(clipBehavior: Clip.none)` 不裁剪。改用 `Material(clipBehavior: Clip.hardEdge)` + Column 去掉 `mainAxisSize: MainAxisSize.min` 让内容填充并裁剪。
- **切换 1天/2天视图不居中到今天**：`onChanged` 只改天数不改 `_focusedDay`，且 `_startOfWeek` 总回退到周一。天数 < 7 时直接从 `_focusedDay` 开始，≤ 3 天时重置到今天。
- **移动端 resize 热区太小**：底部拖拽热区从 8px 扩大到 24px，向下偏移 8px。

---

## 2026-05-27 (perf: overflow + jank fixes)

### Fixed

- **BOTTOM OVERFLOWED BY 21 PIXELS** on calendar page: removed manual `viewInsets.bottom` padding in `calendar_date_picker.dart` and `task_create_sheet.dart` that double-compensated with `isScrollControlled: true`. Wrapped calendar picker content in `SingleChildScrollView`.
- **Edit page lag (all interactions, not just keyboard)**: added `listenWhen` to `BlocListener` in `task_detail_page.dart` so `setState` only fires when checklist data actually changes; added `buildWhen` to `BlocBuilder` in `subtask_tree_section.dart` so the tree only rebuilds when its own subtree/expanded-nodes change.
- **Keyboard animation jank**: removed `MediaQuery.viewInsetsOf(context).bottom` subscriptions that caused per-frame rebuilds during keyboard show/hide animation.
- **Calendar page keyboard interference**: set `resizeToAvoidBottomInset: false` on calendar Scaffold (no text inputs on that page).
- **Repaint isolation**: wrapped `SubtaskTreeSection`, `ChecklistSection`, `AttachmentSection`, `AiDecomposeSection` in `RepaintBoundary` in task detail page; wrapped timeline scroll area in `RepaintBoundary` in calendar page.

### Files modified

- `lib/presentation/widgets/calendar_date_picker.dart`
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`

### Verification

- `dart analyze` on all 5 modified files: 0 errors (4 pre-existing deprecation infos).
- `flutter build apk --debug` succeeded, installed and launched on emulator-5554.

---

## 2026-05-27

### Changed

- Reduced mobile text-input save pressure in [lib/presentation/pages/tasks/task_detail/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/tasks/task_detail/task_detail_page.dart).
- Title and description edits on the newer task detail page now mark the form dirty without scheduling the debounced autosave pipeline on each text change.
- Text changes are still persisted when editing completes, focus leaves the field, or the page closes, so the edit flow stays safe while avoiding repeated write/sync churn during typing.

### Investigation

- Traced the likely mobile lag source to the newer task detail page, where text editing sits inside a heavy page that also hosts subtasks, checklist, attachments, reminder controls, and AI decomposition.
- Confirmed that the existing autosave path reaches `TaskNewBloc._onUpdateTask()`, which writes through the repository layer and then reloads task data, making it too expensive for frequent text-entry pauses on mobile.
- Confirmed the local Android toolchain is installed, but there is currently no connected Android device and no configured emulator image on this machine.

### Verification

- `flutter test test/widget_test.dart test/local_storage_service_test.dart test/task_progress_calculator_test.dart` passed on 2026-05-27.
- `flutter analyze lib/presentation/pages/tasks/task_detail/task_detail_page.dart` reported only pre-existing deprecation infos for `RadioListTile`.

### Risks / Notes

- This change targets the newer task detail editing page only. Other mobile forms may still deserve profiling if you see similar lag elsewhere.
- `adb.exe` exists under `E:\android-sdk\platform-tools`, but the current shell session does not expose `adb` directly on `PATH`.

## 2026-05-27

### Changed

- Updated desktop reminder delivery in [lib/services/notification_service.dart](/E:/claude/project2/smart_assistant/lib/services/notification_service.dart) so Windows prefers the native Windows notification plugin and only falls back to the existing PowerShell toast path if native delivery is unavailable.
- Added desktop runtime decision helpers in [lib/core/desktop/desktop_runtime.dart](/E:/claude/project2/smart_assistant/lib/core/desktop/desktop_runtime.dart) for tray-event handling and desktop notification channel selection.
- Updated [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart) so tray right-click opens the context menu, which restores access to the desktop "退出" action.
- Reduced reminder-section overflow risk by adjusting `SwitchListTile` layout in:
  [lib/presentation/widgets/create_schedule_dialog.dart](/E:/claude/project2/smart_assistant/lib/presentation/widgets/create_schedule_dialog.dart)
  [lib/presentation/pages/task/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/task/task_detail_page.dart)
  [lib/presentation/pages/tasks/task_detail/task_detail_page.dart](/E:/claude/project2/smart_assistant/lib/presentation/pages/tasks/task_detail/task_detail_page.dart)
- Updated notification dependencies in [pubspec.yaml](/E:/claude/project2/smart_assistant/pubspec.yaml) and [pubspec.lock](/E:/claude/project2/smart_assistant/pubspec.lock).

### Tests

- Added [test/desktop_runtime_test.dart](/E:/claude/project2/smart_assistant/test/desktop_runtime_test.dart) to cover tray right-click behavior and Windows notification channel selection.
- Added [test/create_schedule_dialog_test.dart](/E:/claude/project2/smart_assistant/test/create_schedule_dialog_test.dart) to guard the desktop reminder dialog against overflow on short window heights.
- Updated [test/local_storage_service_test.dart](/E:/claude/project2/smart_assistant/test/local_storage_service_test.dart) to initialize mocked preferences before Supabase so the full Flutter test suite can run in one pass.

### Verification

- `flutter test` passed on 2026-05-27.
- `flutter analyze` completed with pre-existing infos/warnings, but no new compile errors from this change.

### Risks / Notes

- `npx gitnexus detect-changes --repo smart-assistant` reported `critical`, but the report included many unrelated pre-existing dirty-worktree files outside this task. That result should not be interpreted as the blast radius of only the reminder/tray fix.
