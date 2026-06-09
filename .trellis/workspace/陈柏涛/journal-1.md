# Journal - 陈柏涛 (Part 1)

> AI development session journal
> Started: 2026-06-06

---



## Session 1: 任务搜索功能实现 + quality check + spec 更新

**Date**: 2026-06-06
**Task**: 任务搜索功能实现 + quality check + spec 更新
**Branch**: `master`

### Summary

实现任务列表搜索功能：TaskRepository.searchTaskIds() 支持标题/描述/检查项搜索、SetSearchQuery 事件 + Bloc 筛选器叠加、SearchDelegate UI 带 300ms 防抖、质量检查通过、更新 state-management.md spec 文档

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `3b82553` | (see git log) |
| `67502de` | (see git log) |
| `36520a0` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: 思维导图切换筛选项目后布局错乱修复

**Date**: 2026-06-06
**Task**: 思维导图切换筛选项目后布局错乱修复
**Branch**: `master`

### Summary

修复 MindMapView 在切换筛选项目后手工拖拽位置丢失的问题。根因: _loadOffsets() 只在 initState() 调用一次，didUpdateWidget 中 task 列表变化后未重新加载。新增 _reloadOffsets() 方法在 didUpdateWidget 中重新加载 SharedPreferences 存储的 offset，不触发 setState 或 _focusNearestTask 副作用。同时将 widget 生命周期异步加载陷阱记录至 component-guidelines.md 的 Common Mistakes 部分。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `473f875` | (see git log) |
| `072a7a9` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: 修复过期任务通知弹窗问题 + 首页性能优化

**Date**: 2026-06-06
**Task**: 修复过期任务通知弹窗问题 + 首页性能优化
**Branch**: `master`

### Summary

修复过期任务通知弹窗三个 bug: ① onDidReceiveNotificationResponse 空回调导致点击不跳转 - 添加 payload+全局 navigatorKey 导航到首页; ② 每次 sync/resume 重复弹窗 - 缓存 _lastShownOverdueCount 去重; ③ _clearOverdueAlarms 重复取消导致卡顿 - 移除 rescheduleTaskReminders 中的冗余调用。附带首页性能优化: _debounceLoadTasks 防抖、_pages 缓存、_visibleTabIndex 通知器。通知去重和禁止重复取消模式写入 quality-guidelines.md。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `8942fcb` | (see git log) |
| `1ec7210` | (see git log) |
| `fb07bee` | (see git log) |
| `47f79c6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: Tab 页面切换卡顿优化

**Date**: 2026-06-06
**Task**: Tab 页面切换卡顿优化
**Branch**: `master`

### Summary

性能优化：消除首页/任务/日历/我的 tab 切换卡顿
- 用 ValueNotifier<int> _tabIndex 替代 int _currentIndex + setState
- build() 方法中 3 个 ValueListenableBuilder 分别重建 IndexedStack / BottomNav / FAB
- _buildBottomNav() + _navItem() 提取为独立 _BottomNavWidget StatelessWidget
- RepaintBoundary 包裹每个 tab 页面
- 更新 quality-guidelines.md: 新增 ValueNotifier+ValueListenableBuilder 替代 setState 模式

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `e5dc5d0` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 5: 思维导图布局重置 + 日历多层任务排序修复

**Date**: 2026-06-06
**Task**: 思维导图布局重置 + 日历多层任务排序修复
**Branch**: `master`

### Summary

Feature 1: 思维导图父子关系变更后，用 _pendingLayoutResetIds 机制清除旧拖拽坐标，使子树重置为自动布局。Feature 2: 日历跨天区改用 DFS 递归排序，保证多层级任务树中父节点永远在子节点上方；并修复父任务无日期时组排序依据（effectiveGroupSpan）。同步修复 Android Gradle 构建配置（jvmTarget DSL 迁移、TimeUnit import、并行构建开启）。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `7827dea` | (see git log) |
| `511d9ed` | (see git log) |
| `1a05678` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 6: 阿里云推送 Android 8.0+ 通知修复

**Date**: 2026-06-06
**Task**: 阿里云推送 Android 8.0+ 兼容性修复 + 小米推送调研
**Branch**: `master`

### Summary

修复 Android 8.0+ 收不到阿里云推送通知的问题：

1. **服务端缺少 AndroidNotificationChannel** — 在 schedule-push 推送参数中添加 `AndroidNotificationChannel: \"schedule_reminders\"` + `AndroidNotifyType: \"BOTH\"`
2. **通知通道匹配** — 客户端改为复用 `schedule_reminders` 通道（flutter_local_notifications 已创建并可用），替换独立的 `aliyun_push_channel`
3. **小米手机问题** — 无 MiPush 厂商通道 + 无自启动权限 → 推送到达设备但不弹通知

**已部署**：schedule-push ✅

### 当前状态

- 非小米手机 — 推送正常工作
- 小米手机 — 需要注册 MiPush 厂商通道（需小米开发者账号 + AppID/AppKey），**暂时搁置**

### 待办（需小米开发者账号后继续）

- [ ] 注册小米开发者账号，获取 MiPush AppID / AppKey
- [ ] 在 AndroidManifest.xml 添加 meta-data：`com.xiaomi.push.id` / `com.xiaomi.push.key`
- [ ] Flutter 端调用 `initThirdPush()` 注册 MiPush
- [ ] 推送测试验证

### Testing

- 第一次测试（aliyun_push_channel）→ 通知栏状态关闭 ❌
- 第二次测试（schedule_reminders）→ 通知栏状态打开 ✅，但小米未展示通知栏
- 服务端 API 调用均成功（msgId 返回正常）

### Status

[PENDING] **搁置 - 等待小米开发者账号**

### Next Steps

- 等待注册小米开发者账号后继续推进

## 2026-06-06 修复：日历移动端长按编辑 + 拖拽边缘调整时间

**根因分析**: commit `a08737c` 引入 `_EagerPanGestureRecognizer`，它在 addAllowedPointer 中立即调用 resolve(GestureDisposition.accepted)，导致 LongPressGestureRecognizer 被 gesture arena 立即拒绝，长按无法触发进入编辑模式

**修复方案**: 移除 LongPressGestureRecognizer，移动端改用 `Listener` + `Timer` 检测长按（400ms，12px 移动阈值取消），绕过 gesture arena 竞争。`_EagerPanGestureRecognizer` 保留不动（继续防止 ScrollView 抢走拖拽手势）。桌面端不受影响（showResize = isEditMode || !_isMobile 在桌面端始终为 true）


## Session 6: 本地通知修复完整实施 + 记录 MIUI 厂商推送阻塞

**Date**: 2026-06-07
**Task**: 本地通知修复完整实施 + 记录 MIUI 厂商推送阻塞
**Branch**: `master`

### Summary

验证 fix-local-notifications 实施完整（try-catch/降级/logcat/系统默认音/alarm.wav删除），更新 PRD 记录小米 MIUI 需厂商推送 SDK 暂缓。calendar-edit-mode 代码已在 2414cad 完成。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `3d24370` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 7: calendar-edit-mode 质量检查 + 归档

**Date**: 2026-06-07
**Task**: calendar-edit-mode 质量检查 + 归档
**Branch**: `master`

### Summary

对 fix(calendar): 长按进入编辑模式后松手不再退出 进行 trellis-check，确认 _longPressActivated 标志位逻辑完整、无调试日志、无新增 lint 问题，质量检验通过后归档。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `2414cad` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 8: 修复逾期提醒通知跳转与频率控制

**Date**: 2026-06-07
**Task**: 修复逾期提醒通知跳转与频率控制
**Branch**: `master`

### Summary

修复桌面端和移动端点击逾期提醒通知不跳转的问题，改造通知节流为基于 SharedPreferences 的时间戳窗口（默认 4 小时），设置页新增逾期提醒间隔配置

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `9167c73` | (see git log) |
| `1e8518b` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 9: 修复首页切回时逾期/时间轴不刷新

**Date**: 2026-06-07
**Task**: 修复首页切回时逾期/时间轴不刷新
**Branch**: `master`

### Summary

根因：BlocListener 在首页不可见时丢弃 TaskNewLoaded 事件，切回首页的 _onVisibleTabChanged 只 setState 不加载数据。用脏标记法（_needsRefresh）解决：后台有变化时记标记，切回时按需调用 _loadData()，无变化不多查 DB。同步更新 state-management.md 记录该模式。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `232d66c` | (see git log) |
| `2201b36` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 10: 评估 codegraph+graphify 在 Flutter 项目的可行性

**Date**: 2026-06-07
**Task**: 评估 codegraph+graphify 在 Flutter 项目的可行性
**Branch**: `master`

### Summary

评估了 codegraph 和 graphify 在本 Flutter/Dart 项目中的实际效果。graphify 原始图谱含 5177 节点（97.5% 为噪音），配置 .graphifyignore 后重建降至 136 节点（Dart 占 99%）。确认 codegraph 为结构查询主力（364类/1799方法），graphify 仅做概念预筛（Dart 边稀疏，不适合调用链）。建立两场景工作流规范并写入项目专用记忆 flutter-codegraph-workflow.md。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `5259dcc` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 11: Taskora Web 上线 — deploy-branch CI/CD

**Date**: 2026-06-07
**Task**: Taskora Web 上线 — deploy-branch CI/CD
**Branch**: `master`

### Summary

完成 Flutter Web 部署上线：vercel.json 移至 web/ 并补 COOP/COEP headers；GitHub Actions 改为 deploy-branch 模式（构建产物推 deploy 分支，Vercel serve 静态文件，无需 Secrets）；清理 git 历史中的 APK 大文件；修复 Flutter 版本约束和 GITHUB_TOKEN 权限问题。URL: https://taskota-front.vercel.app

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `bfa33fd` | (see git log) |
| `906fe1d` | (see git log) |
| `60bf20c` | (see git log) |
| `decc3af` | (see git log) |
| `4280faf` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 12: 修复 WxPusher 推送漏发 + spec 记录

**Date**: 2026-06-08
**Task**: 修复 WxPusher 推送漏发 + spec 记录
**Branch**: `master`

### Summary

确认根因：scan-wechat-reminders 的5min时间窗口导致WxPusher瞬时失败后无法补发；修复为24h窗口并加错误日志；修Flutter推送body中文；写server-push.md合约spec

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `98cc9ad` | (see git log) |
| `0eb7bed` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 13: perf: 消除思维导图拖拽/tab切换卡顿

**Date**: 2026-06-08
**Task**: perf: 消除思维导图拖拽/tab切换卡顿
**Branch**: `master`

### Summary

分层渲染画布（AnimatedBuilder 只包 CustomPaint，节点层各自独立 VLB）；_nodeDragging 改 ValueNotifier 替代 setState；_saveOffsets 加 300ms 防抖；O(n²) parentId 查找改为 O(n) Set；spec 更新记录 Canvas 性能模式

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `f897d18` | (see git log) |
| `049ba46` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 14: 移除 WxPusher 微信推送功能

**Date**: 2026-06-08
**Task**: 移除 WxPusher 微信推送功能
**Branch**: `master`

### Summary

WxPusher被微信封禁，删除所有微信推送相关代码（6个文件删除，4个文件修改，955行净删除），flutter analyze无error，Aliyun推送继续覆盖Android用户

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `11b4188` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 15: fix: 思维导图完成状态不同步到日历 bug

**Date**: 2026-06-08
**Task**: fix: 思维导图完成状态不同步到日历 bug
**Branch**: `master`

### Summary

修复 CalendarPage._reloadData 2秒节流导致 BlocListener 触发的刷新被跳过，造成思维导图完成任务后切回日历仍显示未完成。给 _reloadData 加 force 参数，BlocListener 调用传 force:true 绕过节流。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `f97adc3` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 16: 首页任务详情描述可编辑

**Date**: 2026-06-09
**Task**: 首页任务详情描述可编辑
**Branch**: `master`

### Summary

首页任务详情描述始终显示可编辑区域，移除空描述隐藏守卫，添加占位提示'添加描述...'，支持直接输入和节流自动保存

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `1cbafbb` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 17: 繁星计划申请书+商业计划书

**Date**: 2026-06-09
**Task**: 繁星计划申请书+商业计划书
**Branch**: `master`

### Summary

为Taskora参加阶跃星辰繁星计划第二期准备完整申请材料：申请书字段内容（去AI味，聚焦思维导图/时间轴/冲突检测差异化）+ 含6张产品截图的PDF商业计划书，输出至项目根目录fanxing/目录

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `b7acb81` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
