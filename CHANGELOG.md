## 2026-06-06 (移动端提醒通知准时性优化)

### 修复
- **过期提醒乱响**：APP启动时过期任务的通知不再逐条触发，改为合并为一条摘要通知"你有N个过期任务未完成"。`rescheduleTaskReminders`/`rescheduleBreakdownTaskReminders`/`rescheduleScheduleReminders` 三个方法均增加过期检测+合并摘要逻辑，过期闹钟（AlarmService）在重调度时清理。

### 新增
- **电池优化引导弹窗**：首次启动弹出引导，适配小米/华为/OPPO/vivo/三星品牌的具体操作步骤，引导用户关闭电池优化。支持"不再提示"和"去设置"（跳转系统电池优化页）。`BatteryOptimizationGuide` + `_BatteryGuideDialog`。
- **微信+FCM服务端推送兜底**：`scheduleReminderForSchedule` 调度本地通知的同时，通过 `WechatReminderService.scheduleServerPush` 注册服务端定时推送（微信+FCM双通道），`cancelReminderForSchedule` 同步取消。需配合 Supabase Edge Function `schedule-push` 和 `register-fcm-token`。
- **FCM服务骨架**：`FcmService` 负责 token 获取和上传，待集成 `firebase_messaging` 包。

### 影响文件
- `lib/services/notification_service.dart` — 过期合并摘要 + 服务端推送调用
- `lib/services/wechat_reminder_service.dart` — 新增 scheduleServerPush/cancelServerPush
- `lib/services/fcm_service.dart` — 新增 FCM 服务骨架
- `lib/presentation/widgets/battery_optimization_guide.dart` — 新增电池优化引导弹窗
- `lib/presentation/pages/home/home_page.dart` — 启动时显示引导弹窗
- `android/app/src/main/kotlin/com/taskora/app/MainActivity.kt` — 新增 getManufacturer 方法

### 待配置
- Supabase 部署 `schedule-push` Edge Function（接收定时推送注册/取消）
- Supabase 部署 `register-fcm-token` Edge Function（FCM token 注册）
- `pubspec.yaml` 添加 `firebase_core` + `firebase_messaging`（FCM 集成后启用 FcmService）
- Firebase 项目配置（google-services.json / GoogleService-Info.plist）

### 修复
- **项目侧边栏筛选不锁定项目**：点击侧边栏「所有任务」「今天」「重要」时未清除项目筛选（selectedProjectIds 残留），导致「所有任务」仍只显示选中项目的任务。修复：onFilterSelected 中传入空 projectIds，确保筛选切换到全部项目。

### 修复
- **思维导图切换筛选后不自定定位**：点击「所有任务」「今天」「重要」后，MindMapView 的 didUpdateWidget 未重置 _initialFocusDone，导致视口停留在原位不自动定位到最近任务。修复：监听 selectedFilter 变化，触发 _focusNearestTask。

## 2026-06-05 (微信提醒功能)

### 修复
- **项目侧边栏分组展开/收缩失效**：ProjectSidebar 中 ExpansionTile 因 ValueKey 不变导致 initiallyExpanded 不更新，无法响应"全部展开/全部收缩"按钮。方案：在 key 中加入展开状态标识，确保状态变化时强制重建 ExpansionTile。

### 新增
- **微信提醒模块**（独立模块，零耦合现有通知系统）
  - 后端：WxPusher 推送集成，Supabase Edge Function × 3（绑定管理、回调处理、定时扫描推送）
  - 数据库：`wechat_bindings`（用户绑定表）+ `wechat_reminder_log`（推送日志防重复）
  - 客户端：`WechatReminderService` + `WechatBindingPage`（二维码扫码绑定/解绑/开关）
  - 设置页新增"微信提醒"入口
  - pg_cron 每分钟扫描即将到期任务，通过 WxPusher API 推送微信消息，APP 关闭也能收到

### 待配置
- 注册 WxPusher 并替换 `AppConstants.wxpusherAppToken` 和 `wxpusherAppId`
- Supabase Dashboard 执行 `database/migration_wechat_reminder.sql`
- 部署 3 个 Edge Function 并配置 pg_cron
- WxPusher 后台设置回调 URL 为 `<SUPABASE_URL>/functions/v1/wxpusher-callback`

## 2026-06-05 (任务编辑时冲突检测+自动延后/插入)

### 新增
- **编辑任务时间冲突检测**：编辑任务时修改时间若与其他任务重叠，触发冲突弹窗（取消/并行/自动延后/自动插入），与创建任务时行为一致
- 新增公共服务 `TaskConflictService`：提取冲突检测、延后计算、自动插入逻辑
- 新增公共弹窗 `showTaskConflictDialog()`：统一冲突弹窗 UI

### 覆盖的编辑入口
- `TaskDetailPage._pickDateTime()` — 任务详情页时间选择
- `TaskEditPage._pickDateTime()` — 独立编辑页时间选择
- `MindMapView._editSingleDate()` — 脑图上直接点击日期编辑
- `UpdateTask` 事件新增 `shiftedTasks` 参数，Bloc 中处理被移位的任务

### 影响文件
- 新增：`lib/services/task_conflict_service.dart`
- 新增：`lib/presentation/widgets/task_conflict_dialog.dart`
- 修改：`lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- 修改：`lib/presentation/pages/tasks/widgets/task_edit_page.dart`
- 修改：`lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- 修改：`lib/presentation/blocs/task_new/task_event.dart`
- 修改：`lib/presentation/blocs/task_new/task_bloc.dart`
- 修改：`lib/presentation/pages/tasks/widgets/task_create_sheet.dart`（改用公共工具）

---

## 2026-06-05 (修复日历任务拖拽弹回)

### 修复
- **日历任务拖拽弹回（手势竞技场）**：桌面端 _ResizableTaskBlock 使用标准 PanGestureRecognizer，与 SingleChildScrollView 的 VerticalDragGestureRecognizer 竞争失败 → 改为 _EagerPanGestureRecognizer 立即 accept
- **日历任务拖拽弹回（_reloadData 防抖）**：_moveTask / _moveTaskMultiDay / _resizeTaskStart / _resizeTaskEnd 末尾调用 _reloadData() 未经 await，且 _reloadData() 有 2 秒防抖窗口。拖拽后的 UI 刷新被跳过 → 视觉弹回 → 改为就地更新 _allTasks（setState + task.copyWith），再异步 _reloadData 兜底

### 影响文件
- 修改：lib/presentation/pages/calendar/calendar_page.dart
  - _ResizableTaskBlockState.build 桌面分支 GestureDetector → RawGestureDetector + _EagerPanGestureRecognizer
  - _moveTask / _moveTaskMultiDay / _resizeTaskStart / _resizeTaskEnd 添加就地 _allTasks 更新

---

## 2026-06-05 (注册用户数上限50人)

### 新增
- **注册人数限制**：注册前通过 Supabase RPC `get_user_count()` 检查当前用户总数，超过 50 人拒绝注册并提示"内测名额已满"
- **SQL migration_009**：`get_user_count()` 函数（SECURITY DEFINER，查询 auth.users）

### 影响文件
- 新增：`database/migration_009_user_count_rpc.sql`
- 修改：`lib/services/supabase_service.dart`（新增 `getUserCount()` + `maxRegisteredUsers` 常量）
- 修改：`lib/presentation/blocs/auth/auth_bloc.dart`（`_onRegistered` 注册前检查）

### 操作步骤
- 需要在 Supabase SQL Editor 执行 `database/migration_009_user_count_rpc.sql`

---

## 2026-06-05 (VIP会员等级功能)

### 新增
- **VIP订阅模型**：`UserSubscription` 模型 + `SubscriptionService` 单例管理订阅状态
- **Supabase 表**：`user_subscriptions` 表 + RLS + Realtime（migration_007）
- **配额检查**：免费用户限3个项目/每项目50任务，VIP无限制
- **功能锁**：AI拆分子任务 + 数据导出为VIP专属，入口加锁标识
- **VIP页面**：`VipPage` 展示套餐选择、权益说明、支付入口
- **升级弹窗**：`UpgradeDialog` 配额超限/功能受限时引导升级
- **VIP徽章**：`VipBadge` + `VipLockIcon` 组件
- **状态同步**：Realtime 订阅 + 前台恢复刷新 + 本地 SharedPreferences 缓存

### 影响文件
- 新增：`lib/models/entities/user_subscription.dart`、`lib/services/subscription_service.dart`、`lib/presentation/pages/profile/vip_page.dart`、`lib/presentation/widgets/upgrade_dialog.dart`、`lib/presentation/widgets/vip_badge.dart`、`lib/core/exceptions/quota_exceeded_exception.dart`、`database/migration_007_subscriptions.sql`
- 修改：`lib/main.dart`、`lib/core/constants/app_constants.dart`、`lib/data/repositories/project_repository.dart`、`lib/data/repositories/task_repository.dart`、`lib/services/task_decomposition_service.dart`、`lib/presentation/pages/profile/profile_page.dart`、`lib/presentation/pages/tasks/tasks_page.dart`、`lib/presentation/pages/home/home_page.dart`、`lib/presentation/pages/tasks/task_detail/widgets/ai_decompose_section.dart`、`lib/presentation/blocs/task_new/task_bloc.dart`、`lib/presentation/blocs/task_new/task_state.dart`

### 定价
- 月度VIP ¥9.9/月、年度VIP ¥68/年

### Step 4 追加：支付宝扫码支付全链路
- **服务端**：3 个 Supabase Edge Function（Deno/TypeScript）
  - `create-order`：调用 `alipay.trade.precreate` 生成扫码二维码
  - `alipay-notify`：接收支付宝异步通知，RSA2验签，激活/续费 VIP
  - `order-status`：客户端轮询订单状态
- **共享模块**：`_shared/alipay.ts` 支付宝 RSA2 签名/验签/API 封装
- **客户端**：`PaymentService` + VipPage 二维码支付页（`qr_flutter`）
- **新增依赖**：`qr_flutter: ^4.1.0`
- **新增表**：`payment_orders`（migration_008）
- **部署指南**：`supabase/DEPLOY_GUIDE.md`

### 待办
- 支付宝开放平台创建应用 + 配置密钥 + 开通当面付
- Supabase CLI 部署 Edge Functions
- IAP（Google Play / App Store）后续上架时加

---

## 2026-06-05 (日历页面移动端手势冲突修复)

### 修改
- **任务块拖动优先**：移动端在任务块上拖动时，使用 `_EagerPanGestureRecognizer`（立即赢得手势竞技场），防止 `SingleChildScrollView` 的 `VerticalDragRecognizer` 抢走手势
- 桌面端行为不变，仍使用标准 `GestureDetector`
- tap（点击详情）通过 pan 距离 <3px 判定兼容

### 影响文件
- `lib/presentation/pages/calendar/calendar_page.dart` — 新增 `_EagerPanGestureRecognizer`，移动端 `_ResizableTaskBlock` 改用 `RawGestureDetector`

### 风险
- 移动端任务块区域上无法上下滚动时间线（手势被任务块捕获），需在空白区域操作

---

## 2026-06-04 (AI 拆分设置 + 描述/子任务刷新修复)

### 修改
- **AI 拆分设置**：层级和子任务数量从 Slider 改为 DropdownButton 下拉框
- **描述编辑刷新**：从全屏 Markdown 编辑器返回后，描述预览立即更新（添加 controller listener + Navigator.push then 回调）
- **拆分结果刷新**：AI 拆分完成后追加 LoadSubTree + setState 确保子任务树和父任务标记立即更新

### 影响文件
- `lib/presentation/pages/tasks/task_detail/widgets/ai_decompose_section.dart` — Slider → DropdownButton
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart` — 编辑器返回刷新 + 拆分后刷新
- `lib/presentation/pages/tasks/task_detail/widgets/markdown_description_section.dart` — 添加 controller listener

---

## 2026-06-04 (MVP 上架准备 — 小米应用商店)

### 修改
- **Android 包名**: `com.example.smart_assistant` → `com.taskora.app`（namespace + applicationId + Kotlin 目录）
- **Release 签名**: `key.properties` 驱动的 `signingConfigs.release`，未配置时自动 fallback debug
- **代码混淆**: release 启用 R8 minify + shrinkResources + ProGuard 规则
- **隐私合规弹窗**: 新增 `PrivacyConsentPage`，首次启动必须同意才初始化 Supabase
- **登录页协议**: 新增"同意用户协议和隐私政策"勾选框 + 可点击跳转查看全文
- **全局错误捕获**: `runZonedGuarded` + `FlutterError.onError`，未捕获异常记录文件日志
- **协议文本内置**: 隐私政策含第三方 SDK 披露（Supabase、DeepSeek、Google Fonts）

### 影响文件
- `android/app/build.gradle.kts` — 包名 + 签名 + 混淆
- `android/app/src/main/kotlin/com/taskora/app/MainActivity.kt` — 目录迁移
- `android/app/proguard-rules.pro` — 新增
- `android/key.properties.example` — 新增模板
- `lib/main.dart` — runZonedGuarded + 隐私门控
- `lib/presentation/pages/privacy/privacy_consent_page.dart` — 新增
- `lib/presentation/pages/auth/login_page.dart` — 协议勾选

### 风险/TODO
- 需要创建 release keystore 并配置 `android/key.properties`（参考 `key.properties.example`）
- APP 备案号尚未获取，小米商店提交时需要
- Google Fonts 国内可用性需验证，建议预打包字体

---

## 2026-06-10 (日历三修 v3：修复 onPointerUp 翻页竞态)

### 修复
- **Bug 1 (父任务缩小精度错配)**：`_parentRangeCoversDescendants` 比较 DateTime 前归一化到日期边界，消除毫秒级偏差导致守卫误拒
- **Bug 2 (expandAncestorDates 不回缩)**：当子任务在父范围内时，遍历所有子任务取真实 min/max 支持回缩
- **Bug 3 v4 (onPointerUp 翻页竞态)**：Flutter 中 `onPointerUp` 按 child→parent 顺序分发，内层 `Listener.onPointerUp` 先重置 `_isTaskDragging = false`，外层随后读取时为 false 误触发翻页。新增 `_dragSkipped` 标志在 `onPointerMove` 跳过时设置、`onPointerUp` 检查该标志而非 `_isTaskDragging`。外层 `onPointerDown/Move/Up/Cancel` 全覆盖重置 `_dragSkipped`。

### 影响文件
- `lib/presentation/pages/calendar/calendar_page.dart` — `_dragSkipped` 标志 + 外层透传防护 + 垂直滚动双重锁定 + Listener 方案
- `lib/data/repositories/task_repository.dart` — expandAncestorDates 支持回缩

## 2026-06-10 (父任务时间自动跟随子任务 + 时间/项目锁定 + 父标记)

### 新增
- **`TaskRepository.expandAncestorDates()`**：基于 DB 查询的父任务时间自动扩缩，不再依赖内存列表
- **`TaskRepository.hasChildren()`**：快速检查任务是否有子任务
- **父任务标记**：有子任务时，meta 栏显示「父任务」badge（蓝色树状图标）
- **父任务时间只读**：有子任务时，时间 chip 显示为灰色只读文字 + "(子任务)" 标注，不可点击编辑
- **项目继承锁定**：只有最上级任务（parentId==null）可编辑项目字段；有 parentId 的任务项目 chip 显示为只读

### 修改
- `calendar_page.dart` — `_moveTask`/`_resizeTaskStart`/`_resizeTaskEnd` 在 repo update 后调用 `expandAncestorDates`，确保日历页拖拽子任务时间时父任务跟随
- `task_bloc.dart` — `_expandAncestorDates` 迁移到 repo 方法，消除重复逻辑；`_onUpdateTask` 不再依赖 state 内任务列表
- `task_detail_page.dart` — 新增 `_hasChildren`/`_isRoot` 状态字段；`_timeChip` 父任务只读；`_projectChip` 非根任务只读；`_parentBadge` 父标记

### 影响文件
- `lib/data/repositories/task_repository.dart` — 新增 `expandAncestorDates`、`hasChildren`
- `lib/presentation/pages/calendar/calendar_page.dart` — 3 处 expandAncestorDates 调用
- `lib/presentation/blocs/task_new/task_bloc.dart` — 删除内联 _expandAncestorDates
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart` — UI 锁定 + 父标记

### 风险/TODO
- 已有 `_cascadeProjectId` 确保根任务改项目时自动级联后代
- 新增 hasChildren 异步查询，首次 render 时 `_hasChildren` 可能为 false（短暂延迟后正确）
- 日历页 multi-day mode 的 `_moveTaskMultiDay` 尚未补全 expandAncestorDates，待确认是否需要

---

## 2026-06-10 (Markdown 编辑器升级：全屏 + 图片粘贴)

### 新增
- **全屏编辑器**：点击"编辑"后不再内嵌展开，改为 Navigator.push 全屏编辑器页面 (`MarkdownEditorPage`)，提供类似 Typora/Notion 的大面积编辑区
- **智能粘贴**：Ctrl+V 时自动检测剪贴板内容 — 有图则上传附件，有文字则插入光标处，不再拦截原生文字粘贴
- **拖拽上传**：全屏编辑器中保持 DropTarget 支持，可直接拖入图片文件
- **编辑器内预览**：AppBar 带预览/编辑切换按钮，预览态可滚动查看渲染效果

### 修改
- `markdown_description_section.dart` — 新增 `onEnterEdit` 回调，由父级决定编辑方式（全屏 or 内嵌）
- `task_detail_page.dart` — `_buildDescriptionBox()` 移除 `CallbackShortcuts`（图片粘贴移至编辑器），改用 `onEnterEdit` 导航到全屏编辑器；删除不再使用的 `_pasteDescriptionImage`、`_readClipboardPng`、`_saveDescriptionImageBytes` 方法

### 影响文件
- `lib/presentation/pages/tasks/task_detail/widgets/markdown_editor_page.dart` — **新建**
- `lib/presentation/pages/tasks/task_detail/widgets/markdown_description_section.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`

### 风险/TODO
- 现有描述功能不受影响，预览模式不变
- 编辑器内图片粘贴依赖 `super_clipboard`，桌面端已验证，移动端需确认 `SystemClipboard.instance` 可用

---

## 2026-06-10 (全局记忆加固：codegraph 门禁追溯调用证据)

### 修复
- 根因（2026-06-10 违规）：codegraph MCP 已注册但本轮从未调用过，自检时仍标记为 ✅，用 read_file/search_content 替代完成修改，跳过了 codegraph_impact/explore/callers 三步门禁。
- **Fix A (自检格式升级)**：`self-check-before-reply` / `codegraph-workflow` / `auto-connect-tool-gate` 三个记忆的自检表从 ✅/❌ 改为 **追溯本轮实际调用证据**，逐项填写从未调用过/调用过。任一 ❌ 硬拒绝修改。
- **Fix B (禁止替代条款)**：`codegraph-workflow` 新增明确禁止 read_file/search_content 替代图谱语法分析，违规等同于绕过门禁。

### 影响记忆文件
- `codegraph-workflow.md`：新增调用证据追溯格式 + 2026-06-10 违规案例
- `self-check-before-reply.md`：门禁自检改为逐项追溯调用证据
- `auto-connect-tool-gate.md`：门禁枚举格式升级 + 2026-06-10 违规案例

## 2026-06-10 (跨端任务消失修复 — syncAll 墓碑防护)

### 修复
- 根因：syncAll push 循环无差别推送本地墓碑。当项目级联软删任务时使用 local `now` 作为 `updatedAt`，导致 `syncAll` 认为本地墓碑比云端活任务更"新"，进而推送墓碑覆盖云端，最终传染到全部设备。
- **Fix A (syncAll 墓碑防护)**：push 循环中，本地 `deleted=1` 且远端存活时跳过推送。有意删除已通过 `delete()` 的 `syncImmediately` 即时推送，不依赖此循环传播。
- **Fix B (删除即时推送)**：`_onDeleteTask` 在本地删除后立即 `TaskSyncService.instance.push()` 推送上云，不依赖 syncAll push 循环。
- **Fix C (级联时间戳)**：项目级联软删任务时使用远端 `updated_at` 而非 local `now`，避免 cascaded 墓碑时间戳大于远端活任务。

### 影响文件
- `lib/services/task_sync_service.dart`：syncAll push 循环增加墓碑防护
- `lib/presentation/blocs/task_new/task_bloc.dart`：删除任务后即时推送
- `lib/services/project_sync_service.dart`：级联软删改用远端时间戳

## 2026-06-10 (任务详情 Markdown 编辑器)

### 新增
- 任务详情"描述"区域支持 Markdown 编辑和预览，类似 Typora 体验
- 折叠态显示渲染后的 Markdown 预览，点击进入编辑模式
- 编辑模式提供完整工具栏：标题(H1/H2/H3)、加粗、斜体、删除线、无序/有序/任务列表、引用、行内代码、代码块、链接、分割线、表格
- 支持左右分栏实时预览模式
- 与现有数据模型完全兼容，description 仍存纯 Markdown 文本

### 影响文件
- `pubspec.yaml` — 新增 flutter_markdown 依赖
- `lib/presentation/pages/tasks/task_detail/widgets/markdown_description_section.dart` — 新建组件
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart` — _buildDescriptionBox 替换为新组件

### 风险/TODO
- 已有纯文本描述自动兼容（Markdown 渲染纯文本无副作用）

---

## 2026-06-09 (新建任务后卡顿/消失修复)

### 修复
- **A** — 新建任务时 `syncImmediately: true`，立即推送上云，不等 `syncAll` 批量推
- **B** — `_runOptimisticTaskChange` 中 `syncAll` 失败不再 rollback 本地数据，只打日志
- **D** — `_rescheduleTaskReminders` 加 2s 节流，避免频繁全量通知重调度导致卡顿
- **E** — `_taskChangesSub` 回调中去掉 `_rescheduleTaskReminders()`，断掉通知调度→LoadTasks 连锁反应
- **I** — 新建任务后自动将新任务的 projectId 纳入项目过滤，避免未选项目时任务被过滤掉

### 影响文件
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/presentation/pages/home/home_page.dart`

### 风险/TODO
- `syncAll` 失败时本地数据与云端不一致的风险在下次成功 sync 时自动修复

---

## 2026-06-04 (Realtime 无限循环卡顿修复)

### 修复
- TaskSyncService: push 后记录 taskId，Realtime 收到自身回声时跳过，打断 push→Realtime→sync→LoadTasks 无限循环
- home_page BlocListener: 加 2 秒节流，防止 TaskNewLoaded 频繁触发 _loadData
- 文件：`lib/services/task_sync_service.dart`、`lib/presentation/pages/home/home_page.dart`

---

## 2026-06-04 (任务创建页时长滑块)

### 新增
- 在"日期范围"卡片的开始时间和截止时间之间加入时长滑块
- 支持"小时"(0.5~12h, 步长0.5)和"天"(1~15d, 步长1)两种模式切换
- 滑动自动计算截止时间；手动选截止时间反算滑块值；改开始时间保持时长重算结束
- 文件：`lib/presentation/pages/task/create_task_page.dart`、`lib/presentation/pages/tasks/widgets/task_create_sheet.dart`

---

## 2026-06-04 (退出APP后提醒不生效修复)

### 问题
移动端退出（杀死）APP后，任务提醒不再触发。根因：重复提醒依赖进程内Timer（APP被杀即丢失）、AlarmService调用条件过严、国产ROM电池优化清除AlarmManager。

### 修复
- notification_service.dart: 重复提醒改为预调度未来24小时内最多20次独立通知（每次独立注册AlarmManager），不再依赖Timer
- notification_service.dart: 放宽AlarmService调用条件，不再要求精确闹钟权限
- notification_service.dart: cancelReminderForSchedule 同步取消所有预调度的重复通知
- home_page.dart: APP从后台恢复时自动重新调度所有提醒（_onAppResume增加_rescheduleTaskReminders）
- 新增 battery_optimization_service.dart: 通过MethodChannel检测/请求关闭Android电池优化
- permission_service.dart: 首次启动引导用户关闭电池优化（弹窗跳转系统设置）
- app_settings_page.dart: 设置页新增电池优化状态显示和设置入口
- MainActivity.kt: 新增MethodChannel处理电池优化检测/请求/设置跳转
- AndroidManifest.xml: 新增REQUEST_IGNORE_BATTERY_OPTIMIZATIONS权限

### 影响文件
- lib/services/notification_service.dart
- lib/services/battery_optimization_service.dart (新增)
- lib/services/permission_service.dart
- lib/presentation/pages/home/home_page.dart
- lib/presentation/pages/profile/app_settings_page.dart
- android/app/src/main/kotlin/.../MainActivity.kt
- android/app/src/main/AndroidManifest.xml

---

## 2026-06-05 (��ҳ�����ж�����Сʱ������)

### ����
��ҳ�����ж�ֻ�����ڣ�`today` ��㣩�Ƚϣ����� 14:00 ���ڵ������� 15:00 Ҳ����ʾ���ڡ�

### �޸�
- ����ͳ������`����` ���� `now`����ʱ���룩�Ƚϣ���ʾ��������
- ���鵯�������Ϊ `����(��)` / `����(Сʱ)` / `������` ����ָ�꣬���Կɵ���鿴��Ӧ���������б�
- `_showOverdueSheet` ���� `mode` ����֧�ְ���/Сʱ/�ܼ����ֹ���

### Ӱ���ļ�
- lib/presentation/pages/home/home_page.dart

---

## 2026-06-03 (ʱ���ͻ��ⷶΧ����)

### ����
�½�����ʱ���ͻ���ֻУ��ͬ��Ŀ�����񣬶��������������Ŀ�����񲻲����⡣

### �޸�
- �Ƴ� `isSubtaskTimingOccupantForTaskCreateSheet` �� `t.parentId == null` ��������
- �������зǿ��졢������ɡ�����ɾ������ʱ��ε�����������ͻ���

### Ӱ���ļ�
- lib/presentation/pages/tasks/widgets/task_create_sheet.dart

---

## 2026-06-05 (��ҳ������֧��ճ��/��קͼƬ)

### ����
��ҳ�������������� `_buildDescriptionBox` ֻ���� `TextFormField`��Ctrl+V ճ��ͼƬ����קͼƬ���޷�Ӧ��

### �޸�
- `_buildDescriptionBox` ���� `CallbackShortcuts`(Ctrl+V) + `DropTarget`(��ק)
- ���� `_pasteHomeDescriptionImage`��`_readClipboardPng`��`_handleDroppedHomeDescriptionImages` ��������
- �������� `super_clipboard`��`flutter/services.dart`

### Ӱ���ļ�
- lib/presentation/pages/home/home_page.dart

---

## 2026-06-05 (�޸� migration �ظ����� is_template �е�����������)

### ����
- Schema 9 migration `from < 9` ִ�� `ALTER TABLE projects ADD COLUMN is_template`�����ϴ� migration ���ֳɹ������Ѵ������汾��δд�룩���ٴ�����ʱ SQLite �� `duplicate column name: is_template`

### �޸�
- `app_database.dart`��`from < 9` �� `addColumn` ���� try-catch������ "duplicate column name" �쳣����ԣ������쳣�����׳�

### Ӱ���ļ�
- lib/data/database/app_database.dart

### ����
- �ޡ��ݵȻ�������Ӱ������ migration ·��

---

## 2026-06-04 (��ҳ�½��ճ̸�Ϊ�ײ�����������ģ��������������)

### ��ҳģ���ʽ����
- `CreateScheduleDialog` �� `AlertDialog` ��Ϊ `BottomSheet` ��񣬶��� `TaskCreateSheet`����ק�ֱ���OutlineInputBorder��Բ�Ƕ�����ȫ�����水ť������ѡ����� `showCalendarDatePicker`��
- `home_page.dart`��`_createSchedule` �� `_editSchedule` �� `showDialog` �� `showModalBottomSheet`��`isScrollControlled: true`, `backgroundColor: Colors.transparent`��

### ����ģ��������������
- `TaskCreateSheet` �������ѿ��أ�`SwitchListTile`������ǰʱ��ѡ������ `ListTile`���������� UI ��¶ `remindBeforeMinutes` / `reminderEnabled`�����ظ�����
- `task_repository.dart`��`create()` ���� `remindBeforeMinutes` / `reminderEnabled` ������`TasksCompanion.insert` д��
- `task_new/task_event.dart`��`CreateTask` �¼����� `remindBeforeMinutes` / `reminderEnabled` �ֶ�
- `task_new/task_bloc.dart`��`_onCreateTask` �������Ѳ����� `taskRepository.create()`
- `tasks_page.dart` / `calendar_page.dart` / `subtask_tree_section.dart`����������д��������ֶε� `CreateTask` �¼�

### Ӱ���ļ�
- lib/presentation/widgets/create_schedule_dialog.dart����д��
- lib/presentation/pages/home/home_page.dart
- lib/presentation/pages/tasks/widgets/task_create_sheet.dart
- lib/presentation/pages/tasks/tasks_page.dart
- lib/presentation/pages/calendar/calendar_page.dart
- lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart
- lib/presentation/blocs/task_new/task_event.dart
- lib/presentation/blocs/task_new/task_bloc.dart
- lib/data/repositories/task_repository.dart

### ����
- ��������ֵ������ģ��Ϊ���� UI����������Ӱ�죨���ݿ����� `remindBeforeMinutes=15` / `reminderEnabled=1` Ĭ��ֵ��
- RadioListTile `groupValue`/`onChanged` deprecated��Flutter 3.32+����������Ǩ�Ƶ� RadioGroup

## 2026-06-03 (�޸�֪ͨBUG����ɾ/����������Ե�֪ͨ)

### ����
- **��ɾ����**��`deleteTask()` / `DeleteTask` ��δ���� `cancelReminderForSchedule()`��OS ��֪ͨ�����ճ�����
- **���������**��`toggleStatus()` �е����̬δȡ��֪ͨ���� `rescheduleTaskReminders()` ������ status/deleted�������/��ɾ������ܱ����µ���

### �޸�
- `notification_service.dart`��`rescheduleTaskReminders` ���� `deleted!=0` �� `status==2` ������`rescheduleBreakdownTaskReminders` ���� `status=='completed'` �����񣨷����㣩
- `task_new/task_bloc.dart`��`_onDeleteTask` ɾ��ǰȡ�����к��֪ͨ��`_onToggleTaskStatus` ���ʱȡ��֪ͨ���������������Դͷ�޸���
- `task/task_detail_page.dart`���ɰ棩��`_deleteTask()` �� `_updateStatus('completed')` ������֪ͨȡ��

### Ӱ���ļ�
- lib/services/notification_service.dart
- lib/presentation/blocs/task_new/task_bloc.dart
- lib/presentation/pages/task/task_detail_page.dart

### ����
- �ɰ� task_detail_page δ�����������֪ͨȡ�����ɰ��޴˹��ܣ����°� Bloc ·���Ѹ���

---

## 2026-06-03 (�޸� flutter_timezone 5.1.0 ���Ͳ�����)

### �޸�������ʧ�� �� TimezoneInfo �޷���ֵ�� String ����
- `notification_service.dart`��`FlutterTimezone.getLocalTimezone()` �� 5.1.0 ���� `TimezoneInfo` ���� `String`����ͨ�� `.identifier` ��ȡ IANA ʱ����ʶ������ `tz.getLocation()`��
### �޸������ѹ�����ȫ����Ч + ����ʽ��������
- **alarm ������Ƶ�ļ�**��`assetAudioPath: null` ���� alarm v5.4.1 ���������塣���� `assets/audio/alarm.wav`�����ɵ�Ĭ����������`loopAudio: true` ��������ֱ���û��رա�
- **ʱ������ bug**��`notification_service.dart` �� `timezone.identifier` ӦΪ `timezone`��FlutterTimezone.getLocalTimezone ���� String�������� try-catch ���׺�Ĭ�� UTC��zonedSchedule �������ʱ�䡣
- **����ʱδ����֪ͨȨ��**���� `home_page.dart._initStorage()` �����ѵ���ǰ�������� `requestMobilePermissions()`��
- **����ҳȨ����Ȩ����© Task ������**��`AppSettingsPage` ���� `taskRepository` ��������Ȩ��ͬʱ�ص��� Task �����ѡ�

### Ӱ���ļ�
- lib/services/alarm_service.dart �� assetAudioPath + loopAudio
- lib/services/notification_service.dart �� ʱ���޸�
- lib/presentation/pages/home/home_page.dart �� ����ʱ����Ȩ��
- lib/presentation/pages/profile/app_settings_page.dart �� taskRepository + ȫ���ص���
- lib/presentation/pages/profile/profile_page.dart �� ���� taskRepository
- pubspec.yaml �� assets/audio/ ����
- assets/audio/alarm.wav �� ����Ĭ������

### ����
- alarm.wav Ϊ�������ɵļ����Ҳ��������������滻Ϊ���õ���Ƶ�ļ�

---

## 2026-06-03 (��Ŀͬ�����ƶ��������޸�)

### �޸� 1����Ŀ��ͬ�����ƶ��ˣ�����Supabase ȱ is_template �У�
- ���򣺱��� Drift `projects` ���� migration v8��v9 ������ `is_template` �У�`pushProject` ���䷢�͵� Supabase���� Supabase `projects` ��ȱ�ٸ��У�����ÿ�� `upsert` �����в����ڶ�ʧ�ܣ����� try-catch ��Ĭ�̵���������ͬ��������Ϊ `pushGroup` ���� `is_template`��
- �޸���ͨ�� Management API �� Supabase `projects` ������ `is_template integer NOT NULL DEFAULT 0` �С�
- `lib/services/project_sync_service.dart`������ `forcePullAll()` ����ȡ�����������ͱ��أ���`syncAll` ���� `forcePush` ���������ڷ��������־��
- `lib/presentation/pages/home/home_page.dart`���״ε�¼�� `forcePush: true`������ `AppLifecycleListener.onResume` ���� `forcePullAll` ʵ�ִ򿪼�ˢ�¡�
- Supabase SQL��`ALTER TABLE public.projects ADD COLUMN IF NOT EXISTS is_template integer NOT NULL DEFAULT 0`��

### �޸� 2���ƶ���������ȫ����Ч��3 bug��
- Bug 1��`scheduleNotification` �� `_useOsNotifications` Ϊ false��init ʧ�ܣ�ʱ��Ĭ����֪ͨ�����κ� fallback���ޣ����δ����ʱ��֪ͨ���� `_pendingNotifications`��
- Bug 2��`_pendingNotifications` ��Զ�������ѣ�`consumePending()` ��������Ŀ�� 0 �����á��ޣ�`requestMobilePermissions` Ȩ�޴��޵���ʱ�Զ����� `consumePending()`��
- Bug 3��֪ͨȨ����Ȩ�����µ������ѡ��ޣ�`app_settings_page` ��Ȩ�ɹ����Զ����� `rescheduleScheduleReminders` + `rescheduleBreakdownTaskReminders` �����������ѣ�`_ensureMobileNotificationPermissions` ����Ҫ��ȷ����Ȩ�ޣ������豸Ĭ�Ͻ��ã��� `exactAllowWhileIdle` �Կɽ�����������

### Ӱ���ļ�
- lib/services/project_sync_service.dart
- lib/presentation/pages/home/home_page.dart
- lib/services/notification_service.dart
- lib/presentation/pages/profile/app_settings_page.dart

### ����
- `forcePush` ģʽ�����б������ݸ����ƶˣ����ƶ����и��µ�ͬ����Ŀ���ᱻ����˾����ݸ��ǡ����״ε�¼ʱ����һ�Ρ�
- ��ȷ����Ȩ�޽����󣬲��� Android �豸���ѿ����з��Ӽ��ӳ١�

---

## 2026-06-03 (�޸���ɺ��������δ��ʾ100%)

### �޸�
- ԭ��completeEligibleAncestors ����������� status==2 ���Զ���ɸ����񣬵� TaskProgressCalculator._leafTally �� task ���� + �����ϲ����㣬��������������δȫ���ʱ������ status=2 ������ <100%��
- lib/domain/tasks/task_progress_calculator.dart��_leafTally �� status==2 ʱֱ�ӷ��� _ProgressTally(1,1)�����Լ����״̬��ȷ��������������ʼ��=100%��
- test/task_progress_calculator_test.dart������ 2 ���ܱ����޸�Ӱ�������ֵ��67%��100%�����Լ� 5 �� 06-02 �Ķ��������� projectProgress ����ֵ����

### Ӱ���ļ�
- lib/domain/tasks/task_progress_calculator.dart
- test/task_progress_calculator_test.dart

### ��֤
- flutter test test\task_progress_calculator_test.dart ȫ�� 8 ������ͨ����

### ����
- completeEligibleAncestors �Խ��� status==2 �Զ���ɸ����񣬲���������������δ������"�����ȫ��ɲ����������"����ͬ���޸� completeEligibleAncestors��
# Changelog

## 2026-06-03 (思维导图初始自动定位)

### 修改
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`：打弢�思维导图时自动定位到时间朢�近的节点�?  - 新增 `_initialFocusDone` / `_offsetsLoaded` 标志位��?  - `_loadOffsets()` 完成后设 `_offsetsLoaded = true` 触发 setState�?  - `LayoutBuilder.builder` 中检测首次加载条件，调用 `_focusNearestTask(showSnackBar: false)`�?  - `_focusNearestTask` 新增 `showSnackBar` 参数；无带时间节点时 fallback 定位到第丢�个节点（不弹 snackbar）��?
### 同步链路核查结论
经代码全面审查，桌面�?移动端六类数据（任务、项目��分组��清单��附件��模板）同步链路完整，无遗漏表��移动端侧边栏分组显示的"未展弢�"是时序感知问题（同步完成�?`_syncProjectGroupExpansion` 会自动展弢�），无需修改同步代码�?
### 风险/TODO
- `_initialFocusDone` 不持久化，每次重�?`MindMapView` 都会重新自动定位丢�次（切换视图再切回��维导图会再次定位）。如霢�保持用户手动调整的视口，可改为只在首次挂载时触发�?
## 2026-06-03 (时间轴缩放云端持久化)

### 修改
- `lib/presentation/pages/home/home_page.dart`：`_hourWidth` 缩放值接入云同步�?  - 新增 `_hourWidthSyncDebounce` Timer �?`_syncHourWidth()` 方法�?00ms 防抖）��?  - 缩放按钮（`+`/`-`）和捏合手势 `onScaleUpdate` 变更后均调用 `_syncHourWidth()`�?  - 初始化时�?`cloudPrefs['timelineHourWidth']` 还原，与 `homeFilters` 在同丢� fetch 块内�?  - `dispose()` 中清�?`_hourWidthSyncDebounce`�?
### 风险/TODO
- 无新增风险；`syncPreferences` 内部已有 try/catch，离线时静默忽略�?
## 2026-06-02 (模板节点)

### 修改
- 新增 `node_templates` 本地 Drift 表��`NodeTemplateRepository`、`NodeTemplateSyncService` �?`database/migration_006_node_templates.sql`；Supabase 远端 `node_templates` 表已通过 Management API 创建，启�?RLS �?Realtime�?- 任务�?AppBar 新增“模板节点��入口，`NodeTemplatesPage` 支持维护模板名称、节点标题��描述��优先级、检查项、图片和缩进子任务��?- `TaskCreateSheet`、任务页新建、日历新建��详情页子任务新建均支持“复用模板��；复用�?`CreateTask` 自动生成描述、检查项、图片附件和子任务树�?- �?`CreateTaskPage` 接入模板标题、描述��优先级和子任务基础复用；旧本地模型不支持模板检查项和图片附件落地��?
### 验证
- `flutter pub run build_runner build --delete-conflicting-outputs` 通过�?- `flutter test test\task_mindmap_focus_test.dart` 通过�?- `dart analyze ...` 无新�?error；命令仍因仓库既�?warning/info 返回�?0�?
### 风险/TODO
- 模板图片�?base64 JSON 存入模板同步表，适合模板图片复用；超大图片会增加同步负载�?
## 2026-06-02 (首页时间轴��筛选同步��进度与运维后台)

### 修改
- 首页时间轴新增当前时间定位按钮；页面加载和小�?天模式切换后默认定位当前小时或今天��?- 首页筛��增加完成状态：全部/未完�?已完成；项目筛����节点类型筛选��完成状态筛选持久化到本地并通过 `app_preferences_sync.homeFilters` 同步到移动端，偏好同步改为合并写，避免覆盖任务页筛����?- 项目进度按末位任务和棢�查项真实计数，项目��进度直接累加根任务递归 tally，不再按根任务等�?100 分计算��?- 子任务变为完成后，若同父级全部直接子任务已完成，自动完成父任务并继续棢�查祖先��?- 首页任务详情图片区展�?DB 图片附件，支持删除��复制图片到剪贴板��拖入图片保存��?- 新增个人页��运维后台��入口，展示当前账号可访问的真实用户/任务/项目/棢�查项/附件运维数据；全量用户管理等 Admin 能力保留为服务端受控能力，不在客户端保存 PAT �?service_role�?
### 影响文件
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/attachment_section.dart`
- `lib/domain/tasks/task_progress_calculator.dart`
- `lib/data/repositories/task_repository.dart`
- `lib/services/local_storage_service.dart`
- `lib/services/supabase_service.dart`
- `lib/presentation/pages/profile/admin_ops_page.dart`
- `lib/presentation/pages/profile/profile_page.dart`
- `test/task_progress_calculator_test.dart`
- `test/task_mindmap_focus_test.dart`

### 验证
- `dart analyze ...`：无新增 error；仍有仓库既�?warning/info�?- `flutter test test\task_progress_calculator_test.dart`、`flutter test test\task_mindmap_focus_test.dart`：当前被仓库已有 `nodeTemplates` Drift 生成文件缺失/构��参数不丢�致阻断��?
### 风险/TODO
- 全量用户列表、跨用户数据查询、封�?删除用户、审计日志��备份恢复和密钥轮换必须由服务端 Admin API/Edge Function 执行，不能把 PAT �?service_role 放进 Flutter 客户端��?
## 2026-06-02 (子任务创建扩展父任务跨度)

### 修复
- 原因：子任务新建或自动插入顺延到 2026-06-03 后，父任�?`dueDate` 可能仍停留在原时间，未覆盖子任务结束时间�?- `lib/presentation/blocs/task_new/task_bloc.dart`：`CreateTask` 新任务落库后按最新任务集合扩展父链时间；`shiftedTasks` 中被自动顺延的已有子任务更新后也触发同一父链扩展�?- `test/task_mindmap_focus_test.dart`：补充新建带日期子任务��自动插入顺延已有子任务时父任务跨度覆盖子任务结束时间的回归测试，并初始化测�?Supabase/绑定当前内存仓库避免同步单例污染�?- 验证：两条新�?`flutter test test\task_mindmap_focus_test.dart --plain-name ...` 均��过；整文件测试仍失败于既有两条 `nextLoaded` 等待超时用例；定�?analyze 无新�?error，仅保留既有 `avoid_print` info�?
## 2026-06-02 (首页小时轴拖拽触发优�?

### 修改
- 原因：小时维度时间轴子任务点拖拽命中区偏小，长按拖拽不易触发�?- 调研：检�?Flutter GitHub 源码，`LongPressDraggable` 支持自定�?`delay`，底�?`DelayedMultiDragGestureRecognizer` 霢�要指针在 delay 内不超过 touch slop；因此本次同时缩�?delay 并扩大命中区�?- `lib/presentation/pages/home/home_page.dart`：拖拽触发层改为 `LongPressDraggable`，固定��明命中区为 56px x 36px，delay �?300ms，仅主键/左键可触发拖拽；拖拽位移改为累积 `onDragUpdate.delta.dx` 后按整小时吸附，松手仍走既有 `UpdateTask`�?- 影响：仅影响首页小时轴中符合原条件的可拖子任务，不新增数据库字段、仓�?API �?BLoC 事件；右键删除入口保留��?
### 风险/TODO
- `dart analyze lib\presentation\pages\home\home_page.dart` 已运行，无新�?error；命令仍因该文件既有 warning/info 返回�?0�?- 尚未做桌面端手动拖拽实机验证�?
## 2026-06-02 (Taskora 命名补齐)

### 修改
- 原因：部分构建脚本��Web manifest、README、��知测试脚本�?SQL 注释仍显示旧名称�?- `build_windows.bat`、`build_android.bat`、`open_emulator.bat`：脚本标题改�?`Taskora`；Windows 打包输出目录改为 `Taskora_windows_release`�?- `web/manifest.json`、`README.md`、`test_notification.ps1`、`database/create_sync_table.sql`、`database/migration_001_init.sql`、`database/migration_005_preferences_sync.sql`、`lib/presentation/pages/profile/about_page.dart`、`lib/services/local_storage_service.dart`、`docs/launch/*`、`openspec/changes/desktop-reminder-and-android/state.json`、`generate_pdf.py`、`generate_pdf_v3.py`：用户可见名称同步为 `Taskora`�?- 影响：不修改 Dart 包名、数据库文件名��Android applicationId 或历史归档文档��?
### 风险/TODO
- 旧的 `smart_assistant_windows_release/` 目录属于既有发布产物，本次未重命名目录本体��?
## 2026-06-02 (桌面端提醒启动恢�?

### 修复
- 原因：桌面端启动恢复提醒时只调用数据库任务重排，�?`NotificationService.rescheduleTaskReminders()` 对非 Android/iOS 直接返回；本地日程��旧本地任务和桌�?`Timer` 都没有在应用重开后恢复��?- `lib/services/notification_service.dart`：移除桌面端重排提前返回，新增本地日程��本地任务��Drift 任务三类恢复方法，并�?`shouldRescheduleReminder()` 统一过滤关闭提醒、无弢�始时间和已过期的丢�次��提醒；重复提醒即使弢�始时间已过也会恢复��?- `lib/presentation/pages/home/home_page.dart`：本地存储初始化后��登录后全量同步后��项�?任务订阅刷新后统丢�调用 `_rescheduleTaskReminders()`，恢复本地日程��旧本地任务�?Drift 任务提醒�?- `test/notification_service_test.dart`：补充提醒恢复过滤��辑测试�?- 验证：`flutter test test\notification_service_test.dart` 通过；`flutter analyze lib\services\notification_service.dart lib\presentation\pages\home\home_page.dart test\notification_service_test.dart --no-fatal-infos --no-fatal-warnings` 通过但仍报告首页文件既有 info/warning�?
## 2026-06-02 (6项功能改�?

### 修改
- **功能5 项目进度修正**：`lib/domain/tasks/task_progress_calculator.dart` �?改为只对根任务（parentId==null）累加��归进度，消除子任务被重复计入导致进度虚高的问题�?- **功能4 首页筛��持久化**：`lib/services/local_storage_service.dart` 新增 `getHomeFilterProjectIds/saveHomeFilterProjectIds`；`lib/presentation/pages/home/home_page.dart` �?`_loadData` 恢复筛����在筛��变更时写入存储�?- **功能3 通知软件图标**：新�?`android/app/src/main/res/drawable/ic_notification.xml`（单色矢量图）；`lib/services/notification_service.dart` �?`_androidDetails` �?`icon: '@drawable/ic_notification'`�?- **功能1 时间轴缩�?*：`lib/presentation/pages/home/home_page.dart` �?`_hourWidth` 改为实例变量，头部加 `−`/`+` 按钮（范�?60�?00），时间轴外层加 `GestureDetector` 支持双指捏合缩放�?- **功能2 图片快捷删除+新建添加图片**：`AttachmentImageStrip` �?`showDeleteButton` 参数，图片叠�?`×` 删除按钮；`TaskCreateSheet` 加图片��择 UI �?`_pendingImages` 状��；`CreateTask` 事件�?`pendingImages`，BLoC 在创建任务后保存图片；tasks_page.dart �?calendar_page.dart 调用处传�?`pendingImages`�?- **功能6 闹钟式提�?*：新�?`alarm: ^5.4.1` 依赖；新�?`lib/services/alarm_service.dart` 封装 `VolumeSettings.fixed + NotificationSettings + androidFullScreenIntent`；AndroidManifest �?WAKE_LOCK/USE_FULL_SCREEN_INTENT/FOREGROUND_SERVICE 等权限；iOS Info.plist �?UIBackgroundModes(audio/fetch)；AppDelegate.swift 注册 alarm 插件；`notification_service.dart` 在调�?取消时同步调�?取消闹钟�?
### 风险/TODO
- 功能2：粘贴剪贴板图片暂未实现（需 super_clipboard 等包），目前�?选择图片"按钮�?- 功能6：`assetAudioPath: null` 使用设备默认铃声；如霢�自定义声音，放置 `assets/audio/alarm.mp3` 并修�?`alarm_service.dart` 中的路径，同时在 `pubspec.yaml` 添加 assets 声明�?- 功能6 iOS：需�?Xcode Signing & Capabilities 手动弢��?"Audio, AirPlay and Picture in Picture" �?"Background fetch"�?
## 2026-06-02 (首页描述直接编辑)

### 修改
- 原因：首页任务详情描述区只能查看，不能直接��择和编辑文本��?- `lib/presentation/pages/home/home_page.dart`：描述区改为多行 `TextFormField`，输入后 600ms 防抖保存；DB 任务写入 `TaskRepository.update(description:)`，旧本地任务写入 `LocalStorageService.updateTask()`�?- 影响：仅改首页描述编辑体验，未新增数据库字段、仓�?API �?BLoC 事件�?
### 风险/TODO
- `codegraph/graphify` MCP 工具本会话未暴露，已按只读搜索定位做朢�小范围修改��?- 霢�在桌面端手动确认输入、失焦和防抖保存体验�?
## 2026-06-02 (首页时间轴长任务箭状�?

### 修改
- 原因：跨多个小时或多天的任务在首页时间轴中只显示为单个点，无法表达持续范围��?- `lib/presentation/pages/home/home_page.dart`：时间轴滚动区改为统丢�坐标 `Stack`，小时模式将同日跨小时任务按起止分钟绘制为箭状条，天模式将跨天任务按起止日期绘制为跨日箭状条；短任务仍保留圆点��?- 影响：复用原有任务��中、右键删除��节点筛选和小时模式长按拖动链路；未新增数据库字段��仓�?API �?BLoC 事件�?
### 风险/TODO
- `codegraph/graphify` MCP 工具本会话未暴露，已按只读搜索定位做朢�小范围修改��?- `flutter analyze lib\presentation\pages\home\home_page.dart` 仍受该文件既�?lint/info/warning 影响逢�出非 0，本次未处理无关项��?
## 2026-06-02 (筛��状态丢�?& 移动端��知引导)

### 修复
- **思维导图筛��状态丢�?*：flutter_bloc 9.x concurrent 转换器下，从任务详情返回时两�?`LoadTasks` 并发执行，第二个看到 `TaskNewLoading` state 导致 `preservedStatusFilter` 默认�?`'all'`�?  - `lib/presentation/pages/tasks/tasks_page.dart`：`_openTaskDetail` 返回后的 `LoadTasks` 补充 `statusFilter: state.selectedStatusFilter`�?  - `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`：`_refreshTaskList` �?`LoadTasks` 补充 `statusFilter: state.selectedStatusFilter`�?  - `lib/presentation/pages/tasks/task_detail/widgets/ai_decompose_section.dart`：两处裸 `LoadTasks()` 改为读取当前 BLoC state 并显式传�?`statusFilter`；同时新�?`task_state.dart` import�?- **移动端��知权限配置引导**�?  - `lib/services/notification_service.dart`：新�?`checkMobilePermissions()`（��过 flutter_local_notifications 平台实现棢�查是否已授权）和 `requestMobilePermissions()`（对外暴露权限申请入口）�?  - `lib/presentation/pages/profile/app_settings_page.dart`：��知区块改为动��；移动端（Android/iOS）显示权限状�?+ "请求权限"按钮，Android 额外说明精确闹钟权限引导；桌面端仍显示静态说明��?
### 风险/TODO
- 移动端权限检查和请求霢�在真�?模拟器上验证�?- 精确闹钟权限无法通过代码自动跳转到系统设置，仅文字引导��?
## 2026-06-02 (任务状��筛�?

### 修改
- 原因：任务模块需要支持按全部、未完成、已完成查看任务�?- `lib/presentation/blocs/task_new/task_event.dart`、`lib/presentation/blocs/task_new/task_state.dart`、`lib/presentation/blocs/task_new/task_bloc.dart`：新增任务状态筛选状态，并在现有项目、今�?重要、日期筛选后�?`status` 过滤�?- `lib/presentation/pages/tasks/tasks_page.dart`：AppBar 新增任务状��菜单，支持切换全部、未完成、已完成，并保留当前项目、日期和任务类型筛����?- `test/task_mindmap_focus_test.dart`：补充默认全部��未完成、已完成和裸 `LoadTasks()` 保留状��筛选的回归测试�?- 验证：`flutter test test\task_mindmap_focus_test.dart` 通过；`dart analyze lib\presentation\blocs\task_new lib\presentation\pages\tasks\tasks_page.dart` �?error，仅剩既�?info�?- 风险/TODO：未做应用内手动点击验证�?
## 2026-06-02 (日历单日并行布局修复)

### 修复
- 原因：日历周视图同一天某丢�时间段出现并行任务后，整天其它不重叠任务块也被同样压窄��?- `lib/presentation/pages/calendar/day_task_lane_layout.dart`：新增可测试的单日任�?lane 分配 helper，按连续重叠时间簇分组，并在组内贪心分配 lane�?- `lib/presentation/pages/calendar/calendar_page.dart`：单日任务块按所属重叠组�?`laneCount/laneIndex` 计算位置和宽度，不再使用整天朢��?lane 数��?- `test/calendar_day_task_lane_layout_test.dart`：覆盖独立时间段不被压窄、首尾相接不重叠、传递重叠同组分配��?- 验证：`flutter test test\calendar_day_task_lane_layout_test.dart` 通过；定�?`flutter analyze` 仅剩 `calendar_page.dart` 既有 `_startOfWeek`、`_isDragging` warning�?
## 2026-06-02 (任务详情棢�查项与图片上传微�?

### 修改
- 原因：任务详情编辑页棢�查项区域占用空间偏小，附件区缺少明确的图片上传入口��?- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`、`lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart`：提高任务详情页棢�查项区域朢�小展示高度和列表朢�大高度；`ChecklistSection` 默认列表高度保持 320，不影响其它复用处��?- `lib/presentation/pages/tasks/task_detail/widgets/attachment_section.dart`：附件标题栏新增图片上传按钮，复�?`TaskAttachmentService.pickImageFile()` �?`saveAttachment()`，原有任意文件上传入口保留��?- 影响：不修改新建任务弹窗、数据库字段、附件表结构或同步协议��?
## 2026-06-02 (子任务树刷新保留折叠�?

### 修复
- 原因：编辑子任务返回详情页后，`LoadSubTree` 刷新会把当前根任务的展开集合重置为全部一级子任务，导致用户原先折叠的节点重新展开�?- `lib/presentation/blocs/task_new/task_bloc.dart`：刷新子树时，已�?`expandedNodes[rootTaskId]` 只清理不存在的后�?ID；首次加载该根任务子树时仍默认展弢�丢�级子任务�?- `test/task_mindmap_focus_test.dart`：补充保留折叠����清理失效展弢� ID、首次加载默认展弢�丢�级子任务的回归测试��?- 验证：`flutter test test\task_mindmap_focus_test.dart` 通过；`flutter analyze --no-fatal-infos` 已运行，失败项为仓库既有 warning/info，未发现新增 error�?- 风险/TODO：手�?UI 验证仍需在应用内执行“折叠子任务�?�?编辑子任�?�?返回详情页��流程确认��?
## 2026-06-02 (Windows 文件名改�?Taskora)

### 修复
- 原因：Windows 标题栏和构建产物仍显�?输出 `smart_assistant`，未与应用名 `Taskora` 统一�?- `windows/runner/main.cpp`：窗口创建标题��已有实例查找标题和单实例互斥名改为 `Taskora`�?- `windows/CMakeLists.txt`、`windows/runner/Runner.rc`：Windows 工程名��可执行文件名和文件版本元数据改�?`Taskora` / `Taskora.exe`�?- 验证：`rg -n "smart_assistant|SmartAssistant" windows -S` 无结果；清理�?`build/windows` CMake 缓存后，`flutter build windows --debug` 通过并生�?`build\windows\x64\runner\Debug\Taskora.exe`�?- 风险/TODO：需要重新构�?Windows 包后，旧�?`smart_assistant.exe` 文件不会自动从既有发布目录删除��?
## 2026-06-01 (Taskora 多项任务体验修复)

### 修复/修改
- 原因：集中处理日历交互��任务详情��首页详情��AI 拆分、��维导图父子关系、任务创建��提醒��移动端周视图和应用命名问题�?- `lib/presentation/pages/calendar/calendar_page.dart`、`lib/presentation/pages/home/home_page.dart`、`lib/presentation/pages/tasks/task_detail/task_detail_page.dart`、`lib/presentation/pages/tasks/widgets/task_create_sheet.dart`、`lib/presentation/blocs/task_new/task_bloc.dart`、`lib/data/repositories/task_repository.dart`：完�?Ctrl+滚轮方向、右键菜单��首页详情筛选同步��检查项滚动放大、描述图片附件��项目分�?项目创建、跨周期冲突排除、父任务完成级联和移动父任务项目同步�?- `lib/services/task_decomposition_service.dart`、`lib/presentation/pages/tasks/task_detail/widgets/ai_decompose_section.dart`：增加规范化标题指纹和二次去重，降低多次 AI 拆分生成重复子任务的概率�?- `lib/services/notification_service.dart`、`lib/core/constants/app_constants.dart`、`android/app/src/main/AndroidManifest.xml`、`ios/Runner/Info.plist`、`macos/Runner/Configs/AppInfo.xcconfig`、`linux/runner/my_application.cc`、`windows/runner/Runner.rc`：提醒调度前确保初始化，Windows 普��提醒不再走 MessageBox，应用显示名改为 `Taskora`�?- 验证：`flutter test test\subtask_scheduler_test.dart` 通过；定�?`flutter analyze` 已运行，�?error，仓库仍有既�?warning/info�?- 风险/TODO：移动端提醒仍需真机确认系统权限、精确闹钟和后台调度；本次未做全量手�?UI 回归�?
## 2026-06-01 (首页小时轴子任务点拖�?

### 新增
- 原因：小时维度时间轴霢�要��过长按任务点快速提前或延后非跨天子任务�?- `lib/presentation/pages/home/home_page.dart`：小时模式下，DB 子任务��非跨天且有弢��?结束时间的任务点支持长按横向拖动，按整小时吸附并限制在原日期内，松手后派�?`UpdateTask` 同步更新弢�始和结束时间�?- 影响：不新增数据库字段��仓�?API �?BLoC 事件；根任务、父任务、跨天任务和日模式任务点不启用拖动��?- 验证：`flutter analyze lib\presentation\pages\home\home_page.dart` 已运行，失败项为该文件既�?info/warning：`avoid_print`、`use_build_context_synchronously`、`prefer_final_fields`、`curly_braces_in_flow_control_structures`、`unused_local_variable`�?
## 2026-06-01 (子任务自动延后只计算子任�?

### 修复
- 原因：父任务或普通根任务的时间范围会参与子任务创建冲�?延后计算，导�?2026-06-01 创建子任务时被父任务长条推迟�?2026-06-05 后��?- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`：新增统丢�过滤规则，冲突检测��自动延后和自动插入只把未完成��未删除、`parentId != null`、非跨天的子任务传给 `SubtaskScheduler`�?- `test/subtask_scheduler_test.dart`：补充父任务/根任务被排除、不同父任务子任务仍参与避让的回归测试��?- 验证：`flutter test test\subtask_scheduler_test.dart` 通过�?- 风险/TODO：本次不调整 `SubtaskScheduler` 通用算法；后续若霢�要��仅同父子任务避让��，霢�再改变过滤范围��?
## 2026-06-01 (日历顶部横条折叠展开)

### 修改
- 原因：周视图顶部跨天/父任务横条数量多时占用时间轴视野�?- `lib/presentation/pages/calendar/calendar_page.dart`：新�?`_isMultiDayLaneCollapsed`，顶部多日任务区域支持折叠为 30px 高的展开按钮行，展开状��保留原有最�?6 行滚动横条并增加右上折叠按钮�?- 影响：不改任务模型��仓库��Bloc、排程��辑和多日任务判定规则��?- 验证：`flutter analyze lib\presentation\pages\calendar\calendar_page.dart` 已运行，仅剩 `_startOfWeek` �?`_isDragging` 两个既有 warning�?
## 2026-06-01 (任务节点乐观刷新)

### 修改
- 原因：完成��创建等任务节点操作霢�要先展示动画和本地刷新，避免等待云同步和全量加载造成卡顿�?- `lib/presentation/blocs/task_new/task_bloc.dart`：创建��更新��删除��完成切换��父节点移动、同级排序改为本地写入后即时刷新 `TaskNewLoaded`，再执行云同步；同步失败恢复任务表快照并发出回���提示�?- `lib/data/repositories/task_repository.dart`、`lib/services/task_sync_service.dart`、`lib/presentation/blocs/task_new/task_state.dart`、`lib/presentation/pages/tasks/tasks_page.dart`：新增跳过即�?push、任务快照恢复��同步失败抛出和回��� SnackBar 提示�?- 验证：`dart analyze lib\presentation\blocs\task_new lib\data\repositories\task_repository.dart lib\services\task_sync_service.dart lib\presentation\pages\tasks\tasks_page.dart` 通过但仍有既�?info；`flutter test test\task_progress_calculator_test.dart`、`flutter test test\task_sync_service_test.dart` 通过�?- 风险/TODO：同步失败回逢�以任务表快照为准，任务操作期间若并发写入其他任务也会被一并恢复��?## 2026-06-01 (棣栭〉宓屽婊氳疆涓叉粴淇�?

### 淇�?- 鍘熷洜锛氱敤鎴峰弽棣堥紶鏍囧仠鍦ㄩ椤甸檮浠躲€佹鏌ラ」鎴栨椂闂磋酱浠诲姟鑺傜偣涓婃粴杞椂锛屽灞傞椤典篃浼氳甯﹢�姩涓婁笅婊氬姩銆?- `lib/presentation/pages/home/home_page.dart`锛氫负鏃堕棿杞翠换鍔¤妭鐐广€侢�椤甸檮浠跺尯鍜屾鏌ラ」鍖哄鍔犲眬閮ㄦ粴杞竟鐣岋紱棣栭〉闄勪欢鍖哄鍔犲彈闄愰珮搴﹢�唴閮ㄦ粴鍔ㄥ鍣ㄣ€?- 褰卞搷锛氫粎璋冩暣棣栭��灞€閮ㄦ粴杞簨浠惰竟鐣屽拰闄勪欢鍖烘粴鍔ㄥ澹筹紝涓嶆敼浠诲姟銆侢�檮浠躲€佹鏌ラ」鏁版嵁璇诲啓閫昏緫�?- 椋庨�?TODO锛氫粛闇€鍦ㄦ闈㈢��為檯榧犳爣婊氳疆楠岃瘉涓夊灞€閮ㄦ粴鍔ㄦ墜鎰熴€?
## 2026-06-01 (瀵煎嚭鍏ㄩ儴椤圭洰鍖呭惈鏈垎閰嶄换�?

### 淇�?- 鍘熷洜锛氱敤鎴烽€夋�?2026-06 鏃堕棿鑼冨洿鍜屽叏閮ㄩ��鐩鍑烘椂锛屽瓨鍦ㄩ」鐩爣绛炬樉绀轰负鈥滄湭鍒嗛厤鈥濈殑浠诲姟锛屼絾��煎嚭缁撴灉鎻愮ず鏃犳暟鎹�?- `lib/presentation/pages/profile/task_export_page.dart`锛氬綋鍏ㄩ儴椤圭洰琚€変腑鏃讹紝��煎嚭璋冪敤鏢�逛负浼犵┖椤圭洰闆嗗悎锛岃��绀轰笉鎸夐」鐩繃婊わ紝浠庤€屽寘鍚湭鍒嗛厤/鏈尮閰嶉��鐩换鍔°€?- `test/task_export_service_test.dart`锛氭柊澧炴湭鍖归厤椤圭洰浠诲姟鍦ㄧ┖椤圭洰绛涢€変笅浠嶄細杩涘叆瀵煎嚭宸ヤ綔绨跨殑鏂█�?- 楠岃瘉锛歚flutter test test\task_export_service_test.dart` 閫氳繃锛沗dart analyze lib\presentation\pages\profile\task_export_page.dart lib\services\task_export_service.dart test\task_export_service_test.dart` 閫氳繃銆?- 椋庨�?TODO锛氬鏋滃彧鍕鹃€夋煇涓叿浣撻」鐩紝鏈垎閰嶄换鍔��粛涓嶄細��煎嚭锛涢渶閫夆€滃叏閮ㄩ��鐩€濆寘鍚湭鍒嗛厤浠诲姟銆?
## 2026-06-01 (鎬濈淮��煎浘鑺傜偣杩炵嚎鍔熻兘)

### 鏂板�?- 鍘熷洜锛氭€濈淮瀵煎浘鍙兘閫氳�?`+` 鎸夐挳鏂板缓瀛愯妭鐐癸紝鏃犳硶鎶婁袱涓凡鏈夎妭鐐规墜鍔ㄨ繛绾垮缓绔嬬埗瀛愬叧绯汇€?- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`�?  - `+` 鎸夐挳鏀寔闢�挎寜鎷栨嫿鍑烘鐨瓔杩炵嚎鍒扮洰鏍囪妭鐐癸紝鏉炬墜鍚庣洰鏍囪妭鐐规垚涓哄綋鍓嶈妭鐐圭殑瀛愯妭鐐癸紙璋冪敤宸叉湁 `onMoveToParent`锛夛�?  - `_MindMapLinesPainter` 澧炲�?`connectingFrom`/`connectingTo` 鍙傛暟锛屾嫋鎷��繃绋嬩腑缁樺埗铏氱嚎璐濆灏旀鐨瓔 + 缁堢偣鍦嗙偣�?  - `_MindMapNodeCard` 鏂板�?`onConnectStart/Update/End/Cancel` 鍥涗釜鍥炶皟�?  - 鍙抽敭鐐瑰嚮鑺傜偣杩炵嚎鍖哄煙寮瑰嚭"鏂紑杩炴帴"鑿滃崟锛屾柇寮€鍚庡瓙鑺傜偣鍥炲埌鏍圭骇�?  - ESC 閿悓鏃舵竻闄よ繛绾挎嫋鎷界姸鎬侊紱
  - 杩炵嚎鏈熼棿 `_nodeDragging=true`锛岄槻姝㈢敾甯冭窡闅忓钩绉汇�?- `lib/presentation/blocs/task_new/task_bloc.dart`锛歚_onMoveTaskToParent` 寤虹珛鐖跺瓙鍏崇郴鍚庤嚜鍔ㄦ墿灞曠埗鑺傜偣鐨勬棩鏈熻寖鍥达紙startDate 鍙栨渶鏃┿€乨ueDate 鍙栨渶鏅氾級浠ュ寘鍚瓙鑺傜偣鏃ユ湡锛屼娇鏃ュ巻妯潯鑷姩瑕嗙洊姝ｇ��鍖洪棿�?- 鏃ュ巻鏃ュ巻宸叉�?`_isMultiDayTask �?_hasChildren` 閫昏緫锛岢�埗鑺傜偣杩炵嚎鍚庤嚜鍔ㄥ憟鐜颁负妯潯锛屾棤闇€棰濆鏀瑰姩�?- 楠岃瘉锛歚flutter analyze --no-fatal-infos` �?error�?- 椋庨�?TODO锛氭鐨瓔杩炵嚎缁堢偣鍛戒腑妫€娴嬩互鑺傜偣鍖呭洿鐩掍负鍑嗭紙_hitTestNode锛夛紝鑺傜偣绱у瘑鎺掑垪鏃剁洰鏍囧彲鑳戒笉濡傞鏈燂紱鍙抽敭鍒犻櫎绾跨殑鍛戒腑鍗婂緞鍥哄畾 24px锛屽彲鎸夐渶璋冩暣銆?
## 2026-06-01 (鐧诲綍淇涓庢垜鐨勬ā鍧楢�鍑?

### 淇�?鏂板�?- 鍘熷洜锛氱敤鎴峰弽棣堢櫥褰曢〉涔辩爜銆佹墜鏈哄彿鍙戦€侀獙璇佺爜鍚庨〉闈㈣烦鍥炲垵濮嬫€侊紝骞惰姹傗€滄垜鐨勨€濇ā鍧楁敮鎸佹寜鏃堕棿鑼冨洿銆侀」鐩拰閲嶈绾у埆��煎�?Excel�?- `lib/presentation/pages/auth/login_page.dart`锛氫慨澶嶇櫥褰曢〉娈嬬暀涔辩爜鏂囨�?- `lib/main.dart`銆乣lib/presentation/blocs/auth/auth_bloc.dart`锛氶潪璁よ瘉鎴愬姛鐘舵€佺户缁繚鐣?`LoginPage`锛岄伩鍏嶉獙璇佺爜鍙戦€佷腑涓㈠け鎵嬫満妯��紡锛涙墜鏈哄彿鏍煎紡鍜?Supabase Phone Auth/SMS Provider 閰嶇疆闂�杩斿洖涓枃鎻愮ず�?- `lib/services/task_export_service.dart`銆乣lib/presentation/pages/profile/task_export_page.dart`銆乣lib/presentation/pages/profile/profile_page.dart`銆乣lib/presentation/pages/home/home_page.dart`锛氭柊澧炴垜鐨勯〉��煎嚭鍏ュ彛銆佺瓫閫夐��鍜屽 Sheet 鏍戝�?Excel 瀵煎嚭锛涙柊�?`excel`銆乣archive`銆乣xml` 渚濊禆锛屼笉鏢�规暟鎹簱缁撴��銆?- `test/login_page_test.dart`銆乣test/task_export_service_test.dart`銆乣test/profile_page_test.dart`銆乣test/widget_test.dart`锛氭柊澧?鏇存柊楠岃瘉鐮佺姸鎬併€佸鍑烘湇鍔°€佸鍑哄叆鍙ｅ拰鐧诲綍椤典腑鏂囨枃妗堟祴璇曘€?- 楠岃瘉锛歚flutter test test\login_page_test.dart test\profile_page_test.dart test\widget_test.dart` 閫氳繃锛沗flutter test test\task_export_service_test.dart` 閫氳繃锛沗flutter analyze` 鍙畬鎴愪絾浠撳簱浠嶆湁鏃㈡�?97 �?info/warning�?- 椋庨�?TODO锛氳嫢椤甸潰涓嶅啢�璺冲洖鍚庝粛鏢�朵笉鍒扮煭淇★紝闇€瑕佸�?Supabase 鎺у埗鍙扮‘璁?Phone Auth 宸插惎鐢ㄥ苟閰嶇疆鐭俊鏈嶅姟鍟嗐€?
## 2026-06-01 (鎴戠殑妯″潡缂栬緫璧勬枡)

### 鏂板�?- 鍘熷洜锛氱敤鎴疯姹傝皟鐮斺€滄垜鐨勨€濇ā鍧楢�簲鍏佽缂栬緫鍝簺璧勬枡锛屽苟澧炲姞缂栬緫璧勬枡鍔熻兘�?- `lib/presentation/pages/profile/profile_page.dart`锛氳鍙栨湰鍦版樉寮忚祫鏂欙紝澶撮儴鏄剧ず鏄电О銆佽亴�?韬唤鍜屽煄甯傦紱鈥滅紪杈戣祫鏂欌€濇寜閽烦杞紪杈戦〉骞跺湪淇濆瓨鍚庡埛鏂般�?- 鏂板�?`lib/presentation/pages/profile/profile_edit_page.dart`锛氬厑璁哥紪杈戞樢�绉般€佽亴涓氭垨韬唤銆佹墍鍦ㄥ煄甯傘€佺洰鏍囧煄甯傘€佷富瑕佺洰鏍囷紱璐﹀彿閭/鎵嬫溢�鍙蜂綔涓鸿璇佷俊鎭彧璇绘彁绀猴紱淇濆瓨鍒?`LocalStorageService.saveExplicitProfile()`�?- `test/profile_page_test.dart`锛氭柊澧炵紪杈戣祫鏂欎繚瀛樺悗鍥炴樉鍜屾湰鍦板瓨鍌ㄦ柇瑷€銆?- 楠岃瘉锛歚dart analyze lib\presentation\pages\profile\profile_page.dart lib\presentation\pages\profile\profile_edit_page.dart test\profile_page_test.dart` 閫氳繃锛沗flutter test test\profile_page_test.dart` 閫氳繃銆?- 椋庨�?TODO锛氬綋鍓嶈祫鏂欏彧鍐欐湰�?SharedPreferences锛屾湭鍚屾 Supabase `user_profiles`�?
## 2026-05-31 (鑺傚亣鏃ャ€侢�€€鍑虹櫥褰曘€佸瓙浠诲姟鍚屾銆佺Щ鍔ㄧ璧勬簮甯冨�?

### 淇�?- 鍘熷洜锛氱敤鎴峰弽棣?2026 骞翠簲涓€浼戞伅鏃ユ湭��屾暣灞曠ず銆佹垜鐨勯��閫€鍑虹櫥褰曟棤鍙嶅簲銆佹闈㈢瀛愪换鍔℃棤娉曞悓姝ュ埌绉诲姩绔€佺Щ鍔ㄧ棣栭〉妫€鏌ラ��鍜岄檮浠跺悓鎺掓樉绢�恒€?- `lib/services/holiday_service.dart`锛氭柊澧炰腑�?2026 鍔冲姩鑺傛湰鍦板厹搴曡鐩栵紝琛ラ綈 2026-05-01 �?2026-05-05 浼戞伅鏃ワ紝浠ュ�?2026-04-26�?026-05-09 琛ョ彮鏃ャ€?- `lib/presentation/pages/profile/profile_page.dart`锛氶€€鍑虹櫥褰曡彍鍗曟淳鍙?`LoggedOut`锛屽苟涓烘祴璇曚繚鐣欏彲娉ㄥ�?`onLogout` 鍥炶皟銆?- `lib/presentation/blocs/task_new/task_bloc.dart`銆乣lib/services/task_sync_service.dart`锛氫换鍔″悓姝ュ叆鍙ｆ敼�?`TaskSyncService.syncAll()` �?`user_tasks` 閫愯鍚屾閾捐矾锛涙柊�?`taskToSyncRow`/`syncRowToTaskJson` 楠岃�?`parent_id` �?`parentId` 鏄犲皠銆?- `lib/presentation/pages/home/home_page.dart`锛氱獎灞忛椤典换鍔¤鎯呰祫婧愬尯鏀逛负闄勪欢銆佹鏌ラ」绾靛悜鍒嗗尯锛涙闈㈢浠嶆í鍚戝睍绢�恒€?- 鏂板�?`test/holiday_service_test.dart`銆乣test/task_sync_service_test.dart`銆乣test/profile_page_test.dart` 瑕嗙洊鏈淇銆?- 楠岃瘉锛歚flutter test test\holiday_service_test.dart test\task_sync_service_test.dart test\profile_page_test.dart` 閫氳繃锛涘叏�?`flutter test` 浠嶅け璐ヤ簬鏃㈡�?`create_schedule_dialog_test.dart` ListTile/DecoratedBox 鏂█鍜?`widget_test.dart` 鐧诲綍椤垫枃妗堟柇瑷€銆?
## 2026-05-31 (鎬濈淮��煎浘锛氳嚜鍔ㄩ攣��氭渶杩戜换�?

### 鏂板�?- 鍘熷洜锛氱敤鎴烽渶瑕佸湪鎬濈淮��煎浘鍙充笂瑙掓柊澧炲叆鍙ｏ紝鐐瑰嚮鍚庤嚜鍔ㄦ妸瑙嗚鍒囨崲鍒板綋鍓嶆椂闂存渶杩戠殑浠诲姟鑺傜偣�?- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛氭柊澧炩€滆嚜鍔ㄩ攣��氣€濆皬鎮诞鎸夐挳锛屾寜 `startDate ?? dueDate` 鏌ユ壘鏈€杩戝彲瑙佷换鍔★紝淇濇寔褰撳墠缂╂斁姣斾緥骞跺钩绉荤敾甯冨埌鑺傜偣涓績锛涙棤甯︽椂闂磋妭鐐规椂鏄剧ず鎻愮ず銆?- 褰卞搷锛氫粎褰卞搷鎬濈淮瀵煎浘瑙嗚瀹氫綅锛屼笉淇敼浠诲姟鏁版嵁銆佸竷灞€缂撳瓨銆佹嫋鎷戒繚��樻垨閲嶇疆甯冨眬閫昏緫�?- 椋庨櫓锛歚flutter analyze` �?`dart analyze` 鍦ㄦ湰鏈哄潎瓒呮椂锛岄渶鍚庣画鍦ㄥ彲�?Flutter 宸ュ叿閾句笅澶嶈窇銆?
## 2026-05-31 (浠诲姟鍒涘缓鑷姩鎻掑叆)

### 淇�?- 鍘熷洜锛氬垱寤轰换鍔″彂鐢熸椂闂村啿绐佹椂锛岄渶瑕佹敮鎸佸己鍒朵繚鐣欐柊浠诲姟鏃堕棿锛屽苟鎶婅鎸ゅ崰鐨勫悗缁换鍔＄骇鑱斿悗绉汇€?- `lib/services/subtask_scheduler.dart`锛氭柊澧?`ScheduledTaskShift` �?`autoInsert`锛屾寜鏂颁换鍔℃椂闂存銆佸伐浣滄椂娈点�?5 鍒嗛挓缂撳啿璁＄畻琚悗绉讳换鍔°�?- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`锛氬啿绐佸脊绐楁柊澧炩€滆嚜鍔ㄦ彃鍏モ€濓紝鎵€鏈変紶鍏?`TaskRepository` 鐨勫垱寤轰换鍔￠兘浼氭娴嬪啿绐佸苟杩斿�?`shiftedTasks`�?- `lib/presentation/blocs/task_new/task_event.dart`銆乣task_bloc.dart`锛歚CreateTask` 鏂板�?`shiftedTasks`锛屽垱寤哄悗鎵归噺鏇存柊琚悗绉讳换鍔℃椂闂淬€?- `tasks_page.dart`銆乣subtask_tree_section.dart`銆乣calendar_page.dart`锛氬垱寤哄叆鍙ｄ紶閫?`shiftedTasks`锛涙棩鍘嗗垱寤哄叆鍙ｄ紶�?`TaskRepository`�?- 鏂板�?`test/subtask_scheduler_test.dart` 瑕嗙洊鍚屾鎻掑叆銆佽繛缁骇鑱斿悗绉汇€佽法宸ヤ綔鏃舵鍚庣Щ銆?- 楠岃瘉锛歚dart format` 宸叉牸寮忓寲鏈�?Dart 淇敼锛沗flutter test test\subtask_scheduler_test.dart` 閫氳繃锛沗flutter analyze` 鍙畬鎴愪絾浠撳簱浠嶆湁鏃㈡�?info/warning锛涘叏閲?`flutter test` 澶辫触鍦ㄦ棦�?`create_schedule_dialog_test.dart` ListTile/DecoratedBox 鏂█鍜?`widget_test.dart` 鎵句笉鍒扳€滄櫤鑳藉皬绠″鈥濄�?
## 2026-05-31 (涓汉鎺у埗鍙伴潤鎬佺珯鐐?

### 鏂板�?- 鍘熷洜锛氱敤鎴烽渶瑕佷竴涓渶浣庢垚鏈€佷粎鏈汉鍙闂殑缃戠珯锛岢�敤浜庨厤缃姩鎬佸瘑閽ャ€佸姩鎬佹暟鎹苟绠＄悊鍚勭�?App�?- `personal_admin_site/index.html`銆乣styles.css`銆乣app.js`锛氭柊澧為潤鎬佷釜浜烘帶鍒跺彴锛屾敮�?Supabase Email OTP 鐧诲綍銆佸姩鎬佸瘑閽?鍔ㄦ€佹暟鎹?App 涓夌被绠＄悊瑙嗗浘锛涘瘑閽ュ€煎湪娴忚鍣ㄧ鍔犲瘑鍚庝繚��樸�?- `personal_admin_site/supabase.sql`锛氭柊澧?Supabase 琛ㄧ粨鏋勩€佹洿鏂版椂闂磋Е鍙戝櫒銆丷LS 绛栫暐鍜岄偖�?allowlist 绢�轰緥�?- `personal_admin_site/config.js`銆乣config.example.js`銆乣README.md`锛氭柊澧炲墠�?Supabase 閰嶇疆鍗犱綅銆佹湰鍦伴厤缃€丼upabase 鍒濆鍖栧拰 Cloudflare Pages 鍏嶈垂閮ㄧ讲璇存槑銆?- 褰卞搷锛氭柊澧炵嫭绔嬬珯鐐圭洰褰曪紝涓嶄慨鏀圭幇�?Flutter 搴旂敤浠ｇ爜�?- 椋庨�?TODO锛氬皻鏈疄闄呯嚎涓婂彂甯冿紱闇€瑕佺敤鎴锋挙閿€宸叉毚闇茬�?Supabase Personal Access Token锛屽苟鎻愪緵 Supabase `Project URL`銆乣anon public key`銆佸厑璁哥櫥褰曢偖绠卞強 Cloudflare/Git 鎵樼鍙戝竷鏉冮檺鍚庢墠鑳藉畬鎴愪笂绾裤�?
### 琛ュ�?- `personal_admin_site/_headers`锛氭柊澧?Cloudflare Pages 瀹夊叏鍝嶅簲澶淬�?- `personal_admin_site/DEPLOYMENT_PLAN.md`锛氭柊澧?0 缇庡厓鍥哄畾鎴愭湰閮ㄧ讲鏂规銆佸畼鏂��緷鎹摼鎺ャ€佷笂绾挎楠ゅ拰鍙戝竷鍓嶆鏌ラ」銆?- `personal_admin_site/deploy-check.ps1`锛氭柊澧炲彂甯冨墠妫€鏌ヨ剼鏈紝闃绘鍗犱�?Supabase 閰嶇疆鍜屾晱鎰熷瘑閽ヨ繘鍏ュ墠绔€?- `personal_admin_site/build-cloudflare.sh`銆乣build-local.ps1`锛氭柊澧?Cloudflare 鐜鍙橢�噺鏋勫缓鍜屾湰鍦?Direct Upload 閰嶇疆鐢熸垚鑴氭湰銆?- `personal_admin_site/app.js`锛歋upabase 鏈厤缃椂鏄剧ず鏄庣��鎻愮ず锛岄伩鍏嶉��闈㈤潤榛樺垵濮嬪寲澶辫触銆?- `personal_admin_site_template.zip`锛氭柊澧為潤鎬佺珯鐐逛笂浼犳ā鏉垮寘銆?- 楠岃瘉锛歚node --check personal_admin_site\app.js` 閫氳繃锛涙湰�?Node 闈欐€佹湇鍔¤姹?`/` 杩斿�?`200` 涓斿寘鍚?`Personal Control Desk`锛涚敤涓存椂鐜鍙橢�噺鎵ц�?`build-local.ps1` + `deploy-check.ps1` 閫氳繃锛岄殢鍚庡凡鎭㈠ `config.js` 涓哄崰浣嶉厤缃�?
## 2026-05-31 (鎴戠殑妯″潡琛ュ�?

### 淇�?- 鍘熷洜锛氱敤鎴疯姹傚幓鎺夋垜鐨勬ā鍧楃殑"鎻愰啋璁剧疆"锛屽苟琛ュ叏"璁剧�?甯姪涓庡弽�?鍏充�?鍐呭銆?- `lib/presentation/pages/profile/profile_page.dart`锛氱Щ�?鎻愰啋璁剧疆"鑿滃崟椤癸紱"璁剧�?甯姪涓庡弽�?鍏充�?鎺ュ叆椤甸潰璺宠浆锛汚I 鎺掔▼璺宠繃鍛ㄦ湯寮€鍏充粠鎴戠殑椤电Щ鍒拌缃〉銆?- 鏂板�?`app_settings_page.dart`銆乣help_feedback_page.dart`銆乣about_page.dart`锛氳缃�〉鍖呭惈 AI 鎺掔▼璺宠繃鍛ㄦ湯銆佷富棰樺叆鍙ｃ€侢�€氱煡璇存槑銆佹暟鎹鏄庯紱甯姪椤靛寘鍚姛鑳藉府鍔┿€佸父瑙侀棶棰樺拰鍙嶉璇存槑锛涘叧浜庨��灞曠ず浜у搧鍚嶃€佺増鏈?`1.0.0+3`銆佹牳蹇冭兘鍔涖€佹暟鎹悓姝ュ拰闅愮鏉冮檺璇存槑�?- 褰卞搷锛氫笉鏢�逛换�?鏃ョ▼璇︽儏涓殑鎻愰啋璁剧疆涓庨€氱煡璋冨害閫昏緫�?- 椋庨櫓锛氱増鏈彿鍦ㄥ叧浜庨〉鎸夊綋�?`pubspec.yaml` 闈欐€佸睍绀猴紝鍚庣画鍙戠増闇€鍚屾鏇存柊�?
## 2026-05-31 (棣栭〉浠诲姟璇︽儏锛氳祫婧愬尯鍚岃)

### 淇�?- 鍘熷洜锛氱敤鎴疯姹傞椤电殑闄勪欢鍜屾鏌ラ��鏀惧埌鍚屼竴琛屻€?- `lib/presentation/pages/home/home_page.dart`锛氬皢棣栭��?DB 浠诲姟璇︽儏搴曢儴鐨勮祫婧愬尯鏀逛负 `_buildResourceRow`锛屽瓙浠诲姟鏍戙€侀檮浠躲€佹鏌ラ」鍦ㄥ悓涓€妯悜琛屽睍绢�猴紱绉婚櫎��愪换鍔℃爲鍐呴儴棰濆椤堕儴闂磋窛�?- 褰卞搷锛氫粎璋冩暣棣栭��浠诲姟璇︽儏鍗″竷灞€锛屼笉鏀归檮�?妫€鏌ラ�?瀛愪换鍔＄殑鏁版嵁璇诲啓閫昏緫銆?- 椋庨櫓锛氱獎灞忎笅妯悜涓夊垪鍙敤瀹藉害鍙樺皬�?
## 2026-05-30 (鏃ュ巻鍛ㄨ鍥撅細婊戝姩鏃跺ご閮ㄦ棩鏈熶笌涓嬫柟缃戞牸鍚屾)

### 浼樺�?- 鍘熷洜锛氬懆瑙嗗浘宸﹢�彸鎷栧姩鍒囨崲鏃ユ湡鏃讹紝浠呬笅�?body锛堟椂闂村垪+缃戞�?浠诲姟鍧楋級璺熸墜骞崇Щ锛岄��閮?鏄熸�?鏃ユ�?澶撮儴涓嶅姩锛屽鑷翠袱鑰呮í鍚戦敊浣嶃€佽瑙夎劚绂?- `lib/presentation/pages/calendar/calendar_page.dart`�?  - `_buildDayStripHeader` �?鏄熸�?鏃ユ�?琛屽灞傚寘�?`ClipRect` + `Transform.translate(offset: Offset(_dragOffset, 0))`锛屽鐢?body 鍚屾�?`_dragOffset`锛屼娇澶撮儴涓庝笅鏂圭綉鏍煎垪鎷栧姩杩囩▼涓í鍚戝悓姝ュ钩绉?  - 鏈堜唤��艰埅琛岋紙`< 骞存湢� >`锛変繚鎸佸浐瀹氾紝涓嶅弬涓庡钩绉?- 褰卞搷锛氫粎澶撮儴娓叉煋鍖呰锛屾湭鏢�?`_dragOffset` 璧嬪�?鎷栧姩鍥炶皟/鍚搁檮鍒囨崲閫昏緫锛涙湀瑙嗗浘銆佺旱鍚戞粴鍔ㄣ€佺缉鏢�俱€佷换鍔��潡鎷栨嫿鍧囦笉鍙楀奖鍝?- 椋庨櫓锛氫綆

## 2026-05-30 (棣栭〉浠诲姟璇︽儏锛氭柊澧炶祫婧愬尯)

### 鏂板�?- 鍘熷洜锛氶椤典换鍔¤鎯呭崱鐨勬鏌ラ��鍖哄煙浠呬负鍙棰勮锛堟渶�?鏉★級锛屼笖鏃犻檮浠跺叆鍙ｏ紝鏃犳硶鍦ㄩ椤电洿鎺ユ搷浣?- `lib/presentation/pages/home/home_page.dart`�?  - 鏂板�?`_dbTaskCache`锛坄Map<String, Task?>`锛夌紦��?DB Task 瀵硅薄锛屼緵 `AttachmentSection` 浣跨�?  - 鏂板�?`_loadDbTask` / `_homeToggleChecklist` / `_homeDeleteChecklist` / `_homeEditChecklist` / `_homeAddChecklist` / `_homeSetObsidianUri` 鍏釜鏂规硶锛屽鎺?`ChecklistRepository` CRUD
  - 鏂板�?`_buildResourceSection` / `_buildAttachmentWidget` / `_buildChecklistWidget`锛氬乏鍙充袱鍒楀竷灞€锛屽乏鍒楀鐢?`AttachmentSection`锛屽彸鍒楢�鐢?`ChecklistSection`锛堟敮鎸佸嬀�?娣诲�?鍙屽嚮缂栬緫/闢�挎寜 Obsidian 鍏宠仈锛?  - 鍒犻櫎鍙�?`_buildChecklistPreview` 鏂规�?  - `_buildTaskDetail` 搴曢儴鏇挎崲涓鸿祫婧愬尯锛屼粎��?`source == 'db'` 浠诲姟鏄剧ず
- 椋庨櫓锛氫綆锛涢檮浠?妫€鏌ラ」渚濊禆宸叉�?service/repo锛岃涓轰笌浠诲姟璇︽儏椤靛畬鍏ㄤ竴鑷达紱鏃堕棿杞磋楂樹笉鍙楀奖鍝?
## 2026-07-17 (鎬濈淮��煎浘锛氫慨澶嶇偣鍑荤┖鐧藉鍙栨秷妗嗛€変笉鐢熸晥)

### 淇�?- 鍘熷洜锛氬師�?`Listener` 鏢�惧湪 `InteractiveViewer` 鍐呴�?Stack 搴曞眰锛屾闈㈢�?`InteractiveViewer` �?`ScaleGestureRecognizer` 鎷︽埅鎸囬拡浜嬩欢锛屽鑷村瓙绾?`Listener.onPointerUp` 鏢�朵笉�?�?鐐瑰嚮绌虹櫧澶勬棤娉曟竻�?`_selectedIds`
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`�?  - 鍒犻�?Stack 鍐呭眰鐨?`Positioned.fill` + `Listener`锛堝�?debugPrint�?  - �?`_buildMindMapCanvas` 鐨勫灞?Stack 涓紝鐢?`Listener`锛坄HitTestBehavior.translucent`锛夊寘瑁?`InteractiveViewer`锛屽悓鏍烽€昏緫锛歱ointerDown 璁板綍浣嶇疆锛宲ointerUp 璺濈�?<8px �?`_selectedIds` 闈炵┖鍒欐竻�?  - 澶栧�?Listener 涓嶉樆濉炲瓙绾ф墜鍔匡紙鎷栨嫿鑺傜偣銆丆trl+妗嗛€夈€佸钩绉荤敾甯冨潎姝ｅ父�?- 椋庨櫓锛氫綆锛屼粎鏀瑰彉 Listener 灞傜骇浣嶇疆锛岃涓洪€昏緫涓嶅�?
## 2026-05-30 (鎬濈淮��煎浘锛氱偣鍑荤┖鐧藉鍙栨秷妗嗛€?

### 淇�?- 鍘熷洜锛欳trl+宸﹂敭妗嗛€夎妭鐐瑰悗锛屾澗寮€ Ctrl 閫変腑楂樹寒鎸佺画淇濈暀锛屾棤鎵嬪娍鍙竻绌猴紝浣撻獙涓?鏃犳硶鍙栨秷"
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`�?  - `canvasContent()` �?`Stack` 鏈€搴曞眰鏂板鍏ㄥ睆鑳屾櫙 `Listener`锛坄HitTestBehavior.translucent`锛夛紝`onPointerUp` 鏃惰嫢鎸変笅鍒版姮璧蜂綅�?<8px �?`_selectedIds` 闈炵┖鍒欐竻绌哄�?`setState`
  - 鏂板��楁�?`_bgPointerDownPos` 璁板綍鎸変笅浣嶇疆锛岢�敤浜庡尯�?鐐瑰�?�?骞崇Щ"
  - 鏢�圭敤 `Listener`锛堢粫杩囨墜鍔跨珵鎶€鍦猴級鑰岄�?`GestureDetector.onTap`锛氬悗鑰呬綔�?`InteractiveViewer` 瀛愯妭鐐规椂绌虹櫧澶?tap 浼氳鍏剁缉鏢�捐瘑鍒櫒鎶㈣蛋锛屽鑷撮鐗堟棤鏁?- 椋庨櫓锛氫綆锛屾湭鏀瑰姩鐜版湁妗嗛€?鎷栨�?閿洏閫昏緫锛涘钩绉讳粛姝ｅ父锛堜綅�?8px 涓嶈Е鍙戞竻绌猴級

## 2026-07-15 (鏃ュ巻鍛ㄨ鍥炬嫋鎷芥敼�?Transform 璺熸墜骞崇�?

### 淇�?- 鍘熷洜锛氭嫋鎷戒笉璺熸墜鈥斺€旈槇鍊兼柟寮忎笉鎻愪緵瑙嗚鍙嶉锛屾闈㈤紶�?delta 澶ф椂涓€娆¤烦澶氬�?- `lib/presentation/pages/calendar/calendar_page.dart`�?  - 鏂板�?`_dragOffset` / `_cachedDayWidth` 瀛楁�?  - `_buildWeekTimeline`锛歚GestureDetector` + `Transform.translate` 鍖呰９澶氭棩�?鏃堕棿绾匡紝`_dragOffset` 椹卞姩骞崇�?  - `_onCalendarHorizontalDragUpdate`锛氱疮鍔?`details.delta.dx` �?`_dragOffset` + `setState`
  - `_onCalendarHorizontalDragEnd`锛歚-(_dragOffset / _cachedDayWidth).round()` 绠楀ぉ鏁板亸�?�?鏇存�?`_focusedDay` �?褰掗�?`_dragOffset`

## 2026-05-30 (澶氫富棰樺垏鎹細鏋佸厜�?+ 鏇滅煶榛?

### 鏂板�?- 鍘熷洜锛氬師浠呬竴濂楢�啓姝荤殑 Claude 鏆栫強鐟氳壊涓婚锛宲rofile"涓婚�?鑿滃崟涓虹┖澹筹紙`onTap: () {}`锛夛紱闇€鍦ㄩ粯璁や富棰樺澧炲姞涓ゅ澶у巶鏍囧噯鍙垏鎹富棰?- 閲嶆�?`lib/core/theme/app_theme.dart`锛氭娊鍑?`AppPalette` 璋冭壊鏉挎ā鍨嬶紙鎸佹湁鍏ㄩ儴棰滆�?token + `ThemeData build()`锛夛紝��氫箟涓夊瀹炰�?`claude`/`auroraBlue`锛圙oogle Material 3 钃濓�?`obsidian`锛堟繁鑹叉ā寮忥級锛沗AppTheme` 棰滆�?token �?`static const` 鏢�逛负濮旀�?`_current` 璋冭壊鏉跨殑 `static get`锛屽澶?API 鍚嶄笉鍙橈紝653 澶勫紩鐢ㄩ浂鏢�瑰姩
- 鏂板�?`lib/core/theme/theme_controller.dart`锛歚ThemeController`锛圕hangeNotifier锛夋寔涔呭寲 + 閫氱煡閲嶅缓锛屽叏灞€鍗曚緥 `themeController`
- 鏂板�?`lib/presentation/pages/profile/theme_settings_page.dart`锛氫笁寮犻瑙堝崱閫夋嫨椤碉紝��炴椂鍒囨崲
- `lib/services/local_storage_service.dart`锛氭柊澧?`_themeKey`/`themeId`/`setThemeId`锛圫haredPreferences 鎸佷箙鍖栵級
- `lib/main.dart`锛歚main()` �?`await themeController.load()`锛沗MaterialApp` 澶栧�?`ListenableBuilder`锛宍theme/darkTheme: AppTheme.themeData`锛宍themeMode` 闅忓綋鍓嶈皟鑹叉澘浜?鏆楀垏鎹?- `profile_page.dart`锛氫富棰樿彍鍗曟帴鍏?`Navigator.push` 鍒拌缃��?- 褰卞搷锛氬洜棰滆�?token �?const �?getter�?15 �?const 涓婁笅鏂囧紩鐢�?5 鏂囦欢锛夊幓�?`const`锛堣剼鏈壒�?+ 5 �?const 鍒楄〃��楅潰閲忔墜宸ユ�?final�?- 椋庨櫓锛氬幓 const 鍚庝骇鐢?~89 �?`prefer_const` info 绾ф彁绢�猴紙闈炶嚧鍛斤級锛涙洔鐭抽粦娣辫壊涓嬩釜鍒啓姝?`Colors.white/black` 澶勯渶鐩瀵规瘮搴︼紱鍒囨崲椤典竴娆℃€ц绠楋紝鎬ц兘褰卞搷鍙拷鐣?
## 2026-05-30 (涓汉涓績缁熻鍗＄湡瀹炴暟鎹?

### 淇�?- 鍘熷洜锛氫釜浜轰腑蹇?鎬讳换鍔?瀹屾垚鐜?杩炵�?涓哄啓姝荤殑 128/78%/15澶╋紝闇€鎸夌湡瀹炰换鍔℃暟鎹覆鏌?- `ProfilePage` 澧炲�?`taskRepository` 鍙┖鍙傛暟锛沗_init()` 涓媺鍙?`getAll()` 璁＄畻鎬讳换鍔℃暟銆佸畬鎴愮巼锛坰tatus==2 鍗犳瘮鍥涜垗浜斿叆锛夈€佽繛缁ぉ鏁帮紙�?`completedTime` 鏈湴鏃ユ湡杩炵画鍥炴函锛屼粖鏃ユ湭瀹屾垚鍒欎粠鏄ㄦ棩璧风畻�?- `_buildStatsSection` �?`_total/_completionRate/_streak` 鏇挎崲鍐欐�?- `home_page.dart` �?`const ProfilePage()` 鏢�逛负浼犲�?`widget.taskRepository`
- 鏂囦欢锛歭ib/presentation/pages/profile/profile_page.dart, lib/presentation/pages/home/home_page.dart
- 椋庨櫓锛歚taskRepository` 涓虹┖鏃剁粺璁℃樉绀?0锛涘垏鎹㈠埌"鎴戠�?椤垫椂涓€娆℃€ц绠楋紝鏂板�?瀹屾垚浠诲姟鍚庨渶閲嶈繘璇ラ〉鍒锋柊

## 2026-06-06 (鍥涜薄闄愬垪婧㈠�?+ 鍘婚€炬湡鎻愮ず)

### 淇�?- 绉婚�?`_buildQuadrantChart` �?`q.removeRange(5, q.length)` 纭笂闄愭埅�?- 绉婚櫎椤堕儴 `"N 涓换鍔″凡閫炬�?` 绾㈣壊妯箙�?`overdueCount` 鍙橀�?- 绉婚�?`_buildQuadrant` 搴曢�?`"N 閫炬�?` 绾㈣壊鏂囧瓧
- 閲嶅�?`_buildQuadrant`锛氫换鍔℃寜姣忓�?5 鏉��垎鐗囷紝澶氬垪 `SingleChildScrollView` 妯悜婊氬姩锛屽垪闂?1px 鍒嗛殧绾匡紝绉婚�?`tasks.take(4)` + `"+N 鏇村�?`
- 鏂囦欢锛歭ib/presentation/pages/home/home_page.dart

## 2026-06-06 (鎬濈淮��煎�?Ctrl+妗嗛€夊鑺傜偣鍔熻�?

### 淇�?- 璐熷潗鏍囪妭鐐瑰啢�鎷栧姩鈫掑叏鑱斿姩锛氱敾甯冨昂��?`abs()` �?鎭㈠鍘熷姝ｅ悜鎵╁睍锛岄伩鍏?InteractiveViewer 閲嶈�?viewport
- 鑺傜偣鎵€鏈夋柟鍚戣嚜鐢辨嫋鎷斤細绉婚櫎 `clamp(0,�?` / `clamp(6,�?` 闄愬�?- Ctrl+妗嗛€夐噸鍐欙細`ValueNotifier<_ctrlPressed>` + `ValueListenableBuilder` + `IgnorePointer` 鍗虫椂鍒囨崲鏋舵瀯锛沗GestureDetector` overlay 鎷︽埅妗嗛€夋墜�?- 閫変腑鑺傜偣钃濊壊杈规楂樹�?+ Esc 娓呴櫎閫変腑
- 鏂囦欢锛歭ib/presentation/pages/tasks/widgets/mind_map_view.dart

## 2026-06-06 (鎬濈淮��煎浘鎵嬪娍淇�?+ 棣栭〉缁熻浼樺�?

### 淇�?- 鎬濈淮��煎浘鑺傜偣涓婃嫋鍚?+"鎸夐挳鐐逛笉鍔細`_MindMapNodeCard` 鑷敱鎷栨嫿妯��紡 GestureDetector 鏢�圭敤 `onPanDown`锛堟�?`onPanStart` 鏇存棭瑙﹢�彂锛岃 `_nodeDragging=true`�? 鏂板�?`onPanCancel` 娓呯悊銆? 鎸夐挳鍔?`HitTestBehavior.opaque` + 鐑�?28�?8�?- 鎷栭噸鍙犺妭鐐瑰鑷存暣妫垫爲涓€璧锋嫋鍔細鍚屼笂锛宍onPanDown` 鏇夸�?`onPanStart` 纭�?InteractiveViewer �?pan �?hit test 闃舵琚鐢紝`onPanCancel` 闃叉�?`_nodeDragging` 娈嬬暢��?
### 浼樺�?- 棣栭�?涓嬪崍濂?涓庣粺璁″崱鐗囷紙浠婃棩浠诲�?瀹屾垚鐜?閫炬湡锛夊悎骞朵负鍚屼竴�?Row 甯冨眬锛岢�粺璁″崱鐗囨敼涓虹揣�?inline 鏍峰紡锛岢�偣鍑诲彲灞曞紑��屾暣璇︽儏锛堝惈鍛ㄦ湡鍒囨崲锛夈€?- 鍛ㄦ湡鍒囨崲绉昏嚦璇︽儏寮圭獥鍐咃紝涓婚〉闈粎鏄剧ず褰撳墠鍛ㄦ湡鏁版嵁�?
## 2026-05-30 (浠诲姟妯″潡 6 �?Bug 淇�?

### 淇�?- 鏃ユ湡绛涢€夋竻闄ゅけ鏁堬細`LoadTasks` 鏂板�?`clearDateRange`锛宍task_bloc._onLoadTasks` 娓呴櫎鏃跺己鍒舵�?`dateFrom/dateTo` �?null锛堝�?`?? preservedDateFrom` 浼氫繚鐣欐棫绛涢€夊鑷存竻涓嶆帢�銆佹棤娉曢噸璁撅級銆俙tasks_page` 娓呴櫎鍒嗘敮�?`clearDateRange: true`�?- 鑺傚亣鏃ヤ笉鏄剧ず锛歚holiday_service._fetchChina` 鏁版嵁婧?`timor.tools` 宸蹭笉鍙揪锛屽け璐?绌虹粨鏋滄椂鍥為€€ `date.nager.at`锛圕N锛屼粎娉曞畾鑺傚亣鏃ワ紝鏃犺皟浼戣ˉ鐝級�?- 瀛愪换鍔℃椂闂村啿绐佹娴嬩粎鎬濈淮瀵煎浘鍏ュ彛鐢熸晥锛氳鎯呴�?`subtask_tree_section._showAddSubTaskDialog` 鍘熶负绾爣棰樺璇濇銆佹棤鏃堕棿鏃犳娴嬶紝鏢�逛负澶嶇�?`TaskCreateSheet`锛堝惈寮€濮?鎴鏃堕棿 + `_checkConflict` 鍐茬獊妫€娴嬶級锛岃繑鍥炲悗娲惧�?`CreateTask(parentId)` 骞跺埛鏂板瓙鏍戙�?- 鎬濈淮��煎浘鑺傜偣涓婃嫋鍚?+"鐐��笉鍔細`mind_map_view` `onDragUpdate` 閽冲埗鑺傜偣鍧愭�?`dx>=0/dy>=6`锛岄槻姝㈣秺鍑虹敾甯?`SizedBox` 瀵艰�?`Clip.none` 婧㈠嚭鍖烘棤娉曞懡涓€?- 鎷栧崟涓妭鐐规暣鐗囩敾甯冭仈鍔細鏂板�?`_nodeDragging` 鏍囪锛岃妭鐐规嫋鎷芥湡�?`InteractiveViewer.panEnabled = !_nodeDragging`锛岄伩鍏嶇敾甯冨钩绉讳笌鑺傜偣鎷栨嫿鍚屾椂瑙﹢�彂锛堟挙閿€涓婁竴鐗?鎭掍�?true"鐨勫垽鏂級�?
### 淇�?- `tasks_page.dart`锛氱Щ�?AppBar 鍙充笂瑙?鏂板缓椤圭洰"鎸夐挳锛堟娊灞夊唴鍏ュ彛淇濈暢�锛夈�?
---

## 2026-05-30 (鐢诲竷鎷栧姩淇�?+ 瀛愪换鍔℃椂闂村啿绐佹�?

### 淇�?- `mind_map_view.dart`锛歚InteractiveViewer` �?`panEnabled` �?`!_freeDragMode`�? false锛夋敼涓?`true`锛屾仮澶嶇敾甯冭嚜鐢卞钩绉汇€侳lutter 鎵嬪娍绔炴妧鍦鸿嚜鍔ㄥ鐞嗚妭鐐规嫋鎷戒笌鐢诲竷鎷栨嫿鐨勪紭鍏堢骇锛屼笉闇€瑕佹墜鍔ㄥ叧闂�?
### 鏂板�?- `task_create_sheet.dart`锛氭柊澧?`TaskRepository? taskRepository` 鍙€夊弬鏁般€傚綋鍒涘缓��愪换鍔★紙`initialParentId != null`锛夋椂锛宍_submit` 鍦ㄦ彁浜ゅ墠鏌ヨ宸叉湁浠诲姟鏃堕棿娈碉紝妫€娴嬪尯闂撮噸鍙狅紝寮瑰啿绐佹彁绢�哄脊绐楋紝鏀寔涓夌澶勭悊鏂瑰紡锛氬苟琛岋紙淇濇寔鍘熸椂闂达級銆佸彇娑堛€佽嚜鍔ㄥ欢鍚庯紙鍒╃�?`SubtaskScheduler` 璁＄畻涓嬩竴绌洪棽鏃舵锛夈�?
### 淇�?- `tasks_page.dart`锛歚_showCreateTaskSheet` 浼犲�?`taskRepository` �?`TaskCreateSheet`
- `calendar_page.dart`锛歚_showCreateTaskSheet` 浼犲�?`taskRepository` �?`TaskCreateSheet`

### 椋庨�?- 鑷姩寤跺悗浣跨�?`SubtaskScheduler`锛屽伐浣滄椂娈甸檺��?09:00�?1:00锛涜嫢鎵€鏈夋椂娈靛凡婊★紙鐞嗚鏋佺鎯呭喌锛夛紝杩斿�?null锛屾鏃朵繚鎸佸師鏃堕棿鍒涘�?
## 2026-05-30 (鎵嬫溢�绔换鍔℃彁閱掑彲闈犳€т慨澶?+ 鏉冮檺寮曞)

### 淇�?- Android/iOS 绔彁閱掓敼�?`zonedSchedule`锛堢郴缁?AlarmManager锛夛紝涓嶅啀渚濊�?Flutter 杩涚▼��樻椿锛汚pp 琚�?鍚庡彴鍚庨€氱煡浠嶅彲瑙﹢��?- 绉婚�?Android/iOS 鍒嗘敮鐨?Timer 璺緞锛涙闈㈢淇濈暀 Timer

### 鏂板�?- `AndroidManifest.xml`锛氭坊鍔?`RECEIVE_BOOT_COMPLETED` 鏉冮�?+ `ScheduledNotificationBootReceiver`锛岄噸鍚悗鑷姩鎭㈠宸茶皟搴﹂€氱煡
- `lib/services/permission_service.dart`锛氬皝瑁呰繍琛屾椂閫氱煡鏉冮檺鐢宠锛坄requestNotificationPermission`�? 棣栨鍚姩寮曞�?dialog锛坄showNotificationGuideIfNeeded`锛夛紝鐢?`SharedPreferences` 闃叉閲嶅寮瑰�?
### 淇�?- `pubspec.yaml`锛氭坊鍔?`timezone: ^0.10.1`锛宍notification_service.dart` �?`init()` 涓皟鐢?`tz.initializeTimeZones()`
- `lib/presentation/pages/home/home_page.dart`锛氶娆¤繘鍏?`HomePage` 鏃堕€氳�?`addPostFrameCallback` 瑙﹀彂閫氱煡鏉冮檺寮曞
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`锛歚_reminderEnabled` 绫诲瀷鐢?`int` 鏢�逛负 `bool`锛屾秷闄や笌 model �?bool 鐨勭被鍨嬩笉涓€�?
### 椋庨�?- `zonedSchedule` 闇€瑕佽澶囨敮鎸佺簿纭�椆閽燂紙`SCHEDULE_EXACT_ALARM`锛夛紝Android 12+ 鐢ㄦ埛鑻ュ湪绯荤粺璁剧疆鍏抽棴绮剧��闂归挓鏉冮檺锛岄€氱煡浠嶅彲鑳藉欢�?- 閲嶅惎鍚庢仮澶嶄緷璧?`flutter_local_notifications` 鍐呯�?Receiver 宸ヤ綔姝ｅ父锛岄渶鐪熸満楠岃�?
## 2026-05-30 (鏃ュ巻鑺傚亣鏃ユ樉绀?+ 澶氬浗鍒囨崲)

### 鍔熻�?鏃ュ巻椤甸潰鏢�寔鏄剧ず娉曞畾鑺傚亣鏃ワ紙绾㈣壊锛夈€佽皟浼戣ˉ鐝紙钃濊壊锛夛紝鍙垏鎹㈠浗��讹紙榛樿涓浗锛夛紝鏁版嵁浠?API 瀹炴椂鎷夊彇骞剁紦��?7 澶┿�?
### 鏂板�?- `lib/services/holiday_service.dart`锛氳妭鍋囨棩鏈嶅姟锛屼腑鍥界�?timor.tools API锛屽叾浠栧浗瀹剁�?date.nager.at锛沗SharedPreferences` 7 澶╃紦��?+ 鏂綉闄嶇骇

### 淇�?- `lib/presentation/pages/calendar/calendar_page.dart`�?  - AppBar 鏂板鍥芥棗鎸夐挳锛屽垏�?馃嚚馃嚦馃嚭馃嚫馃嚡馃嚨馃嚞馃嚙馃嚢馃嚪 浜斿浗鑺傚亣�?  - 鍛ㄨ鍥炬棩鏈熷ご锛坄_buildCustomWeekHeader`锛夛細鑺傚亣鏃ュ悕绉版樉绢�哄湪鏃ユ湡鍦嗗湀涓嬫�?  - 鏈堣鍥撅紙`_buildTableCalendar`锛夛細浣跨敤 `calendarBuilders` 鍦ㄦ牸��愬唴鏄剧ず鑺傚亣鏃ュ皬�?  - 骞翠唤鍒囨崲鏃惰嚜鍔ㄦ媺鍙栨柊骞翠唤鏁版�?
### 椋庨�?- 澶栭�?API锛坱imor.tools / date.nager.at锛変笉鍙敤鏃朵粎鏄剧ず缂撳瓨鏁版嵁锛涘垵娆′娇鐢ㄦ棤缂撳瓨鍒欒妭鍋囨棩涓虹�?- timor.tools 鐩墠鍙彁渚涜�?2 骞存暟鎹紝瓒呭嚭鑼冨洿鐨勫勾浠借繑鍥炵�?
## 2026-05-30 (淇鎬濈淮瀵煎浘��愪换鍔℃秷�?

### 鏍瑰�?`ProjectSyncService._upsertProjectFromRow` 鏢�跺埌浜戠椤圭洰澧撶�?(`deleted=1`) 鍚庯�?*鏃犳潯浠剁骇鑱旇蒋鍒犺椤圭洰涓嬪叏閮ㄤ换鍔?*锛屼笖鑷韩鏃犲纰戜繚鎶ゃ�?鍚姩鏃?`ProjectSyncService.syncAll()` 鍏堜�?`TaskSyncService.syncAll()` 鎵ц锛屼换鍔″湪浠诲姟鍚屾寮€濮嬪墠灏辫娓呮帢��?
鍚屾椂淇�?`_onRemoteDelete` (task) 鍜岄」鐩?Realtime DELETE 鍥炶皟鐨勫悓绫婚棶棰樸€?
### 淇�?- `lib/services/project_sync_service.dart`: `_upsertProjectFromRow` 鍔犲纰戜繚鎶も€斺€旀湰鍦板瓨娲婚」鐩嫆缁濊繙绔纰戯紝涓嶇骇鑱斿垹浠诲姟锛涢」鐩?Realtime DELETE 鍥炶皟鍔犲纰戜繚鎶?- `lib/services/task_sync_service.dart`: `_onRemoteDelete` 鍔犲纰戜繚�?- `lib/data/repositories/task_repository.dart`: `delete()` 鍔犳棩蹇?
### 褰卞搷鏂囦欢
- `lib/services/project_sync_service.dart`
- `lib/services/task_sync_service.dart`
- `lib/data/repositories/task_repository.dart`

## 2026-06-04 (鎬濈淮��煎浘鎷栧姩鎬ц兘浼樺�?

### 鏍瑰�?1. `_lineAnimController` 姣忔�?`onPanUpdate` 閲嶇疆鍔ㄧ敾�?锛宎nimation listener 棰濆瑙﹢��?~18 �?`setState`锛屾瘡甯у疄闄呰Е鍙?2+ 娆��叏�?rebuild
2. 姣忔�?`setState` 瑙﹀彂��屾�?`build()` �?閲嶆柊鎵ц�?`_buildTree / _layoutTree / _collectNodes` �?O(n) 璁＄�?3. 姣忓抚鍏ㄩ噺閲嶅缓鎵€鏈夎妭�?Widget锛屾�?RepaintBoundary 闅旂�?4. `build()` 鍐呮湁澶ч�?`print` 璋冭瘯鏃ュ織

### 淇敼鍐呭
1. 鍒犻�?`_lineAnimController` 鍔ㄧ敾鎺у埗鍣?+ `_animatedPositions` + `_manualOffsets`
2. 鏂板甯冨眬缂撳瓨锛坄_cachedPendingNodes/Lines/CanvasSize` 绛夛級锛宍initState` / `didUpdateWidget` 涓绠楋紝`build()` 鐩存帴璇荤紦�?3. 鎷栨嫿鏀逛负 `ValueNotifier<Offset>` 姣忚妭鐐圭嫭�?+ `ValueListenableBuilder`锛屽彧閲嶅缓琚嫋鎷借妭�?4. 杩炵嚎灞傜敤 `AnimatedBuilder` + `Listenable.merge` 鐩戝惉鎵€鏈?notifier锛屽彧閲嶅缓 `CustomPaint`
5. 鍒犻�?`build()` 鍐呮墍鏈?`print` 璋冭瘯鏃ュ織
6. 姣忎釜鑺傜偣澶栧�?`RepaintBoundary`

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

## 2026-06-04 (鎷栨嫿浣嶇疆鎸佷箙鍖?+ 鐢ㄦ埛闅旂)

### 淇敼鍐呭
1. `MindMapView` 鏂板�?`userId` 鍙傛�?2. `_loadOffsets()` �?�?SharedPreferences 鍔犺浇宸蹭繚瀛樺亸绉伙紝key �?`mindmap_offsets_<userId>`
3. `_saveOffsets()` �?鎷栨嫿缁撴潫鏃跺�?`_draggedIds` 瀵瑰簲浣嶇疆搴忓垪鍖栦负 JSON 淇濆�?4. `onDragEnd` 鍥炶皟璋冪敤 `_saveOffsets()` �?鏉惧紑榧犳爣鍗冲埢鎸佷箙�?5. 閲嶇疆鎸夐挳鍚屾椂娓呴櫎鎸佷箙鍖栨暟�?6. `TasksPage` �?`AuthBloc` 鎻愬�?userId锛圫upabase `user.id` 鎴栨湰鍦?`local_<email>`锛夊苟浼犲叆

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`

## 2026-05-30 (淇鎬濈淮瀵煎浘��愪换鍔￠噸鍚悗琚簯绔鐭宠鐩栧垹闄?

### 鏍瑰�?`syncAll` 浠庝簯绔媺鍙栨椂锛屼簯绔畫鐣欐棫�?`deleted=1` 澧撶煶璁板綍锛宍syncFromJson` �?LWW 閫昏緫灏嗘湰鍦版椿浠诲姟(deleted=0)瑕嗙洊涓?deleted=1銆傚悓鏃?`taskRepository.create` �?`push` �?await锛屽瓨鍦ㄧ珵鎬併�?
### 淇敼鍐呭
1. `task_repository.dart:syncFromJson` �?鏂板鍙嶅悜澧撶煶淇濇姢锛氭湰鍦版椿浠诲�?deleted=0)涓嶈杩滅澧撶�?deleted=1)瑕嗙�?2. `task_repository.dart:create` �?`push` 鏢�逛负 await锛屾秷闄ょ珵�?3. `task_sync_service.dart:syncAll` �?鏈湴娲讳絾浜戠鏄鐭虫椂涓诲姩鎺ㄩ€佽鐩栵紝淇娈嬬暀澧撶�?4. 鏂板�?`file_logger.dart` 鏂囦欢鏃ュ織宸ュ�?+ 鍏抽敭璺緞璇婃柇鏃ュ織

### 褰卞搷鏂囦欢
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `lib/core/utils/file_logger.dart`锛堟柊澧烇級

### 椋庨�?- 浣庯細鍙嶅悜澧撶煶淇濇姢鍙兘��艰嚧鐢ㄦ埛鍦ㄥ叾浠栬澶囧垹闄ょ殑浠诲姟鍦ㄦ湰璁惧�?澶嶆�?锛屼絾浼樺厛淇濊瘉鏁版嵁涓嶄涪澶?
## 2026-05-31 (淇鎬濈淮瀵煎浘妯″紡瀛愪换鍔℃秷�?

### 淇敼鍐呭
1. `_onLoadTasks` 琛ュ叏鐘舵€佷繚鐣欙細`viewMode`銆乣dateFrom`銆乣dateTo` 浠庝笂涓€涓?`TaskNewLoaded` 鐘舵€佺户鎵?2. 涔嬪�?`CreateTask` �?`LoadTasks` �?`emit TaskNewLoaded` 鏃舵湭浼犲叆 `viewMode`锛岄粯璁ゅ洖閫€�?`'mindmap'`
3. 鏃ユ湡绛涢€?`dateFrom`/`dateTo` 鍚屾牱涓㈠け锛屽鑷存坊鍔犲瓙浠诲姟鍚庢棩鏈熺瓫閫夎娓呴櫎

### 褰卞搷鏂囦欢
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 椋庨�?- 浣庯細绾閲忎繚鐣欙紝涓嶅奖鍝嶇幇鏈夐€昏�?
## 2026-05-30 (鎬濈淮��煎浘鑷敱鎷栨�?+ 杩炵嚎寤惰繜鍔ㄧ�?

### 淇敼鍐呭
1. **鑷敱鎷栨嫿妯��紡**锛氬彸涓嬭鏂板鍔犻攣/瑙ｉ攣鍒囨崲鎸夐挳锛岃В閿佸悗鑺傜偣鍙嚜鐢辨嫋鍔ㄥ埌鐢诲竷浠绘剰浣嶇�?2. **杩炵嚎寤惰繜鍙樼煭鍔ㄧ敾**锛氭嫋鍔ㄨ妭鐐规椂杩炵嚎�?300ms easeOut 鎯€ц繃娓★紝鏉炬墜鍚庡钩婊戠缉鐭嚦鏈€缁堜綅�?3. **`_ConnectorLine` 閲嶆�?*锛氫粠��樻鍧愭爣鏢�逛负�?`parentId`/`childId`锛宍_MindMapLinesPainter` 鍔ㄦ€佹煡琛ㄧ粯�?4. **`_MindMapNodeCard` 澧炲�?*锛氭柊澧?`freeDragMode`/`onDragUpdate` 鍙傛暟锛岃嚜鐢辨ā寮忎笅鐢?`GestureDetector` 澶勭悊鎷栧姩
5. **`InteractiveViewer.panEnabled` 鎸夋ā寮忓垏鎹?*锛氳嚜鐢辨嫋鎷芥椂绂佺敤鐢诲竷骞崇Щ閬垮厤鎵嬪娍鍐茬獊锛岀缉鏀句粛鍙�?
### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`

### 椋庨�?- 鑷敱鎷栨嫿妯��紡涓嬬敾甯冩棤娉曞钩绉伙紙浠呭彲缂╂斁锛夛紝闇€鍒囨崲鍥炶嚜鍔ㄥ竷灞€妯��紡鍚庢仮澶嶅钩�?
## 2026-05-29 (鎬濈淮��煎浘鎷栧姩/甯冨�?鏃堕棿缂栬緫/瀛愪换鍔℃秷澶变慨澶?

### 淇敼鍐呭
1. **鏃犻檺鎷栧姩**锛歚boundaryMargin` 鏢�逛负 `double.infinity`锛岀缉灏忓悗涔熷彲鑷敱宸﹀彸鎷栧姩
2. **甯冨眬闂磋窛浼樺�?*锛歏Gap 16�?8, HGap 80�?00, Padding 40�?00锛岃妭鐐逛笉鍐嶇揣璐存尋鍦ㄤ竴璧?3. **灞曞紑鎸夐挳绉诲埌鏍囬�?*锛氫粠浼樺厛绾ц绉诲埌鏍囬鏂囨湰鍙充晶锛岃瑙夋洿鍚堢�?4. **鏃堕棿鍒嗗紑缂栬�?*锛氬紑濮?缁撴潫鏃堕棿鍚勮嚜鐙珛鐐瑰嚮寮?picker 缂栬緫锛屼笉鍐嶈繛缁脊涓ゆ�?5. **瀛愪换鍔℃秷澶变慨澶?*锛歚_onCreateTask` 淇濈暢�褰撳�?filter/projectId锛屽苟璋冪敤 `_syncTasksToCloud()`
6. **娣诲姞��愪换鍔″悗鑷姩灞曞紑鐖惰妭鐐?*

### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`

### 椋庨�?- 瀛愪换鍔℃秷澶遍棶棰樼殑鏍瑰洜鍙兘杩樻湁鍏朵粬鍥犵礌锛堝 Realtime 鍥炶皟锛夛紝宸蹭慨澶嶆渶鏄庢樉鐨?filter 涓㈠け闂��?
## 2026-05-29 (鎬濈淮��煎浘瑙嗗浘浼樺�?+ 妫€鏌ラ」婧㈠嚭淇�?

### 淇敼鍐呭
1. **鎬濈淮��煎浘鍗＄墖鍙充�?"+" 鎸夐�?*锛氭瘡涓换鍔��崱鐗囧彸渚т腑闂存柊澧炲渾褰?"+" 鎸夐挳锛岢�偣鍑荤洿鎺ュ垱寤哄瓙浠诲姟锛堥�?parentId�?2. **鎬濈淮��煎浘椤圭洰鍒囨�?*锛氬崱鐗囦笂椤圭洰鍚嶅彲鐐瑰嚮寮瑰嚭椤圭洰閫夋嫨鑿滃崟锛岢�洿鎺ュ垏鎹㈡墍灞為��鐩?3. **鏃堕棿灞曠ず浼樺�?*锛氬崱鐗囨樉绢�哄畬鏁存椂闂磋寖鍥达紙寮€濮嬧啋缁撴潫锛夛紝鐐瑰嚮鍙垎鍒慨鏀瑰紑濮嬪拰缁撴潫鏃堕�?4. **鐢诲竷鎷栨嫿浼樺�?*锛氬澶?boundaryMargin �?800px锛岀缉鏀捐寖鍥磋皟鏁翠负 0.15~3.0锛屾敮鎸佺伒娲荤殑宸﹢�彸涓婁笅鎷栨嫿鍜岢�缉鏀?5. **鍘绘帢� Slidable**锛氱Щ闄ゆ€濈淮��煎浘鍗＄墖鐨勫乏婊戞墜鍔匡紙��屾�?鍒犻櫎锛夛紝閬垮厤涓庣敾甯冩嫋鎷藉啿�?6. **鍙充笂瑙?"-" 鍒犻櫎鎸夐挳**锛氭瘡涓崱鐗囧彸涓婅鍥哄畾绾㈣壊 "-" 鎸夐挳锛屾敮鎸佸揩鎹峰垹�?7. **妫€鏌ラ」婧㈠嚭淇�?*锛氬�?`Flexible` 鏇挎崲涓?`ConstrainedBox(maxHeight: 240)`锛岃В�?"BOTTOM OVERFLOWED BY 8.0 PIXELS" 榛勮壊婧㈠嚭鎶ラ�?
### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`
- `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart`

### 椋庨�?- 椤圭洰閫夋嫨鑿滃崟鍦ㄩ��鐩緢澶氭椂鍙兘闇€瑕佹粴鍔ㄤ紭�?
## 2026-05-29 (鎬濈淮��煎浘浠诲姟瑙嗗�?+ 绯荤粺鎵樼洏淇�?

### 淇敼鍐呭
1. **鎬濈淮��煎浘浠诲姟瑙嗗�?*锛氭柊澧?`mind_map_view.dart`锛屼换鍔″垪琛ㄦ敮鎸佹按骞虫€濈淮��煎浘灞曠ず锛堟牴鑺傜偣鍦ㄥ乏锛屽瓙鑺傜偣鍚戝彸鍒嗘敮锛岃礉濉炲皵鏇茬嚎杩炴帴绾匡級銆備繚鐣欐嫋鎷姐€佸睍寮�?鎶樺彔銆佷紭鍏堢骇銆丼lidable绛夊叏閮ㄤ氦浜掋€傛闈㈢榛樿鎬濈淮瀵煎浘锛屽彲閫氳�?AppBar 鎸夐挳鍒囨崲鍒楄�?瀵煎浘瑙嗗浘�?2. **绯荤粺鎵樼洏鍥炬爣涓€鑷存€?*锛氱�?`windows/runner/resources/app_icon.ico` 鏇挎�?`assets/icons/tray_icon.ico`锛岀‘淇濇墭鐩樺浘鏍囦笌搴旂敤鍥炬爣涓€鑷淬�?3. **鍗曞疄渚嬩繚�?*锛歚windows/runner/main.cpp` 娣诲�?Named Mutex锛岄槻姝㈠寮€銆傜浜屼釜瀹炰緥浼氭縺娲诲凡鏈夌獥鍙ｅ悗閫€鍑恒€?4. **閫€鍑哄欢杩熶慨�?*锛氭墭鐩?閫€�?鑿滃崟鏀逛负 `windowManager.destroy()` + `exit(0)`锛岃В鍐冲叧闂欢杩熴�?
### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/mind_map_view.dart`锛堟柊寤猴級
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/task_state.dart`
- `lib/presentation/blocs/task_new/task_event.dart`
- `lib/presentation/blocs/task_new/task_bloc.dart`
- `lib/main.dart`
- `windows/runner/main.cpp`
- `assets/icons/tray_icon.ico`

### 椋庨�?- 澶ч噺浠诲姟鏃舵€濈淮瀵煎浘鍙兘闇€瑕佹€ц兘浼樺�?- InteractiveViewer �?Draggable 鎵嬪娍鍐茬獊闇€鍏虫�?
## 2026-05-29 (淇妯℃嫙鍣ㄨ仈缃?

### 淇敼鍐呭
- **open_emulator.bat**锛氭敼涓虹洿鎺ヨ皟鐢?`emulator.exe -avd <name> -dns-server 8.8.8.8,114.114.114.114` 鍚姩妯℃嫙鍣紝淇妯℃嫙鍣?DNS 瑙ｆ瀽澶辫触瀵艰�?Supabase 鏃犳硶杩炴帴鐨勯棶棰樸€?- **android/app/src/debug/AndroidManifest.xml**锛氭坊鍔?`usesCleartextTraffic="true"` + `networkSecurityConfig`�?- **android/app/src/main/res/xml/network_security_config.xml**锛氭柊寤猴紝debug 鏋勫缓鍏佽 cleartext 娴侀�?+ 淇��换鐢ㄦ�?CA 璇佷功銆?
### 鍘熷�?妯℃嫙鍣?`flutter run` 鏃舵棤娉曡仈缃戯紙鏃ュ巻鍒蜂笉鍑烘潵锛夛紝鎵撳寘 APK 瀹夎鐪熸満姝ｅ父銆傛牴鍥犳槸妯℃嫙�?DNS 瑙ｆ瀽澶辫触瀵艰嚧鏃犳硶杩炴�?Supabase�?
## 2026-05-29 (鏂板鑴氭湰)

### 淇敼鍐呭
- **open_emulator.bat**锛氭柊澧炰竴閿墦寮�?Android 妯℃嫙鍣ㄨ剼鏈紝鑷姩妫€娴嬪彲鐢ㄦā鎷熷櫒骞跺惎鍔紝鏢�寔澶氭ā鎷熷櫒閫夋嫨�?
## 2026-05-29 (6椤筓I/UX鏢�硅繘)

## 2026-05-29 (6椤筓I/UX鏢�硅繘)

### 淇敼鍐呭
1. **SnackBar鐐瑰嚮娑堝け**锛氭柊澧?`showAppSnackBar` 鍏ㄥ眬宸ュ叿鍑芥暟锛屾墍鏈夋彁绀烘秷鎭偣鍑诲嵆娑堝け銆傜粺涓€鏇挎崲浜嗗叏�?7�?`ScaffoldMessenger.showSnackBar` 璋冪敤銆?2. **棣栭〉浠诲姟璇︽儏鏃ユ湡缂栬�?*锛歚_TimelineTask` 鏂板�?`endDate` 瀛楁锛岃鎯呭尯鍩熸樉绢�?寮€�?�?缁撴�?涓や釜鍙偣鍑绘棩鏈燂紝鍒嗗埆缂栬緫寮€濮嬪拰缁撴潫鏃堕棿銆?3. **浠诲姟璇︽儏椤垫棩鏈熺紪杈戜慨澶?*锛歚_timeChip()` 绉婚櫎澶栧眰 `onTap`锛屽紑濮嬪拰缁撴潫鏃ユ湡鍚勮嚜鐙珛 `InkWell`锛屼袱涓棩鏈熷潎鍙崟鐙偣鍑荤紪杈戙�?4. **棣栭〉浠诲姟璇︽儏椤圭洰淇�?*锛氶」鐩爣绛炬敮鎸佺偣鍑诲脊鍑洪��鐩�€夋嫨鍣紝鐩存帴鍒囨崲浠诲姟鎵€灞為��鐩€?5. **椤圭洰鍒犻櫎涓嶆敹鍥濪rawer**锛氬垹闄?`_confirmDeleteProject` 涓�?`Navigator.pop(context)`锛屽垹闄ゅ悗渚ц竟鏍忎繚鎸佹墦寮€�?6. **搴旂敤鍥炬爣**锛氳璁℃竻�?闃冲厜椋庢牸鍥炬爣锛堟殩姗欐笎鍙樿儗�?+ 鐧��壊娓呭�?+ 灏忓お闃筹級锛岄€氳�?`flutter_launcher_icons` 鐢熸�?Android �?Windows 鍥炬爣銆?7. **鏃ュ巻姘村钩鎷栧姩��艰�?*锛氬懆瑙嗗浘鏃堕棿杞村尯鍩熸敮鎸侢�紶鏍?鎵嬫寚姘村钩鎷栧姩锛屽疄鏃惰窡鎵嬪垏鎹㈡棩鏈燂紙绱Н瓒呰�?0.6 �?dayWidth 鍗冲亸绉?澶╋級銆?
### 褰卞搷鏂囦欢
- `lib/core/utils/snackbar_helper.dart`锛堟柊澧烇級
- `lib/presentation/pages/home/home_page.dart`
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/pages/calendar/calendar_page.dart`
- `assets/icons/app_icon.svg`, `assets/icons/app_icon_1024.png`锛堟柊澧烇級
- `android/app/src/main/res/mipmap-*/ic_launcher.png`锛堟洿鏂帮級
- `pubspec.yaml`锛堟坊鍔?flutter_launcher_icons�?- 14涓枃浠剁殑 SnackBar 璋冪敤鏇挎崲

### 椋庨�?TODO
- 鏃ュ巻姘村钩鎷栧姩涓庝换鍔��潡鎷栧姩鍏卞瓨锛氫换鍔″潡浣跨�?pan 鎵嬪娍鍦?gesture arena 涓紭鍏堢骇鏇撮珮锛岢�┖鐧藉尯鍩熸墠鍝嶅簲姘村钩鎷栧姩
- 鍥炬爣鍦ㄦ繁鑹茶儗鏅笂瀵规瘮搴﹁冻澶燂紝娴呰壊鑳屾櫙涓婂渾瑙掑彲鑳界暐鏄炬煍鍜?
## 2026-05-29 (鏃ュ�?浠诲姟鍒楄��澧炲己 + 鍚屾BUG淇�?

### 淇敼鍐呭
- **鏃ュ巻鍛ㄨ鍥惧ご閮ㄥ悓�?*锛氬垏鎹㈡樉绢�哄ぉ�?1-15�?鏃讹紝澶撮儴鏄熸湡鏍囩鍜屾棩鏈熸暟瀛楅殢涔嬪彉鍖栵紝涓嶅啀鍥哄畾鏄剧ず7澶┿€傛柊澧?`_buildCustomWeekHeader()` 鏇夸�?`TableCalendar` 鐨勫浐��氬懆澶淬€?- **绉诲姩绔棩鍘嗘枃��楄嚜閫傚簲**锛氫换鍔″潡鏂囧瓧鏍规嵁鍙敤��藉害鍔ㄦ€佺缉鏢�撅紙鏈€�?px锛夛紝鏋佺獎鏃堕殣钘忔椂闂村拰鐖舵爣绛撅紝浣跨敤 `FittedBox` 纭繚鏍囬鍙銆?- **妗岄潰绔彸閿彍鍗?*锛氫换鍔″崱鐗囨敮鎸佸彸閿脊鍑?缂栬�?鍒犻�?涓婁笅鏂囪彍鍗曪紙`GestureDetector.onSecondaryTapUp` + `showMenu`锛夈�?- **浠诲姟鍗＄墖椤圭洰鏍囩**锛氶」鐩悕浠庢爣棰樹笅鏂圭Щ鍒板崱鐗囧乏涓婅锛屼互褰╄壊灏忔爣绛惧舰寮忔樉绢�恒€?- **鏃ユ湡鍖洪棿绛涢�?*锛氫换鍔″垪�?AppBar 鏂板鏃ユ湡绛涢€夋寜閽紝BLoC 灞傛敮鎸?`dateFrom/dateTo` 鍙傛暟锛岃繃婊や换鍔℃椂闂磋寖鍥翠笌閫夊畾鍖洪棿鏈変氦闆嗙殑浠诲姟銆?- **鍚屾BUG淇�?*�?  - `syncFromJson` 淇濈暢�杩滅�?`updatedAt` 鏃堕棿鎴筹紝閬垮厤鏈�湴瑕嗙洊浜戠鏂版暟�?  - 澧撶煶淇濇姢锛氭湰鍦板凡鍒犻櫎涓既�椂闂存埑>=杩滅鏃讹紝涓嶈杩滅鏈垹闄ょ姸鎬佸娲?  - Realtime 鍥炶皟涓茶鍖栵紙`_enqueue` 闃熷垪锛夛紝闃叉骞跺彂鍐欏叆��艰�?SQLite database locked

### 褰卞搷鏂囦欢
- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`
- `lib/presentation/pages/tasks/tasks_page.dart`
- `lib/presentation/blocs/task_new/{task_event,task_state,task_bloc}.dart`
- `lib/data/repositories/task_repository.dart`
- `lib/services/task_sync_service.dart`

### 椋庨�?TODO
- 鏃ュ巻鑷畾涔夊ご閮ㄥ湪澶╂�?7鏃舵棩鏈熷彲鑳��法鏈堬紝宸叉纭鐞?- `FittedBox` 鍦ㄦ瀬绐勫潡涓婂彲鑳藉鑷存枃��楄繃灏忎絾浠嶅彲瑙侊紝鏄鏈熻�?- 鍚屾淇闇€瑕佽法璁惧楠岃瘉锛屽缓璁竻绌轰簯绔兊灏告暟鎹悗娴嬭瘯

## 2026-05-29 (鍏ㄤ笟鍔℃暟鎹弻绔悓姝ワ細杞垹闄ゅ鐭?+ 鍙屽�?LWW 瀵硅�?+ checklist 涓婁�?

### 淇敼鍐呭
- **缁熶竴杞垹闄わ紙澧撶煶�?*锛歚Tasks/Projects/ProjectGroups/ChecklistItems` 鍚勫�?`deleted` 鍒楋紙NOT NULL DEFAULT 0锛夛紝schemaVersion 6�?锛宍onUpgrade if(from<7)` 鍏滃簳鍔犲垪銆傚垹闄や竴寰嬬�?`deleted=1, updatedAt=now` 骞舵帹閫佸鐭筹紝涓嶅啀鐗╃悊鍒犻櫎 �?鍒犻櫎闈犲鐭宠法绔紶鎾€侀噸鍚笉澶嶆椿銆?- **鍙屽�?LWW 鍏ㄩ噺��硅�?*锛歚TaskSyncService/ProjectSyncService/ChecklistSyncService/AttachmentSyncService` 鏂板�?鍗囩�?`syncAll()`锛氭媺浜戠锛堝惈澧撶煶锛夊悎骞跺埌鏈�?+ 鏈湴锛堝惈澧撶煶锛夊嚒浜戠缂哄け鎴栨湰鍦?`updatedAt` 鏇存柊鍒欐帹閫佷笂浜戙€備慨�?瀛愪换鍔℃爲涓嶅悓姝?"绂荤嚎鍒犻櫎涓嶄紶鎾?�?- **checklist 棣栨涓婁簯**锛氭柊寤?`lib/services/checklist_sync_service.dart` + 浜戣�?`public.checklist_items`锛圧LS + REPLICA IDENTITY FULL + 鍔犲�?supabase_realtime publication锛夛紱`ChecklistRepository` 娉ㄥ�?syncService锛屽鍒犳敼 push銆佽蒋鍒犮€佽鏌ヨ杩囨护 `deleted=0`銆佹柊澧?`syncFromJson`�?- **鍒犻櫎绌?catch / NPE 瀹堝�?*锛歚TaskSyncService` 鍘绘帢� `catch(_){}` 淇濈暢�鏃ュ織锛宍currentUser!` �?`currentUser?` 瀹堝崼銆?- **鍚姩鎸夌櫥褰曟€侀棬鎺?*锛歚home_page` 绉婚櫎鏈櫥褰曞嵆瑙﹢�彂鐨?task pull锛屾墍鏈?`syncAll()+subscribe()` 缁熶竴鍦ㄧ櫥褰曞悗鍚姩锛宍signedIn/initialSession` 姣忔閲嶈窇鍏ㄩ噺��硅处銆?- **椤圭洰鍒犻櫎绾ц仈杞�?*锛歱roject 鍒犻櫎鏃剁骇鑱旇蒋鍒犲叾�?tasks/checklist锛涜繙绔��鐩鐭冲埌杈炬椂鏈湴鍚屾牱绾ц仈杞垹銆?- **闃舵�? 娓呯┖鍏ㄩ儴鏁版�?*锛氫簯绔?`user_tasks/task_attachments/projects/project_groups` �?DELETE 娓呯┖锛沗AppDatabase.wipeAllData()` 浜嬪姟娓呯┖鏈湴鍚勮��骞堕噸�?inbox�?
### 褰卞搷鏂囦欢
- `lib/data/database/app_database.dart`�? 鐢熸垚鐗?`.g.dart`�?- `lib/data/repositories/{task,project,project_group,checklist}_repository.dart`
- `lib/services/{task_sync,project_sync,attachment_sync,checklist_sync}_service.dart`锛坈hecklist 涓烘柊寤猴級
- `lib/presentation/pages/home/home_page.dart`銆乣lib/main.dart`
- `test/task_progress_calculator_test.dart`锛堟瀯閫犺�?`deleted`�?- `database/migration_004_soft_delete_checklist_realtime.sql`锛堜簯绔暀鐥曪�?
### 椋庨�?TODO
- **鏈湴蹇呴��娓呯┖**锛氭闈?DB 娓呯┖鏃舵枃浠惰鍗犵敤锛圓pp 杩愯涓級鏈垹鎴愬姛銆傞』鍏堝叧�?App 鍐嶈繍琛?`clear_data.bat`锛堟垨鍒?`%USERPROFILE%\Documents\smart_assistant.db`锛夛紱鍚﹢�垯涓嬫鍚�?`syncAll` 浼氭妸鏈�湴鏃ф暟鎹弽鎺ㄥ洖宸叉竻绌虹殑浜戠銆傜Щ鍔ㄧ闇€鍗歌浇閲嶈鎴栧悗缁帴鍏ュ簲鐢ㄥ�?`wipeAllData()` 鍏ュ彛銆?- `clear_data.bat` 浠呭�?`.db/-journal`锛屾湭鍒?`-wal/-shm`锛圖rift 榛樿闈?WAL锛屽奖鍝嶅皬锛夈�?- `syncAll` �?O(n) 鍏ㄩ�?upsert锛屽綋鍓嶆暟鎹噺灏忥紱鍚庣画鍙壒閲忓寲銆?- `migration_004` 浠呬綔鐣欑棔锛屽疄闄呭凡閫氳�?Management API 鎵ц锛坱oken 涓嶅叆搴擄級�?
## 2026-05-29 (浠诲姟鍒楄��鏍戝舰缁撴�?UI 浼樺�?

### 淇敼鍐呭
- 鏍戝舰杩炴帴绾匡細鏂板 `_TreeLinesPainter`锛圕ustomPaint锛夛紝��愯妭鐐规樉绢�?鈹溾攢鈹�?/ 鈹斺攢鈹�?杩炴帴绾匡紝闈炴渶鍚庣鍏堝眰鎸佺画绔栫�?- 灞傜骇鏍囩锛氭瘡涓妭鐐瑰乏渚ф樉绀?R0/R1/R2 灏忔爣绛?- 缂╃獎宸︿晶鍖哄煙锛氭嫋鎷芥墜鏌?icon �?20�?6锛宲adding horizontal �?2�?
- 绉婚�?TaskCard 鍐呴�?`depth * 24` 缂╄繘锛堜紶 depth:0锛夛紝缂╄繘缁熶竴鐢卞灞傛爲褰㈢嚎璐熻�?
### 褰卞搷鏂囦欢
- `lib/presentation/pages/tasks/widgets/task_list_view.dart`
- `lib/presentation/pages/tasks/widgets/task_card.dart`

### 椋庨�?TODO
- 宸插畬鎴愬尯鍧楋紙completedTreeNodes锛夋湭鍔犳爲褰㈢嚎锛屼繚鎸佸師鏍?
## 2026-05-27 (鎵归噺浼樺寲 + AI 鎺掔�?+ 椤圭洰鍒嗙粍 + 鏃ュ巻鎷栧姩閲嶅�?

### 鏂板鍔熻兘

- **椤圭洰鍒嗙粍**锛團6锛夛細鏂板缓 `ProjectGroups` �?+ `groupId` 澶栭敭锛屼晶杈规爮鎸夊垎�?ExpansionTile 灞曞紑锛岢�粍杩涘害 = 缁勫唴椤圭洰鍔犳潈绱姞锛堝悓椤圭洰鍙ｅ緞锛夈€?- **AI 浼版�?+ 鑷姩鎺掔▼**锛團2锛夛�?  - `task_decomposition_service` system prompt 寮哄埗鍙跺瓙鑺傜偣杩斿洖 `minutes`锛堚�?80锛夛紱闈炲彾瀛愮敱��愯妭鐐圭疮鍔犮�?  - 鏂板�?`subtask_scheduler.dart`�?:00�?1:00 宸ヤ綔鏃舵�? 鍒嗛挓鍚搁檮�?5 鍒嗛挓缂撳啿銆侀伩璁╁凡鍗犵敤鏃舵銆乣skipWeekends` 鍙€夛紱杈撳嚭鍙跺瓙鎺掔▼缁撴灉锛屽苟鎶婄埗浠诲姟鍥炲啓涓?`startOfDay(min) �?endOfDay(max)` 寮哄埗璺ㄥぉ锛岃嚜鍔ㄦ覆鏌撲负鏃ュ巻椤堕儴闀挎潯�?  - `ai_decompose_section` 鎺ュ�?scheduler锛屾媶��屽嵆鎺掔▼锛涢粯璁ゅ紑鍚彁閱掞紙鎻愬�?5 鍒嗛挓锛夈€?- **浠诲姟鎸傞��鐩骇鑱斿埌��愪换鍔?*锛團1锛夛細`TaskRepository.update` 妫€�?`projectId` 鍙樻洿鏃讹紝鎵归噺鏇存柊鎵€鏈夊悗浠?+ sync push�?- **棣栭〉鏃堕棿杞磋嚜閫傚簲楂樺�?*锛團5锛夛細鏍规嵁褰撳墠鍙鍒楃殑鏈€澶т换鍔℃暟鍔ㄦ€佺畻楂樺害�?0�?10px锛夛紝鑺傜偣鍐呭厑璁镐笂涓嬫粴鍔ㄧ湅瀹屾墍鏈変换鍔°€?- **棣栭〉鎻忚堪鍥哄畾楂樺害鍙粴鍔?*锛團4锛夛�?40px 楂樺害鍐呮粴鍔紝瓒呰繃 1000 瀛楁埅鏂?+ "灞曞紑鍏ㄦ枃"璺宠浆缂栬緫椤点�?- **浠诲姟鍒楄��浼樺厛�?PopupMenuButton**锛團3锛夛細鏇挎崲鏄撹瑙︾殑缁嗚壊鏉★紝鏂板甯﹂鑹插渾鐐?+ "�?�?�?�? 鏍囩鐨勮兌鍥婁笅鎷夈€?- **鏂板缓浠诲姟榛樿鏃堕棿**锛團7锛夛細寮€濮嬫椂�?= 褰撳墠锛屾埅�?= 褰撳�?1h�?- **璁剧疆锛欰I 鎺掔▼璺宠繃鍛ㄦ�?*锛歚profile_page` 鍔犲紑鍏筹紝`LocalStorage.skipWeekends`�?- **浜戝悓姝?*锛歚projects` / `project_groups` 涓婁簯锛坄migration_002_groups_and_estimate.sql`锛夛紝`user_tasks` �?`estimated_minutes` 鍒楋紱鏂板缓 `ProjectSyncService` 鎻愪�?pull / push / subscribe�?
### Bug 淇�?
- **B1 绉诲姩绔棩鍘嗛暱鎸夊悗鏃犳硶鎷栨嫿杈圭紭鏀规椂�?*锛歳esize hot zone 鏢�圭敤 5 鍒嗛挓鍚搁檮绮掑害锛岃窡鎵嬪搷搴斻€?- **B2 鏃ュ巻浠诲姟鍧楁嫋鍔ㄦ墜鎰熷�?*锛氬幓鎺?`Draggable`/`DragTarget`锛屾�?`Listener` + `Transform.translate` 鍘熷昂��歌窡鎵嬶紝5 鍒嗛挓鍚搁檮锛岃法鏃ユ寜 `dayWidth` 璁＄畻鍒楢�亸绉伙紱澶氭�?bar 鍚屾牱鏀瑰啓�?- **B3 鍒嗛挓閫夋嫨鍣ㄦ敼涓嬫媺�?*锛氬垹闄?ListWheelScrollView锛屾敼涓?�?涓€鑷寸�?`_timeDropdown`�? 鍒嗛挓涓€妗ｃ€?- **B4 鏈堣鍥惧彸鍒囦笅鏂逛换鍔��垪琛ㄤ笉鍒锋柊**锛歚onPageChanged` �?`setState`锛屾�?`_selectedDay` 鍚屾鍒版柊鏈堝悓鍙锋棩�?- **澶氭棩闀挎潯 lane 鑷姩鎾戦珮**锛歚_buildMultiDayLane` 鎸夊眰绾ф繁搴︽帓搴忥紙鏍逛换鍔��湪涓婏級锛宭ane 鏁板姩鎬佽绠楋�?6 鏃跺唴閮ㄧ旱鍚戞粴鍔ㄣ€?
### 鏁版嵁妯″��鍙樻洿

- Drift `schemaVersion` 4 �?5锛氭柊琛?`project_groups`锛宍projects.group_id`銆乣tasks.estimated_minutes` 鍒椼�?- `TaskNewLoaded` �?`groups` / `groupProgress` 瀛楁銆?- `TaskProgressCalculator` 鏂板�?`groupProgress` 璁＄畻銆?
### 褰卞搷鏂囦欢
- 鏁版嵁灞傦細`app_database.dart` (+ .g.dart)銆乣task_repository.dart`銆乣project_repository.dart`銆佹柊寤?`project_group_repository.dart`
- 鏈嶅姟灞傦細鏂板�?`subtask_scheduler.dart`銆乣project_sync_service.dart`锛涙�?`task_sync_service.dart`銆乣task_decomposition_service.dart`銆乣local_storage_service.dart`銆乣notification_service.dart` 鎺ュ�?- 琛ㄧ幇灞傦細`home_page.dart`銆乣calendar_page.dart`銆乣profile_page.dart`銆乣task_card.dart`銆乣task_create_sheet.dart`銆乣project_sidebar.dart`銆乣calendar_date_picker.dart`銆乣ai_decompose_section.dart`
- Bloc锛歚task_bloc.dart` / `task_state.dart`
- 浜戠�?SQL锛氭柊寤?`database/migration_002_groups_and_estimate.sql`�?*闇€鐢ㄦ埛鍦?Supabase Dashboard SQL Editor 鎵ц**�?
### 鍚庣�?TODO / 椋庨�?
- �?`flutter analyze` 閫氳繃锛?9 �?info/warning锛屾�?error锛夛紝��炴溢�鍔熻兘鏈窇閫氾紱寤鸿鍦ㄦ闈㈢ + 绉诲姩绔悇璺戜竴閬?AI 鎷嗗垎銆佹棩鍘嗘嫋鍔ㄣ€佹湀瑙嗗浘鍒囨崲銆侀」鐩垎缁勩€佽法璁惧鍚屾娴佺▼�?- AI 鎺掔▼涓?璐績椤哄簭濉�?锛屼笉鍋氬叏灞€鏈€浼橈紱鍚屼竴鏃舵澶氭 AI 鎷嗗垎鍙兘鎵庡爢鎺掑湪杩滄湭鏉ャ€?- 鐖朵换鍔¤法澶╁己鍒朵�?00:00�?3:59锛屼細璁╁�?bar 鍦ㄦ湢�瑙嗗浘瑕嗙洊瀹屾暣鏃舵锛屾槸棰勬湡琛屼负銆?
---

## 2026-05-27 (login fix + 闢�挎寜缂栬�?+ pinch 缂╂�?

### Fixed

- **鐧诲綍棣栨鏃犲搷搴?*锛歋upabase 璺緞涓?`_login()` 鎶婁簨浠朵涪�?BLoC 鍚庣珛鍗冲叧�?`_isLoading`锛孊LoC 寮傛杩樺湪椋炪€傛敼涓?Supabase 妯��紡瀹屽叏鐢?BLoC 鐘舵€侊紙`AuthLoading`锛夐┍鍔ㄦ寜�?disable�?- **绉诲姩绔暱鎸夌紪杈戞ā寮忥紙婊寸瓟娓呭崟鏂规锛?*锛氶暱鎸変换鍔��潡杩涘叆缂栬緫妯��紡锛屾樉绀鸿摑鑹查珮浜竟�?+ 椤堕�?搴曢儴澶ф嫋鎷芥墜鏌勶�?6px 楂橈紝钃濊壊 primaryColor锛夈€傛嫋鎷借皟鏁存椂闂村悗鑷姩閫€鍑虹紪杈戞ā寮忋€傜偣鍑荤┖鐧藉尯鍩熶篃閫€鍑恒€傛闈㈢淇濇寔鍘熸湁 hover 灏忕櫧绾胯涓恒�?- **绉诲姩绔弻�?pinch 缂╂斁鏃ュ巻鏃堕棿杞?*锛氱�?`Listener` �?`onPointerDown/Move/Up/Cancel` 杩��釜澶氱偣瑙︽帶锛屽弻鎸囨椂鎸夎窛绂绘瘮渚嬭皟鏁?`_hourHeight`锛屼笉骞叉壈 `SingleChildScrollView` 鐨勫崟鎸囨粴鍔ㄣ�?
---

## 2026-05-27 (release login + calendar fixes)

### Fixed

- **Release 妯��紡鏃犳硶鐧诲綍**锛歚INTERNET` 鏉冮檺鍙湪 debug manifest锛屼�?manifest 缂哄け銆傚凡娣诲姞鍒?`android/app/src/main/AndroidManifest.xml`�?- **鏃ュ巻浠诲姟鍗＄�?BOTTOM OVERFLOW**锛歚_buildBlockContent` 鍐呭瓒呭嚭 28px 鏈€灏忛珮搴︿笖 `Stack(clipBehavior: Clip.none)` 涓嶈鍓€傛敼�?`Material(clipBehavior: Clip.hardEdge)` + Column 鍘绘帢� `mainAxisSize: MainAxisSize.min` 璁╁唴��瑰～鍏呭苟瑁佸壢��?- **鍒囨�?1�?2澶╄鍥句笉灞呬腑鍒颁粖�?*锛歚onChanged` 鍙敼澶╂暟涓嶆�?`_focusedDay`锛屼�?`_startOfWeek` 鎬诲洖閫€鍒板懆涓€銆傚ぉ鏁?< 7 鏃剁洿鎺ヤ粠 `_focusedDay` 寮€濮嬶紝鈮?3 澶╂椂閲嶇疆鍒颁粖澶┿€?- **绉诲姩绔?resize 鐑尯澶皬**锛氬簳閮ㄦ嫋鎷界儹鍖轰粠 8px 鎵╁ぇ鍒?24px锛屽悜涓嬪亸�?8px�?
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
- Updated [lib/main.dart](/E:/claude/project2/smart_assistant/lib/main.dart) so tray right-click opens the context menu, which restores access to the desktop "閫€�? action.
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
# 2026-05-31 涓婄嚎鍙樼幇鍑嗗鏂囨��?
## 鏂板�?- 鏂板�?`docs/launch/PLATFORM_RESEARCH_CN.md`锛氫腑鍥藉ぇ闄嗕釜浜哄紑鍙戣€呬笂绾垮钩鍙拌皟鐮旓紝寤鸿棣栧彂 Windows 瀹樼�?绉佸�?+ 鍥藉唴��夊崜娓犻亾寮曟祦銆?- 鏂板�?`docs/launch/LAUNCH_CHECKLIST.md`锛氫笂绾挎潗鏂欍€佸悎瑙勩€佹妧鏈獙鏀跺拰棣栧彂鎵ц娓呭崟�?- 鏂板�?`docs/launch/PRIVACY_POLICY_DRAFT.md`銆乣docs/launch/TERMS_OF_SERVICE_DRAFT.md`锛氶殣绉佹斂绛栧拰鐢ㄦ埛鍗忚鑽夋�?- 鏂板�?`docs/launch/STORE_LISTING_COPY.md`銆乣docs/launch/PRICING_AND_GO_TO_MARKET.md`锛氬簲鐢ㄥ晢搴楁枃妗堛€佸畾浠峰拰鑾峰鏂规銆?- 鏂板�?`docs/launch/RISK_REGISTER.md`銆乣docs/launch/RELEASE_EVIDENCE.md`锛氫笂绾块闄╃櫥璁板拰褰撳墠鍙戝竷璇佹嵁璁板綍�?
## 璇存�?- 鏈鍙柊澧炴枃妗ｏ紝涓嶄慨鏀逛笟鍔��唬鐮併€佷笉鏇存崲 DeepSeek Key銆佷笉鏀瑰彉鏋勫缓鑴氭湰鎴栧簲鐢ㄥ姛鑳姐�?- 宸茬煡椋庨櫓缁х画淇濈暢�锛欴eepSeek Key 瀹㈡埛绔唴缃€丄ndroid release 浣跨�?debug 绛惧悕銆丄ndroid 鍖呭悕浠嶄负 `com.example.smart_assistant`�?
# 2026-05-31 鏃ュ巻鑺傚亣鏃ヤ笌浼戞伅鏃ュ睍绀?
## 淇�?- `lib/services/holiday_service.dart`锛歚HolidayCountry` 鎵╁睍寰峰浗銆佹硶鍥姐€佸姞鎷垮ぇ銆佹境澶у埄浜氥€佸嵃搴︺€?- `lib/presentation/pages/calendar/calendar_page.dart`锛氭帴鍏?`HolidayService`锛孉ppBar 鏂板鑺傚亣鏃ュ浗��跺垏鎹紱鍛ㄨ鍥炬棩鏈熷ご鍜屾湀瑙嗗浘鏃ユ湡鏍煎睍绀烘硶瀹氳妭鍋囨棩銆佽皟浼戣ˉ鐝€佹櫘閫氬懆鏈紤鎭棩銆?- `lib/services/holiday_service.dart`锛氫腑鍥借妭鏃ュ鍔犳湰鍦拌ˉ鍏咃紝鍎跨鑺傜瓑闈炴斁鍋囪妭鏃ヤ娇�?`HolidayType.observance` 灞曠ず锛屼笉鍙備笌浼戞伅鏃ュ垽鏂€?- `lib/presentation/pages/calendar/calendar_page.dart`锛歚HolidayType.observance` 浣跨敤宸ヤ綔鏃ヨ妭鏃ユ牱寮忓睍绀恒€?- `ARCHITECTURE.md`锛氬悓姝ヨ褰曟棩鍘嗚妭鍋囨�?浼戞伅鏃ュ睍绢�虹粨鏋勩�?
## 楠岃�?- `flutter analyze lib/services/holiday_service.dart lib/presentation/pages/calendar/calendar_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 2 涓棦鏈?warning�?
## 椋庨�?- 澶栭儴鑺傚亣�?API 鍒濇涓嶅彲鐢ㄤ笖鏃犵紦瀛樻椂锛屽彧鑳藉睍绀烘湰鍦板懆鏈紤鎭棩銆?
# 2026-05-31 绉婚櫎棣栭��璁よ瘑寮曞�?
## 淇�?- `lib/presentation/pages/home/home_page.dart`锛氱Щ闄ら椤靛垵濮嬪寲鏃惰嚜鍔ㄨ烦杞?`OnboardingPage` 鐨勯€昏緫锛屼繚鐣欓€氱煡鏉冮檺寮曞銆?- `ARCHITECTURE.md`锛氳褰曢椤靛惎鍔ㄥ紩瀵肩粨鏋勫彉鍖栥�?
## 楠岃�?- `flutter analyze lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 5 涓棦鏈?lint/info�?
## 椋庨�?- `OnboardingPage` 鏂囦欢浠嶄繚鐣欙紝鑻ュ叾浠栧叆鍙ｅ紩鐢ㄤ笉浼氬彈鏈淇敼褰卞搷銆?
# 2026-05-31 瀛愪换鍔￠粯璁ょ户鎵跨埗浠诲姟椤圭洰

## 淇�?- `lib/presentation/pages/tasks/tasks_page.dart`锛氫粠浠诲姟�?鎬濈淮��煎浘鐖惰妭鐐规柊澧炲瓙浠诲姟鏃讹紝榛樿椤圭洰浼樺厛鍙栫埗浠诲姟椤圭洰�?- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart`锛氬垵濮嬪寲鍜屽垏鎹㈢埗浠诲姟鏃跺悓姝ラ€変腑鐖朵换鍔＄殑椤圭洰�?- `ARCHITECTURE.md`锛氳褰曞瓙浠诲姟鍒涘缓榛樿椤圭洰閫昏緫銆?
## 楠岃�?- `flutter analyze lib/presentation/pages/tasks/tasks_page.dart lib/presentation/pages/tasks/widgets/task_create_sheet.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 7 涓棦鏈?lint/info�?
## 椋庨�?- 浠呰鐩栨柊浠诲姟寮圭獥璺緞锛涗换鍔¤鎯呴〉��愪换鍔″叆鍙ｆ鍓嶅凡浼犲叆鐖朵换鍔￠」鐩€?
# 2026-05-31 绉诲姩绔椤典换鍔¤鎯呰祫婧愬尯閫傞厤

## 淇�?- `lib/presentation/pages/home/home_page.dart`锛氶椤?DB 浠诲姟璇︽儏璧勬簮鍖烘寜瀹藉害鍒囨崲甯冨眬锛涚Щ鍔ㄧ瀛愪换鍔＄嫭鍗犱竴琛岋紝闄勪欢鍜屾鏌ラ」鍗曠嫭缁勬垚涓€琛屻€?- `ARCHITECTURE.md`锛氳褰曢椤典换鍔¤鎯呯Щ鍔ㄧ璧勬簮鍖哄竷灞€瑙勫垯銆?
## 楠岃�?- `flutter analyze lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 5 涓棦鏈?lint/info�?
## 椋庨�?- �?`640px` 浣滀负绐勫睆闃堝€硷紝��為檯璁惧缁嗚妭浠嶉渶鐪熸溢�纭銆?
# 2026-05-31 鎬濈淮��煎浘鍒犻櫎璺ㄧ鍚屾

## 淇�?- `lib/data/repositories/task_repository.dart`锛氳繙绔换鍔��鐭充笉鍐嶈鏈湴娲讳换鍔℃棤鏉′欢鎷掔粷锛屾敼涓烘�?`updatedAt` LWW 鍒ゆ柇銆?- `lib/services/task_sync_service.dart`锛氬叏閲忓悓姝ヤ笉鍐嶇敤鏈湴娲讳换鍔℃棤鏉′欢瑕嗙洊浜戠澧撶煶锛涙柊澧炰换鍔″悓�?`changes` 骞挎挱銆?- `lib/presentation/pages/home/home_page.dart`锛氱洃鍚?`TaskSyncService.changes`锛岃繙绔换鍔℃柊澧?鏇存�?鍒犻櫎鍚庤Е鍙?`LoadTasks` 鍒锋柊浠诲姟椤靛拰鎬濈淮瀵煎浘銆?- `ARCHITECTURE.md`锛氳褰曚换鍔��垹闄よ法绔悓姝ラ€昏緫銆?
## 楠岃�?- `flutter analyze lib/data/repositories/task_repository.dart lib/services/task_sync_service.dart lib/presentation/pages/home/home_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 7 涓棦鏈?lint/info/warning�?
## 椋庨�?- 闇€鍙岀鐧诲綍鍚屼竴璐﹢�彿鐪熸満楠岃�?Realtime 鍒犻櫎浼犳挱锛涙湰鏈轰粎鍋氶潤鎬佸垎鏋愩�?
# 2026-05-31 鎵嬫溢�楠岃瘉鐮佺櫥�?
## 淇�?- `lib/services/supabase_service.dart`锛氭柊澧炴墜鏈哄彿鍙戦€侢�獙璇佺爜鍜岀煭淇?OTP 鏍￠獙灏佽锛屼娇鐢?Supabase Flutter `signInWithOtp` / `verifyOTP`�?- `lib/presentation/blocs/auth/auth_event.dart`銆乣auth_state.dart`銆乣auth_bloc.dart`锛氭柊澧炴墜鏈哄彿楠岃瘉鐮佽姹傘€佹牎楠屽拰宸插彂閫佺姸鎬併€?- `lib/presentation/pages/auth/login_page.dart`锛氱櫥褰曢��鏂板閭�?鎵嬫溢�楠岃瘉鐮佹ā寮忓垏鎹紝鎵嬫満妯��紡鏢�寔鑾峰彇楠岃瘉鐮併€佽緭鍏ラ獙璇佺爜鐧诲綍锛涘ぇ闄?11 浣嶆墜鏈哄彿鑷姩琛?`+86`�?- `ARCHITECTURE.md`锛氳褰曟墜鏈洪獙璇佺爜鐧诲綍娴佺▼�?
## 楠岃�?- `flutter analyze lib/presentation/blocs/auth/auth_bloc.dart lib/services/supabase_service.dart lib/presentation/pages/auth/login_page.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 12 涓棦鏈?`print` info�?
## 椋庨�?- 闇€瑕佸�?Supabase 鍚庡彴寮€鍚?Phone provider 骞堕厤缃煭淇℃湇鍔★紱鏈溢�鏈疄闄呭彂閫佺煭淇°�?
# 2026-05-31 鍏ㄥ眬鎺掗櫎椤圭�?
## 淇�?- `lib/services/local_storage_service.dart`锛氭柊澧?`excludedProjectIds` 鎸佷箙鍖栬缃�?- `lib/presentation/blocs/task_new/task_bloc.dart`锛氫换鍔℃ā鍧楢�姞杞藉拰杩涘害璁＄畻鍓嶆帓闄よ缃腑鐨勯��鐩€?- `lib/presentation/pages/home/home_page.dart`锛氶椤垫椂闂磋酱婧愭暟鎹帓闄よ缃腑鐨勯��鐩紝褰卞搷鏃堕棿杞淬€佺粺璁°€佸洓璞￠檺�?- `lib/presentation/pages/home/home_page.dart`锛氶椤甸��鐩瓫閫夊簳灞傜姸鎬佷粠鍗曢��鐩?ID 璋冩暣涓洪��鐩?ID 闆嗗悎锛岢�浉鍏宠绠楁寜闆嗗悎杩囨护銆?- `lib/presentation/pages/home/home_page.dart`锛氶椤甸��鐩瓫閫夊鍔犲閫夊脊绐楢�叆鍙ｏ紝鍘熶笅鎷変繚鐣欎负蹇€熷崟閫夈�?- `lib/presentation/pages/calendar/calendar_page.dart`锛氭棩鍘嗕换鍔��姞杞芥椂鎺掗櫎璁剧疆涓殑椤圭洰锛涙棩鍘嗛」鐩瓫閫夋敼涓洪��鐩?ID 闆嗗悎锛屽彲鍦ㄨ彍鍗曚腑澶氶�?鍙栨秷椤圭洰�?- `lib/presentation/pages/tasks/tasks_page.dart`锛欰ppBar 鏂板鈥滄帓闄ら」鐩€濆閫夎缃叆鍙ｃ�?- `lib/presentation/blocs/task_new/task_event.dart`銆乣task_state.dart`銆乣task_bloc.dart`銆乣lib/presentation/pages/tasks/tasks_page.dart`锛氫换鍔℃ā鍧楃瓫閫夌姸鎬佹敮鎸佸椤圭洰闆嗗悎锛屼换鍔￠�?AppBar 鏂板椤圭洰澶氶€夌瓫閫夊叆鍙ｃ�?- `ARCHITECTURE.md`锛氳褰曞叏灞€鎺掗櫎椤圭洰鏁版嵁娴併€?
## 楠岃�?- `dart format` 宸叉牸寮忓寲鏈鐩稿叧 Dart 鏂囦欢銆?- `flutter analyze lib/presentation/pages/home/home_page.dart lib/presentation/pages/calendar/calendar_page.dart lib/presentation/blocs/task_new/task_event.dart lib/presentation/blocs/task_new/task_state.dart lib/presentation/blocs/task_new/task_bloc.dart lib/presentation/pages/tasks/tasks_page.dart lib/services/notification_service.dart lib/services/permission_service.dart lib/services/local_storage_service.dart` 宸茶繍琛岋紝鏃犵紪璇戦敊璇紱浠嶆湁 27 涓棦鏈?lint/info/warning�?
## 椋庨�?- 棣栭〉鍘熼��鐩笅鎷変粛淇濈暀蹇€熷崟閫夛紝鏃佽竟澶氶€夋寜閽敤浜庡閫夌瓫閫夈€?
# 2026-05-31 绉诲姩绔拰妗岄潰绔彁閱掗€氱�?
## 淇�?- `lib/services/notification_service.dart`锛氱Щ鍔ㄧ璋冨害閫氱煡鍓嶅厹搴曡姹傞€氱煡鏉冮檺鍜?Android 绮剧‘闂归挓鏉冮檺锛沬OS 鍓嶅彴閫氱煡鏄惧紡鍚敤 alert/badge/sound�?- `lib/services/notification_service.dart`锛歐indows 妗岄潰鎻愰啋鏢�逛负 PowerShell MessageBox锛岀敤鎴风偣�?OK 鍓嶄笉浼氳嚜鍔ㄦ秷澶便€?- `lib/services/permission_service.dart`锛欰ndroid 棣栨閫氱煡鎺堟潈寮曞鍚屾璇锋眰绮剧‘闂归挓鏉冮檺銆?
## 楠岃�?- `flutter analyze lib/services/notification_service.dart lib/services/permission_service.dart` 宸茶繍琛岋紝鏃犻棶棰樸€?
## 椋庨�?- Android 绮剧‘闂归挓鏉冮檺浼氳烦杞郴缁熸巿鏉冮〉锛屼粛闇€鐪熸溢�纭涓嶅悓鍘傚晢鍚庡彴淇濇椿绛栫暐�?
# 2026-06-01 鏂板缓鍒嗙粍鍚庝晶杈规爮涓嶆樉绀?
## 淇�?- `lib/presentation/pages/tasks/widgets/project_sidebar.dart`锛氱┖鐘舵€佸垽鏂敼涓洪��鐩拰鍒嗙粍閮戒负绌烘椂鎵嶆樉绢�烘暣浣撶┖鐘舵€侊紝鍏佽鏃犻��鐩殑鍒嗙粍姝ｅ父娓叉煋銆?- `test/project_sidebar_test.dart`锛氭柊澧炲洖褰掓祴璇曪紝瑕嗙洊娌℃湁椤圭洰浣嗗瓨鍦ㄥ垎缁勬椂浠嶅睍绀哄垎缁勫悕绉般€?
## 楠岃�?- `flutter test test\project_sidebar_test.dart` 閫氳繃銆?- `flutter analyze lib\presentation\pages\tasks\widgets\project_sidebar.dart test\project_sidebar_test.dart` 閫氳繃銆?
## 椋庨�?- 鏈仛鐪熸満/杩愯鏃舵墜鍔ㄧ偣鍑婚獙璇侊紱鏈浠呰鐩栫粍浠舵覆鏌撲笌闈欐€佸垎鏋愩€?
# 2026-06-01 椤圭洰渚ф爮鍒嗙粍灞曞紑涓庢帓�?
## 淇�?- `lib/presentation/pages/tasks/widgets/project_sidebar.dart`锛氬垎缁勫睍寮€鏢�逛负鍙楁帶鐘舵€侊紝鏂板鍏ㄩ儴灞曞紑銆佸叏閮ㄦ敹缂┿€佹椂闂存帓搴忔寜閽紱鍒嗙粍鍜岀粍鍐呴��鐩寜 `createdAt` 鎺掑簭銆?- `lib/presentation/pages/tasks/tasks_page.dart`锛氱淮鎶や晶鏍忓垎缁勫睍寮€闆嗗悎锛涙柊寤洪」鐩�€夋嫨鍒嗙粍鍚庣珛鍗冲睍寮€璇ュ垎缁勶紱璇诲彇骞朵繚瀛樻帓搴忔柟鍚戙�?- `lib/services/local_storage_service.dart`锛氭柊澧?`projectSidebarTimeSortDesc` 鎸佷箙鍖栭厤缃紝榛樿鍊掑簭銆?- `test/project_sidebar_test.dart`銆乣test/local_storage_service_test.dart`锛氳ˉ鍏呬晶鏍忓睍寮€/鏢�剁缉銆佹帓搴忓拰鎸佷箙鍖栨祴璇曘�?- `ARCHITECTURE.md`锛氳褰曢��鐩晶鏍忓垎缁勫睍寮€鍜屾帓搴忕粨鏋勩�?
## 楠岃�?- `dart format lib\presentation\pages\tasks\widgets\project_sidebar.dart lib\presentation\pages\tasks\tasks_page.dart lib\services\local_storage_service.dart test\project_sidebar_test.dart test\local_storage_service_test.dart` 宸叉墽琛屻€?- `flutter test test\project_sidebar_test.dart test\local_storage_service_test.dart` 閫氳繃銆?
## 椋庨�?- 鏈仛鐪熸満鎵嬪姩鐐瑰嚮楠岃瘉锛涘綋鍓嶈鐩?widget 琛屼负鍜屾湰鍦板瓨鍌ㄦ寔涔呭寲銆?

# 2026-06-01 日历右键跳转思维导图节点
## 修改
- `lib/presentation/pages/calendar/calendar_page.dart`：日历任务列表项、单日任务块、多日任务条右键改为触发思维导图跳转回调；单日任务块右键不再直接删除�?- `lib/presentation/pages/home/home_page.dart`：接收日历跳转任务后切到任务页，并派发带目标任务 ID �?`LoadTasks`�?- `lib/presentation/blocs/task_new/task_event.dart`、`task_state.dart`、`task_bloc.dart`：新增聚焦任务请求字段，加载时强制��维导图视图并展弢�目标任务祖先节点�?- `lib/presentation/pages/tasks/tasks_page.dart`、`lib/presentation/pages/tasks/widgets/mind_map_view.dart`：��传并消费聚焦请求，居中选中目标节点�?- `test/task_mindmap_focus_test.dart`：新增聚焦请求字段测试��?## 验证
- `flutter test test/task_mindmap_focus_test.dart` 通过�?- `flutter analyze lib/presentation/pages/home/home_page.dart lib/presentation/pages/calendar/calendar_page.dart lib/presentation/pages/tasks/tasks_page.dart lib/presentation/pages/tasks/widgets/mind_map_view.dart lib/presentation/blocs/task_new/task_bloc.dart lib/presentation/blocs/task_new/task_event.dart lib/presentation/blocs/task_new/task_state.dart` 无新增编译错误；命令仍因既有 lint/warning 非零�?## 风险
- 未做真机/桌面手动右键验收；当前仅完成静��分析和字段级测试��?
# 2026-06-01 桌面本地数据化模�?## 修改
- `lib/presentation/pages/auth/login_page.dart`：桌面端新增“不登录，本地使用��入口，进入 `LocalAuthenticated`，不�?Supabase 登录�?- `lib/services/local_data_service.dart`：新增本地数据目录��数据库/附件路径、偏好快照��zip 导入导出能力�?- `lib/services/local_storage_service.dart`：本地用户��日程��旧本地任务、资料和偏好写入后同步刷新数据目录内�?`preferences.json`�?- `lib/data/database/app_database.dart`：数据库文件路径改为�?`LocalDataService` 解析，并新增 `checkpointForBackup()`�?- `lib/services/task_attachment_service.dart`：附件本地目录改为跟�?`LocalDataService`�?- `lib/presentation/pages/home/home_page.dart`、`lib/main.dart`、`lib/presentation/pages/profile/profile_page.dart`、`lib/presentation/pages/profile/app_settings_page.dart`：将数据库实例传入我�?设置页，并仅在桌面本地模式显示保存位置��导入数据��导出备份入口��?- `test/local_data_service_test.dart`：新增目录切换复制和备份导入测试�?## 验证
- `flutter test test\local_data_service_test.dart` 通过�?- `flutter analyze lib\services\local_data_service.dart lib\services\local_storage_service.dart lib\data\database\app_database.dart lib\presentation\pages\auth\login_page.dart lib\presentation\pages\profile\app_settings_page.dart lib\presentation\pages\profile\profile_page.dart test\local_data_service_test.dart` 通过�?- 扩大�?`main.dart`、`home_page.dart`、`task_attachment_service.dart` 的分析仍被既�?lint/info/warning 拦住，未发现本次新增文件问题�?## 风险
- 切换保存位置和导入备份采用��重启后生效”，避免在运行中替换已打弢� SQLite 文件；仍霢�桌面端手动验收文件��择、导入和重启后的数据加载�?## 2026-06-01 (跨天父任务调整校�?

### 修复
- 原因：桌面端周视图顶部跨天任务条左右调整热区偏小，且父任务可被缩短到无法覆盖子任务日期��?- `lib/presentation/pages/calendar/calendar_page.dart`：跨天条左右调整热区�?18px 扩大�?32px；父任务跨天条保存前校验新时间范围必须覆盖所有未删除后代子任务时间段，不满足时提示并拒绝更新�?- `lib/presentation/pages/calendar/task_time_range_guard.dart`：新增后代任务时间范围计算，递归覆盖直接子任务和孙任务等全部后代�?- `test/calendar_task_time_range_guard_test.dart`：覆盖后代范围��删�?无时间过滤��父任务缩短失败判断�?- 验证：`flutter test test\calendar_task_time_range_guard_test.dart` 通过；`flutter analyze lib\presentation\pages\calendar\calendar_page.dart lib\presentation\pages\calendar\task_time_range_guard.dart test\calendar_task_time_range_guard_test.dart` 仍有既有 `_startOfWeek` 未使用和 `_isDragging` 未使�?warning�?## 2026-06-02 (思维导图筛��与新节点展�?

### 修复
- 原因：任务页当前项目筛��在�?`LoadTasks()` 刷新后会被清空，且新建子节点后页面层基于�?state 展开父节点存在竞态��?- `lib/presentation/blocs/task_new/task_event.dart`、`lib/presentation/blocs/task_new/task_bloc.dart`、`lib/presentation/pages/tasks/tasks_page.dart`：`LoadTasks` 增加 `hasProjectSelectionOverride`，刷新时保留当前项目/任务类型/日期/视图状��；创建任务后由 BLoC 展开新节点父链并写入思维导图聚焦请求，移除页面层旧展弢�逻辑�?- `lib/data/database/app_database.dart`、`test/task_mindmap_focus_test.dart`：数据库构��器支持测试传入内存 executor，补充项目筛选保留和创建子节点展弢�/聚焦回归测试�?
## 2026-06-02 任务详情图片、项目筛选与 Android 提醒

### 修改
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart`：新版任务详情描述区增加 Ctrl+V 图片粘贴和拖入图片保存��?- `lib/services/task_attachment_service.dart`：新增图片字节保存入口，支持剪贴板和拖入文件直接写入附件�?- `lib/presentation/pages/home/home_page.dart`、`lib/presentation/pages/calendar/calendar_page.dart`：项目筛选改为复用分组项目��择器��?- `lib/presentation/pages/task/task_detail_page.dart`：旧版提醒设置保存后同步旧本地任务数据��?- `lib/services/notification_service.dart`、`lib/services/permission_service.dart`、`android/app/src/main/AndroidManifest.xml`：Android 提醒增加本地时区、稳定��知 ID、精确闹钟权限判断��提醒重排和权限引导�?- `pubspec.yaml`、`pubspec.lock`：新�?`super_clipboard`、`desktop_drop`、`flutter_timezone`�?
### 验证
- `flutter test test/task_sync_service_test.dart test/task_attachment_service_test.dart test/notification_service_test.dart test/project_picker_content_test.dart` 通过�?- 定向 `flutter analyze` 无编译错误；仍有既有 lint/info/warning�?
### 风险
- Android 厂商后台限制只能通过设置引导缓解，仍霢�真机确认通知触达�?- 剪贴板图片当前按 PNG 数据读取；拖入文件按扩展名限�?png/jpg/jpeg/gif/webp�?


## 2026-06-04 (Reasonix 全局记忆钩子系统)

### 新增
- **插件结构**: 创建 .codex-plugin/ 插件目录，注册插件清单和 marketplace 入口
- **预执行钩子技能**: 整合 .reasonix/memory/global/ 全部 22 条记忆规则为 6 阶段预执行流程
  - 阶段1: 回复格式强制 ([记忆执行情况] + [老板])
  - 阶段2: 改前门禁 (codegraph/graphify 工具检查 + 选择题征询)
  - 阶段3: 修改执行 (数据流追溯 + 反补丁检查 + 一次一事)
  - 阶段4: 改后维护 (graphify update + 文档更新)
  - 阶段5: 回复前自检 (Summary/Files/Tests/Risks/Next)
- **钩子配置文件**: 声明 before-every-execution 触发时机
- **安装脚本**: install_hook.ps1 用于验证/安装钩子状态
- **外部触发词**: 跑技能 / force-load-global-memories / 格式

### 数据源
- C:\\Users\\Administrator\\.reasonix\\memory\\global\\ (22 条原始记忆文件)

### 影响文件
- .codex-plugin/.codex-plugin/plugin.json (新建)
- .codex-plugin/skills/pre-execution-hook/SKILL.md (新建)
- .codex-plugin/hooks/pre-execution.json (新建)
- .codex-plugin/scripts/install_hook.ps1 (新建)
- ARCHITECTURE.md (添加钩子章节)
- CHANGELOG.md (本次记录)
- ~/.agents/plugins/marketplace.json (插件入口)

### 风险/TODO
- 钩子通过 AGENTS.md 注入上下文，需确认每次新线程正确加载
- 22 条记忆规则分散在 .reasonix，SKILL.md 是最新整合来源，但需要定期与原始文件同步
- 外部触发词需要人工监督执行
