# Changelog

## 2026-05-30 (日历周视图：滑动时头部日期与下方网格同步)

### 优化
- 原因：周视图左右拖动切换日期时，仅下方 body（时间列+网格+任务块）跟手平移，顶部"星期+日期"头部不动，导致两者横向错位、视觉脱离
- `lib/presentation/pages/calendar/calendar_page.dart`：
  - `_buildDayStripHeader` 的"星期+日期"行外层包裹 `ClipRect` + `Transform.translate(offset: Offset(_dragOffset, 0))`，复用 body 同款 `_dragOffset`，使头部与下方网格列拖动过程中横向同步平移
  - 月份导航行（`< 年月 >`）保持固定，不参与平移
- 影响：仅头部渲染包装，未改 `_dragOffset` 赋值/拖动回调/吸附切换逻辑；月视图、纵向滚动、缩放、任务块拖拽均不受影响
- 风险：低

## 2026-05-30 (首页任务详情：新增资源区)

### 新增
- 原因：首页任务详情卡的检查项区域仅为只读预览（最多5条），且无附件入口，无法在首页直接操作
- `lib/presentation/pages/home/home_page.dart`：
  - 新增 `_dbTaskCache`（`Map<String, Task?>`）缓存 DB Task 对象，供 `AttachmentSection` 使用
  - 新增 `_loadDbTask` / `_homeToggleChecklist` / `_homeDeleteChecklist` / `_homeEditChecklist` / `_homeAddChecklist` / `_homeSetObsidianUri` 六个方法，对接 `ChecklistRepository` CRUD
  - 新增 `_buildResourceSection` / `_buildAttachmentWidget` / `_buildChecklistWidget`：左右两列布局，左列复用 `AttachmentSection`，右列复用 `ChecklistSection`（支持勾选/添加/双击编辑/长按 Obsidian 关联）
  - 删除只读的 `_buildChecklistPreview` 方法
  - `_buildTaskDetail` 底部替换为资源区，仅对 `source == 'db'` 任务显示
- 风险：低；附件/检查项依赖已有 service/repo，行为与任务详情页完全一致；时间轴行高不受影响

## 2026-07-17 (思维导图：修复点击空白处取消框选不生效)

### 修改
- 原因：原有 `Listener` 放在 `InteractiveViewer` 内部 Stack 底层，桌面端 `InteractiveViewer` 的 `ScaleGestureRecognizer` 拦截指针事件，导致子级 `Listener.onPointerUp` 收不到 → 点击空白处无法清空 `_selectedIds`
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`：
  - 删除 Stack 内层的 `Positioned.fill` + `Listener`（含 debugPrint）
  - 在 `_buildMindMapCanvas` 的外层 Stack 中，用 `Listener`（`HitTestBehavior.translucent`）包裹 `InteractiveViewer`，同样逻辑：pointerDown 记录位置，pointerUp 距离 <8px 且 `_selectedIds` 非空则清空
  - 外层 Listener 不阻塞子级手势（拖拽节点、Ctrl+框选、平移画布均正常）
- 风险：低，仅改变 Listener 层级位置，行为逻辑不变

## 2026-05-30 (思维导图：点击空白处取消框选)

### 修改
- 原因：Ctrl+左键框选节点后，松开 Ctrl 选中高亮持续保留，无手势可清空，体验上"无法取消"
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`：
  - `canvasContent()` 的 `Stack` 最底层新增全屏背景 `Listener`（`HitTestBehavior.translucent`），`onPointerUp` 时若按下到抬起位移 <8px 且 `_selectedIds` 非空则清空并 `setState`
  - 新增字段 `_bgPointerDownPos` 记录按下位置，用于区分"点击"与"平移"
  - 改用 `Listener`（绕过手势竞技场）而非 `GestureDetector.onTap`：后者作为 `InteractiveViewer` 子节点时空白处 tap 会被其缩放识别器抢走，导致首版无效
- 风险：低，未改动现有框选/拖拽/键盘逻辑；平移仍正常（位移>8px 不触发清空）

## 2026-07-15 (日历周视图拖拽改为 Transform 跟手平移)

### 修改
- 原因：拖拽不跟手——阈值方式不提供视觉反馈，桌面鼠标 delta 大时一次跳多天
- `lib/presentation/pages/calendar/calendar_page.dart`：
  - 新增 `_dragOffset` / `_cachedDayWidth` 字段
  - `_buildWeekTimeline`：`GestureDetector` + `Transform.translate` 包裹多日栏+时间线，`_dragOffset` 驱动平移
  - `_onCalendarHorizontalDragUpdate`：累加 `details.delta.dx` 到 `_dragOffset` + `setState`
  - `_onCalendarHorizontalDragEnd`：`-(_dragOffset / _cachedDayWidth).round()` 算天数偏移 → 更新 `_focusedDay` → 归零 `_dragOffset`

## 2026-05-30 (多主题切换：极光蓝 + 曜石黑)

### 新增
- 原因：原仅一套写死的 Claude 暖珊瑚色主题，profile"主题"菜单为空壳（`onTap: () {}`）；需在默认主题外增加两套大厂标准可切换主题
- 重构 `lib/core/theme/app_theme.dart`：抽出 `AppPalette` 调色板模型（持有全部颜色 token + `ThemeData build()`），定义三套实例 `claude`/`auroraBlue`（Google Material 3 蓝）/`obsidian`（深色模式）；`AppTheme` 颜色 token 由 `static const` 改为委托 `_current` 调色板的 `static get`，对外 API 名不变，653 处引用零改动
- 新增 `lib/core/theme/theme_controller.dart`：`ThemeController`（ChangeNotifier）持久化 + 通知重建，全局单例 `themeController`
- 新增 `lib/presentation/pages/profile/theme_settings_page.dart`：三张预览卡选择页，实时切换
- `lib/services/local_storage_service.dart`：新增 `_themeKey`/`themeId`/`setThemeId`（SharedPreferences 持久化）
- `lib/main.dart`：`main()` 加 `await themeController.load()`；`MaterialApp` 外包 `ListenableBuilder`，`theme/darkTheme: AppTheme.themeData`，`themeMode` 随当前调色板亮/暗切换
- `profile_page.dart`：主题菜单接入 `Navigator.push` 到设置页
- 影响：因颜色 token 由 const 变 getter，215 处 const 上下文引用（25 文件）去除 `const`（脚本批量 + 5 处 const 列表字面量手工改 final）
- 风险：去 const 后产生 ~89 个 `prefer_const` info 级提示（非致命）；曜石黑深色下个别写死 `Colors.white/black` 处需目检对比度；切换页一次性计算，性能影响可忽略

## 2026-05-30 (个人中心统计卡真实数据)

### 修改
- 原因：个人中心"总任务/完成率/连续"为写死的 128/78%/15天，需按真实任务数据渲染
- `ProfilePage` 增加 `taskRepository` 可空参数；`_init()` 中拉取 `getAll()` 计算总任务数、完成率（status==2 占比四舍五入）、连续天数（按 `completedTime` 本地日期连续回溯，今日未完成则从昨日起算）
- `_buildStatsSection` 用 `_total/_completionRate/_streak` 替换写死值
- `home_page.dart` 将 `const ProfilePage()` 改为传入 `widget.taskRepository`
- 文件：lib/presentation/pages/profile/profile_page.dart, lib/presentation/pages/home/home_page.dart
- 风险：`taskRepository` 为空时统计显示 0；切换到"我的"页时一次性计算，新增/完成任务后需重进该页刷新

## 2026-06-06 (四象限列溢出 + 去逾期提示)

### 修改
- 移除 `_buildQuadrantChart` 中 `q.removeRange(5, q.length)` 硬上限截断
- 移除顶部 `"N 个任务已逾期"` 红色横幅及 `overdueCount` 变量
- 移除 `_buildQuadrant` 底部 `"N 逾期"` 红色文字
- 重写 `_buildQuadrant`：任务按每列 5 条分片，多列 `SingleChildScrollView` 横向滚动，列间 1px 分隔线，移除 `tasks.take(4)` + `"+N 更多"`
- 文件：lib/presentation/pages/home/home_page.dart

## 2026-06-06 (思维导图 Ctrl+框选多节点功能)

### 修复
- 负坐标节点再拖动→全联动：画布尺寸 `abs()` → 恢复原始正向扩展，避免 InteractiveViewer 重调 viewport
- 节点所有方向自由拖拽：移除 `clamp(0,∞)` / `clamp(6,∞)` 限制
- Ctrl+框选重写：`ValueNotifier<_ctrlPressed>` + `ValueListenableBuilder` + `IgnorePointer` 即时切换架构；`GestureDetector` overlay 拦截框选手势
- 选中节点蓝色边框高亮 + Esc 清除选中
- 文件：lib/presentation/pages/tasks/widgets/mind_map_view.dart

## 2026-06-06 (思维导图手势修复 + 首页统计优化)

### 修复
- 思维导图节点上拖后"+"按钮点不动：`_MindMapNodeCard` 自由拖拽模式 GestureDetector 改用 `onPanDown`（比 `onPanStart` 更早触发，设 `_nodeDragging=true`）+ 新增 `onPanCancel` 清理。+ 按钮加 `HitTestBehavior.opaque` + 热区 28×28。
- 拖重叠节点导致整棵树一起拖动：同上，`onPanDown` 替代 `onPanStart` 确保 InteractiveViewer 的 pan 在 hit test 阶段被禁用，`onPanCancel` 防止 `_nodeDragging` 残留。

### 优化
- 首页"下午好"与统计卡片（今日任务/完成率/逾期）合并为同一行 Row 布局，统计卡片改为紧凑 inline 样式，点击可展开完整详情（含周期切换）。
- 周期切换移至详情弹窗内，主页面仅显示当前周期数据。

## 2026-05-30 (任务模块 6 项 Bug 修复)

### 修复
- 日期筛选清除失效：`LoadTasks` 新增 `clearDateRange`，`task_bloc._onLoadTasks` 清除时强制把 `dateFrom/dateTo` 置 null（原 `?? preservedDateFrom` 会保留旧筛选导致清不掉、无法重设）。`tasks_page` 清除分支传 `clearDateRange: true`。
- 节假日不显示：`holiday_service._fetchChina` 数据源 `timor.tools` 已不可达，失败/空结果时回退 `date.nager.at`（CN，仅法定节假日，无调休补班）。
- 子任务时间冲突检测仅思维导图入口生效：详情页 `subtask_tree_section._showAddSubTaskDialog` 原为纯标题对话框、无时间无检测，改为复用 `TaskCreateSheet`（含开始/截止时间 + `_checkConflict` 冲突检测），返回后派发 `CreateTask(parentId)` 并刷新子树。
- 思维导图节点上拖后"+"点不动：`mind_map_view` `onDragUpdate` 钳制节点坐标 `dx>=0/dy>=6`，防止越出画布 `SizedBox` 导致 `Clip.none` 溢出区无法命中。
- 拖单个节点整片画布联动：新增 `_nodeDragging` 标记，节点拖拽期间 `InteractiveViewer.panEnabled = !_nodeDragging`，避免画布平移与节点拖拽同时触发（撤销上一版"恒为 true"的判断）。

### 修改
- `tasks_page.dart`：移除 AppBar 右上角"新建项目"按钮（抽屉内入口保留）。

---

## 2026-05-30 (画布拖动修复 + 子任务时间冲突检测)

### 修复
- `mind_map_view.dart`：`InteractiveViewer` 的 `panEnabled` 由 `!_freeDragMode`（= false）改为 `true`，恢复画布自由平移。Flutter 手势竞技场自动处理节点拖拽与画布拖拽的优先级，不需要手动关闭。

### 新增
- `task_create_sheet.dart`：新增 `TaskRepository? taskRepository` 可选参数。当创建子任务（`initialParentId != null`）时，`_submit` 在提交前查询已有任务时间段，检测区间重叠，弹冲突提示弹窗，支持三种处理方式：并行（保持原时间）、取消、自动延后（利用 `SubtaskScheduler` 计算下一空闲时段）。

### 修改
- `tasks_page.dart`：`_showCreateTaskSheet` 传入 `taskRepository` 给 `TaskCreateSheet`
- `calendar_page.dart`：`_showCreateTaskSheet` 传入 `taskRepository` 给 `TaskCreateSheet`

### 风险
- 自动延后使用 `SubtaskScheduler`，工作时段限定 09:00–21:00；若所有时段已满（理论极端情况），返回 null，此时保持原时间创建

## 2026-05-30 (手机端任务提醒可靠性修复 + 权限引导)

### 修复
- Android/iOS 端提醒改用 `zonedSchedule`（系统 AlarmManager），不再依赖 Flutter 进程存活；App 被杀/后台后通知仍可触发
- 移除 Android/iOS 分支的 Timer 路径；桌面端保留 Timer

### 新增
- `AndroidManifest.xml`：添加 `RECEIVE_BOOT_COMPLETED` 权限 + `ScheduledNotificationBootReceiver`，重启后自动恢复已调度通知
- `lib/services/permission_service.dart`：封装运行时通知权限申请（`requestNotificationPermission`）+ 首次启动引导 dialog（`showNotificationGuideIfNeeded`），用 `SharedPreferences` 防止重复弹出

### 修改
- `pubspec.yaml`：添加 `timezone: ^0.10.1`，`notification_service.dart` 在 `init()` 中调用 `tz.initializeTimeZones()`
- `lib/presentation/pages/home/home_page.dart`：首次进入 `HomePage` 时通过 `addPostFrameCallback` 触发通知权限引导
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`：`_reminderEnabled` 类型由 `int` 改为 `bool`，消除与 model 层 bool 的类型不一致

### 风险
- `zonedSchedule` 需要设备支持精确闹钟（`SCHEDULE_EXACT_ALARM`），Android 12+ 用户若在系统设置关闭精确闹钟权限，通知仍可能延迟
- 重启后恢复依赖 `flutter_local_notifications` 内置 Receiver 工作正常，需真机验证

## 2026-05-30 (日历节假日显示 + 多国切换)

### 功能
日历页面支持显示法定节假日（红色）、调休补班（蓝色），可切换国家（默认中国），数据从 API 实时拉取并缓存 7 天。

### 新增
- `lib/services/holiday_service.dart`：节假日服务，中国用 timor.tools API，其他国家用 date.nager.at；`SharedPreferences` 7 天缓存 + 断网降级

### 修改
- `lib/presentation/pages/calendar/calendar_page.dart`：
  - AppBar 新增国旗按钮，切换 🇨🇳🇺🇸🇯🇵🇬🇧🇰🇷 五国节假日
  - 周视图日期头（`_buildCustomWeekHeader`）：节假日名称显示在日期圆圈下方
  - 月视图（`_buildTableCalendar`）：使用 `calendarBuilders` 在格子内显示节假日小字
  - 年份切换时自动拉取新年份数据

### 风险
- 外部 API（timor.tools / date.nager.at）不可用时仅显示缓存数据；初次使用无缓存则节假日为空
- timor.tools 目前只提供近 2 年数据，超出范围的年份返回空

## 2026-05-30 (修复思维导图子任务消失)

### 根因
`ProjectSyncService._upsertProjectFromRow` 收到云端项目墓碑 (`deleted=1`) 后，**无条件级联软删该项目下全部任务**，且自身无墓碑保护。
启动时 `ProjectSyncService.syncAll()` 先于 `TaskSyncService.syncAll()` 执行，任务在任务同步开始前就被清掉。

同时修复了 `_onRemoteDelete` (task) 和项目 Realtime DELETE 回调的同类问题。

### 修复
- `lib/services/project_sync_service.dart`: `_upsertProjectFromRow` 加墓碑保护——本地存活项目拒绝远端墓碑，不级联删任务；项目 Realtime DELETE 回调加墓碑保护
- `lib/services/task_sync_service.dart`: `_onRemoteDelete` 加墓碑保护
- `lib/data/repositories/task_repository.dart`: `delete()` 加日志

### 影响文件
- `lib/services/project_sync_service.dart`
- `lib/services/task_sync_service.dart`
- `lib/data/repositories/task_repository.dart`

## 2026-06-04 (思维导图拖动性能优化)

### 根因
1. `_lineAnimController` 每次 `onPanUpdate` 重置动画到0，animation listener 额外触发 ~18 次 `setState`，每帧实际触发 2+ 次全量 rebuild
2. 每次 `setState` 触发完整 `build()` → 重新执行 `_buildTree / _layoutTree / _collectNodes` 等 O(n) 计算
3. 每帧全量重建所有节点 Widget，无 RepaintBoundary 隔离
4. `build()` 内有大量 `print` 调试日志

### 修改内容
1. 删除 `_lineAnimController` 动画控制器 + `_animatedPositions` + `_manualOffsets`
2. 新增布局缓存（`_cachedPendingNodes/Lines/CanvasSize` 等），`initState` / `didUpdateWidget` 中计算，`build()` 直接读缓存
3. 拖拽改为 `ValueNotifier<Offset>` 每节点独立 + `ValueListenableBuilder`，只重建被拖拽节点
4. 连线层用 `AnimatedBuilder` + `Listenable.merge` 监听所有 notifier，只重建 `CustomPaint`
5. 删除 `build()` 内所有 `print` 调试日志
6. 每个节点外包 `RepaintBoundary`

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

## 2026-06-04 (拖拽位置持久化 + 用户隔离)

### 修改内容
1. `MindMapView` 新增 `userId` 参数
2. `_loadOffsets()` — 从 SharedPreferences 加载已保存偏移，key 为 `mindmap_offsets_<userId>`
3. `_saveOffsets()` — 拖拽结束时将 `_draggedIds` 对应位置序列化为 JSON 保存
4. `onDragEnd` 回调调用 `_saveOffsets()` — 松开鼠标即刻持久化
5. 重置按钮同时清除持久化数据
6. `TasksPage` 从 `AuthBloc` 提取 userId（Supabase `user.id` 或本地 `local_<email>`）并传入

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`

## 2026-05-30 (修复思维导图子任务重启后被云端墓石覆盖删除)

### 根因
`syncAll` 从云端拉取时，云端残留旧的 `deleted=1` 墓石记录，`syncFromJson` 的 LWW 逻辑将本地活任务(deleted=0)覆盖为 deleted=1。同时 `taskRepository.create` 中 `push` 未 await，存在竞态。

### 修改内容
1. `task_repository.dart:syncFromJson` — 新增反向墓石保护：本地活任务(deleted=0)不被远端墓石(deleted=1)覆盖
2. `task_repository.dart:create` — `push` 改为 await，消除竞态
3. `task_sync_service.dart:syncAll` — 本地活但云端是墓石时主动推送覆盖，修复残留墓石
4. 新增 `file_logger.dart` 文件日志工具 + 关键路径诊断日志

### 影响文件
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `lib/core/utils/file_logger.dart`（新增）

### 风险
- 低：反向墓石保护可能导致用户在其他设备删除的任务在本设备"复活"，但优先保证数据不丢失

## 2026-05-31 (修复思维导图模式子任务消失)

### 修改内容
1. `_onLoadTasks` 补全状态保留：`viewMode`、`dateFrom`、`dateTo` 从上一个 `TaskNewLoaded` 状态继承
2. 之前 `CreateTask` → `LoadTasks` → `emit TaskNewLoaded` 时未传入 `viewMode`，默认回退为 `'mindmap'`
3. 日期筛选 `dateFrom`/`dateTo` 同样丢失，导致添加子任务后日期筛选被清除

### 影响文件
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 风险
- 低：纯增量保留，不影响现有逻辑

## 2026-05-30 (思维导图自由拖拽 + 连线延迟动画)

### 修改内容
1. **自由拖拽模式**：右下角新增加锁/解锁切换按钮，解锁后节点可自由拖动到画布任意位置
2. **连线延迟变短动画**：拖动节点时连线带 300ms easeOut 惯性过渡，松手后平滑缩短至最终位置
3. **`_ConnectorLine` 重构**：从存死坐标改为存 `parentId`/`childId`，`_MindMapLinesPainter` 动态查表绘制
4. **`_MindMapNodeCard` 增强**：新增 `freeDragMode`/`onDragUpdate` 参数，自由模式下用 `GestureDetector` 处理拖动
5. **`InteractiveViewer.panEnabled` 按模式切换**：自由拖拽时禁用画布平移避免手势冲突，缩放仍可用

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

### 风险
- 自由拖拽模式下画布无法平移（仅可缩放），需切换回自动布局模式后恢复平移

## 2026-05-29 (思维导图拖动/布局/时间编辑/子任务消失修复)

### 修改内容
1. **无限拖动**：`boundaryMargin` 改为 `double.infinity`，缩小后也可自由左右拖动
2. **布局间距优化**：VGap 16→28, HGap 80→100, Padding 40→100，节点不再紧贴挤在一起
3. **展开按钮移到标题行**：从优先级行移到标题文本右侧，视觉更合理
4. **时间分开编辑**：开始/结束时间各自独立点击弹 picker 编辑，不再连续弹两次
5. **子任务消失修复**：`_onCreateTask` 保留当前 filter/projectId，并调用 `_syncTasksToCloud()`
6. **添加子任务后自动展开父节点**

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 风险
- 子任务消失问题的根因可能还有其他因素（如 Realtime 回调），已修复最明显的 filter 丢失问题

## 2026-05-29 (思维导图视图优化 + 检查项溢出修复)

### 修改内容
1. **思维导图卡片右侧 "+" 按钮**：每个任务卡片右侧中间新增圆形 "+" 按钮，点击直接创建子任务（预设 parentId）
2. **思维导图项目切换**：卡片上项目名可点击弹出项目选择菜单，直接切换所属项目
3. **时间展示优化**：卡片显示完整时间范围（开始→结束），点击可分别修改开始和结束时间
4. **画布拖拽优化**：增大 boundaryMargin 至 800px，缩放范围调整为 0.15~3.0，支持灵活的左右上下拖拽和缩放
5. **去掉 Slidable**：移除思维导图卡片的左滑手势（完成/删除），避免与画布拖拽冲突
6. **右上角 "-" 删除按钮**：每个卡片右上角固定红色 "-" 按钮，支持快捷删除
7. **检查项溢出修复**：将 `Flexible` 替换为 `ConstrainedBox(maxHeight: 240)`，解决 "BOTTOM OVERFLOWED BY 8.0 PIXELS" 黄色溢出报错

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart`

### 风险
- 项目选择菜单在项目很多时可能需要滚动优化

## 2026-05-29 (思维导图任务视图 + 系统托盘修复)

### 修改内容
1. **思维导图任务视图**：新增 `mind_map_view.dart`，任务列表支持水平思维导图展示（根节点在左，子节点向右分支，贝塞尔曲线连接线）。保留拖拽、展开/折叠、优先级、Slidable等全部交互。桌面端默认思维导图，可通过 AppBar 按钮切换列表/导图视图。
2. **系统托盘图标一致性**：用 `windows/runner/resources/app_icon.ico` 替换 `assets/icons/tray_icon.ico`，确保托盘图标与应用图标一致。
3. **单实例保护**：`windows/runner/main.cpp` 添加 Named Mutex，防止多开。第二个实例会激活已有窗口后退出。
4. **退出延迟修复**：托盘"退出"菜单改为 `windowManager.destroy()` + `exit(0)`，解决关闭延迟。

### 影响文件
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`（新建）
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_state.dart`
- `lib/presentation/blocs/task_new/task_event.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `windows/runner/main.cpp`
- `assets/icons/tray_icon.ico`

### 风险
- 大量任务时思维导图可能需要性能优化
- InteractiveViewer 与 Draggable 手势冲突需关注

## 2026-05-29 (修复模拟器联网)

### 修改内容
- **open_emulator.bat**：改为直接调用 `emulator.exe -avd <name> -dns-server 8.8.8.8,114.114.114.114` 启动模拟器，修复模拟器 DNS 解析失败导致 Supabase 无法连接的问题。
- **android/app/src/debug/AndroidManifest.xml**：添加 `usesCleartextTraffic="true"` + `networkSecurityConfig`。
- **android/app/src/main/res/xml/network_security_config.xml**：新建，debug 构建允许 cleartext 流量 + 信任用户 CA 证书。

### 原因
模拟器 `flutter run` 时无法联网（日历刷不出来），打包 APK 安装真机正常。根因是模拟器 DNS 解析失败导致无法连接 Supabase。

## 2026-05-29 (新增脚本)

### 修改内容
- **open_emulator.bat**：新增一键打开 Android 模拟器脚本，自动检测可用模拟器并启动，支持多模拟器选择。

## 2026-05-29 (6项UI/UX改进)

## 2026-05-29 (6项UI/UX改进)

### 修改内容
1. **SnackBar点击消失**：新增 `showAppSnackBar` 全局工具函数，所有提示消息点击即消失。统一替换了全部47处 `ScaffoldMessenger.showSnackBar` 调用。
2. **首页任务详情日期编辑**：`_TimelineTask` 新增 `endDate` 字段，详情区域显示"开始 → 结束"两个可点击日期，分别编辑开始和结束时间。
3. **任务详情页日期编辑修复**：`_timeChip()` 移除外层 `onTap`，开始和结束日期各自独立 `InkWell`，两个日期均可单独点击编辑。
4. **首页任务详情项目修改**：项目标签支持点击弹出项目选择器，直接切换任务所属项目。
5. **项目删除不收回Drawer**：删除 `_confirmDeleteProject` 中的 `Navigator.pop(context)`，删除后侧边栏保持打开。
6. **应用图标**：设计清单+阳光风格图标（暖橙渐变背景 + 白色清单 + 小太阳），通过 `flutter_launcher_icons` 生成 Android 和 Windows 图标。
7. **日历水平拖动导航**：周视图时间轴区域支持鼠标/手指水平拖动，实时跟手切换日期（累积超过 0.6 倍 dayWidth 即偏移1天）。

### 影响文件
- `lib/core/utils/snackbar_helper.dart`（新增）
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `assets/icons/app_icon.svg`, `assets/icons/app_icon_1024.png`（新增）
- `android/app/src/main/res/mipmap-*/ic_launcher.png`（更新）
- `pubspec.yaml`（添加 flutter_launcher_icons）
- 14个文件的 SnackBar 调用替换

### 风险/TODO
- 日历水平拖动与任务块拖动共存：任务块使用 pan 手势在 gesture arena 中优先级更高，空白区域才响应水平拖动
- 图标在深色背景上对比度足够，浅色背景上圆角可能略显柔和

## 2026-05-29 (日历/任务列表增强 + 同步BUG修复)

### 修改内容
- **日历周视图头部同步**：切换显示天数(1-15天)时，头部星期标签和日期数字随之变化，不再固定显示7天。新增 `_buildCustomWeekHeader()` 替代 `TableCalendar` 的固定周头。
- **移动端日历文字自适应**：任务块文字根据可用宽度动态缩放（最小8px），极窄时隐藏时间和父标签，使用 `FittedBox` 确保标题可见。
- **桌面端右键菜单**：任务卡片支持右键弹出"编辑/删除"上下文菜单（`GestureDetector.onSecondaryTapUp` + `showMenu`）。
- **任务卡片项目标签**：项目名从标题下方移到卡片左上角，以彩色小标签形式显示。
- **日期区间筛选**：任务列表 AppBar 新增日期筛选按钮，BLoC 层支持 `dateFrom/dateTo` 参数，过滤任务时间范围与选定区间有交集的任务。
- **同步BUG修复**：
  - `syncFromJson` 保留远端 `updatedAt` 时间戳，避免本地覆盖云端新数据
  - 墓石保护：本地已删除且时间戳>=远端时，不被远端未删除状态复活
  - Realtime 回调串行化（`_enqueue` 队列），防止并发写入导致 SQLite database locked

### 影响文件
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/{task_event,task_state,task_bloc}.dart`
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`

### 风险/TODO
- 日历自定义头部在天数>7时日期可能跨月，已正确处理
- `FittedBox` 在极窄块上可能导致文字过小但仍可见，是预期行为
- 同步修复需要跨设备验证，建议清空云端僵尸数据后测试

## 2026-05-29 (全业务数据双端同步：软删除墓石 + 双向 LWW 对账 + checklist 上云)

### 修改内容
- **统一软删除（墓石）**：`Tasks/Projects/ProjectGroups/ChecklistItems` 各加 `deleted` 列（NOT NULL DEFAULT 0），schemaVersion 6→7，`onUpgrade if(from<7)` 兜底加列。删除一律置 `deleted=1, updatedAt=now` 并推送墓石，不再物理删除 → 删除靠墓石跨端传播、重启不复活。
- **双向 LWW 全量对账**：`TaskSyncService/ProjectSyncService/ChecklistSyncService/AttachmentSyncService` 新增/升级 `syncAll()`：拉云端（含墓石）合并到本地 + 本地（含墓石）凡云端缺失或本地 `updatedAt` 更新则推送上云。修复"子任务树不同步""离线删除不传播"。
- **checklist 首次上云**：新建 `lib/services/checklist_sync_service.dart` + 云表 `public.checklist_items`（RLS + REPLICA IDENTITY FULL + 加入 supabase_realtime publication）；`ChecklistRepository` 注入 syncService，增删改 push、软删、读查询过滤 `deleted=0`、新增 `syncFromJson`。
- **删除空 catch / NPE 守卫**：`TaskSyncService` 去掉 `catch(_){}` 保留日志，`currentUser!` → `currentUser?` 守卫。
- **启动按登录态门控**：`home_page` 移除未登录即触发的 task pull，所有 `syncAll()+subscribe()` 统一在登录后启动，`signedIn/initialSession` 每次重跑全量对账。
- **项目删除级联软删**：project 删除时级联软删其下 tasks/checklist；远端项目墓石到达时本地同样级联软删。
- **阶段0 清空全部数据**：云端 `user_tasks/task_attachments/projects/project_groups` 已 DELETE 清空；`AppDatabase.wipeAllData()` 事务清空本地各表并重建 inbox。

### 影响文件
- `lib/data/database/app_database.dart`（+ 生成物 `.g.dart`）
- `lib/data/repositories/{task,project,project_group,checklist}_repository.dart`
- `lib/services/{task_sync,project_sync,attachment_sync,checklist_sync}_service.dart`（checklist 为新建）
- `lib/presentation/pages/home/home_page.dart`、`lib/main.dart`
- `test/task_progress_calculator_test.dart`（构造补 `deleted`）
- `database/migration_004_soft_delete_checklist_realtime.sql`（云端留痕）

### 风险/TODO
- **本地必须清空**：桌面 DB 清空时文件被占用（App 运行中）未删成功。须先关闭 App 再运行 `clear_data.bat`（或删 `%USERPROFILE%\Documents\smart_assistant.db`）；否则下次启动 `syncAll` 会把本地旧数据反推回已清空的云端。移动端需卸载重装或后续接入应用内 `wipeAllData()` 入口。
- `clear_data.bat` 仅删 `.db/-journal`，未删 `-wal/-shm`（Drift 默认非 WAL，影响小）。
- `syncAll` 为 O(n) 全量 upsert，当前数据量小；后续可批量化。
- `migration_004` 仅作留痕，实际已通过 Management API 执行（token 不入库）。

## 2026-05-29 (任务列表树形结构 UI 优化)

### 修改内容
- 树形连接线：新增 `_TreeLinesPainter`（CustomPaint），子节点显示 ├── / └── 连接线，非最后祖先层持续竖线
- 层级标签：每个节点左侧显示 R0/R1/R2 小标签
- 缩窄左侧区域：拖拽手柄 icon 从 20→16，padding horizontal 从 2→1
- 移除 TaskCard 内部 `depth * 24` 缩进（传 depth:0），缩进统一由外层树形线负责

### 影响文件
- `lib/presentation/pages/tasks/widgets/task_list_view.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`

### 风险/TODO
- 已完成区块（completedTreeNodes）未加树形线，保持原样

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
