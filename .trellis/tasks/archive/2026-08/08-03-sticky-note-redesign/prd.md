# brainstorm: 便签美化 + 点击跳首页定位任务 + 时间轴/四象限联动

## Goal

Windows 桌面版 Taskora 关闭进托盘后，右上角显示悬浮便签（`DesktopFloatingTaskTab`）。现状痛点：
1. **便签丑**：有黑色/深色边框线（`Border.all(priorityColor.withValues(alpha:0.48))` 叠在 bgCard 上造成的视觉黑边）。
2. **点击行为**：点便签当前跳 `TaskDetailPage`（详情页），应改为**跳首页定位到该任务**。
3. **联动**：定位时时间轴维度要自动对应（跨天任务→day 维度，小时任务→hour 维度），四象限也要对应上。

## What I already know

### 便签现状
- 渲染组件：`lib/presentation/widgets/desktop_floating_task_tab.dart` — `DesktopFloatingTaskTab`，卡片 344x96（外层窗口 360x112，Padding 8），右上角对齐。
  - 结构：`Material(bgCard 0.98, radius 8, elevation 10, shadowColor black 0.18)` → `InkWell(onTap)` → `Container(radius 8, border: Border.all(priorityColor.withValues(alpha:0.48)))`。
  - "黑线"来源：0.48 alpha 优先级色边框叠在 bgCard 上，在暗色背景下呈黑/深线；且 Material 与内层 Container 双层圆角+边框叠加易出描边伪影。
- 控制器：`lib/core/desktop/desktop_floating_tab_controller.dart` — `DesktopFloatingTabController`（单例 ChangeNotifier），`handleCloseRequested`→`_selectTaskForFloatingTab`（按 score=priority*2+urgency 选候选）→`_enterFloatingMode`；`restoreFullWindow({openTaskId})`→`_openTaskDetail(taskId)`。
- 点击接线：`lib/main.dart` → `DesktopFloatingTaskTab.onTap` → `restoreFullWindow(openTaskId: currentTask.taskId)` → 控制器 `_openTaskDetail` push `TaskDetailPage`。

### 首页现状
- `HomePage`（`lib/presentation/pages/home/home_page.dart`）5 tab IndexedStack：[0] `_HomeContent`（时间轴+四象限）、[1] `TasksPage`、[2] `CalendarPage`、[3] `AssistantPage`、[4] `ProfilePage`。
- `_HomeContent` 已有：
  - 时间轴 `_timelineMode` ∈ {'hour','day'}，`_selectTask(_TimelineTask)` 已能自动切维度（非今天+hour→day；今天+day→hour）后 `_scrollToTask`。
  - 四象限 `_buildQuadrantChart()`：q1 紧急重要 / q2 重要不紧急 / q3 紧急不重要 / q4 不重要不紧急（urgent=date.diff(now)<=3天，important=P0/P1）；每格 `_buildQuadrant(...)` 渲染，item `onTap: _selectTask(task)`。
- 已有外部定位模式：`_jumpToMindMap` 用 `TaskNewBloc.add(LoadTasks(focusTaskId:, focusRequestToken:))` 切到 tab1 定位。

## Assumptions (temporary)

- 四象限"对应上"= 在四象限中把该任务高亮/定位到其所在象限（可能还要切 tab0 首页视图）。
- 便签视觉优化优先沿用 AppTheme token，不引入新依赖。
- 跨天判定应复用任务 isAllDay / start-end 跨日的语义。

## Open Questions

- 便签视觉方向（borderless 卡片 vs 毛玻璃 vs 主题色渐变）？
- 首页定位机制（一次性 focus token / HomePage 参数 / 复用 TaskNewBloc focusTaskId）？
- 四象限"对应"的确切交互（高亮即可 vs 滚动定位 vs 切象限视图）？
- 跨天任务判定与时间轴维度切换的精确规则/边界？

## Requirements (evolving)

* 便签去黑线、美化：**方案A**（无彩色整圈描边 + cardShadow 阴影分层 + 100% 不透明卡 + 圆角12 + 左侧优先级色条 + 标题色点）
* 点击便签 → 恢复窗口 + 跳首页 tab0 + 定位该任务（时间轴维度自动 day/hour 对应）
* 时间轴维度规则：跨天 OR isAllDay → day；非今天单日 → day；今天小时任务 → hour
* 四象限：只对 `_selectedTaskId` 对应项加高亮，不要求自动滚动可见
* **便签候选任务选择：弃用现有 `priority*2 + urgency` 复杂打分**。分层规则（2026-08-03 最终确认）：**小时级任务（单日非全天）优先**，层内"进行中→距 now 最近，无 startDate 不进入排序"；**跨天/全天任务随后**用同规则排后（`_selectTaskForFloatingTab` / `rankCandidates` 重写）

## Acceptance Criteria (evolving)

* [ ] 便签无黑色描边，深浅主题下均美观，与 AppTheme 一致（方案A）
* [ ] 点便签不再进详情页，进入首页并定位到该任务
* [ ] 跨天任务/全天任务(isAllDay)定位时时间轴切到 day 维度；今天小时任务切到 hour 维度
* [ ] 四象限中该任务处于高亮状态（`_selectedTaskId` 匹配）
* [ ] 便签候选 = 小时级任务优先（层内：进行中→距 now 最近，无 startDate 不进入排序）；跨天/全天任务按同规则排后（不再按优先级打分）

## Definition of Done

- 测试覆盖（单元/组件级，便签 widget + 首页 focus 逻辑）
- `flutter analyze` 通过；Windows 桌面构建通过
- 桌面 + Web 双端编译不破（遵守 platform-compatibility 条件导出）
- 文档/CHANGELOG 视改动更新

## Out of Scope (explicit)

* 不做跨平台（Android/iOS）便签
* 不引入新第三方 UI 依赖（除非调研强烈建议）
* 便签窗口的 window_manager 配置可调整（透明/opacity 用于修黑线与白屏），但保持窗口尺寸 360x112 / 置顶 / 拖拽语义
* 不做真毛玻璃（flutter_acrylic 等，列为 V2）

## Spec Conflicts

* 无硬冲突。注意 quality-guidelines（setState→VLB、防抖）与 platform-compatibility（window_manager 仅桌面、条件导出）约束。

## Technical Notes

- 关键文件：`desktop_floating_task_tab.dart` / `desktop_floating_tab_controller.dart` / `home_page.dart` / `main.dart`
- AppTheme token：`bgCard`/`textPrimary`/`textSecondary`/`borderSubtle`/`cardShadow`/`priorityP0..P3`
- 窗口 360x112 由 `window_manager.setMinimumSize/MaximumSize/Size` 固定

## Research References

* [`research/ui-design.md`](research/ui-design.md) — 黑线根因=三层叠加(深色挤出阴影+48%彩色整圈描边+98%不透明卡)；推荐方案A(无描边+cardShadow阴影分层+不透明卡+圆角12)+可选hairline兜底
* [`research/home-focus-mechanism.md`](research/home-focus-mechanism.md) — restore 时 HomePage 全新重建；推荐机制A=控制器一次性 pendingFocusTaskId+token，_loadData 完成后 postFrame 复用 `_processPendingNotificationTask` 范式消费
* [`research/timeline-quadrant-rules.md`](research/timeline-quadrant-rules.md) — 跨天判定=date/endDate 不同日(_isMultiDayNode，不用 isAllDay)；_selectTask 现逻辑对"跨天 start 今天"会被推进 hour(缺陷)；四象限无高亮；需 R1 跨天优先切 day + R5 象限高亮

## Converged Approach (已确认)

**1. 便签美化**（方案A，已确认）：`desktop_floating_task_tab.dart` — 去整圈彩色描边；阴影从 Material elevation 迁到 `BoxDecoration.boxShadow: AppTheme.cardShadow`；卡片 100% 不透明 bgCard；圆角 8→12；优先级只留左侧色条+标题色点。零新依赖。

**2. 点击跳首页定位**（机制A，已确认）：控制器加 `pendingFocusTaskId`+token；`restoreFullWindow` 开头写入，删除 `_openTaskDetail` 的 push 逻辑；`_HomeContentState` 在 `_loadData` postFrame（`_processPendingNotificationTask` 旁）消费：匹配 `t.id==taskId || t.taskId==taskId` → `_selectTask`+`_scrollToTask` → 清空。HomePage restore 重建已证实。

**2b. 候选任务选择简化**（V1 已确认：进行中优先；**已被 V2 Q1 分层规则取代**）：重写 `_selectTaskForFloatingTab`（desktop_floating_tab_controller.dart:213-261）——现状只取 `status==0`(待办) 且按 `_scoreTask = priority*2 + urgency` 打分；改为：
1. 候选池 = 未完成任务（`status==0` 待办 + `status==1` 进行中，`deleted==0 && archived==0`），弃用 `_scoreTask` 打分；
2. **① 进行中优先**：池内存在 `status==1` → 取其中 anchor time（startDate ?? dueDate）距 now 最近者（平局取 updatedAt 最新）；
3. **② 否则时间最近**：池内按 anchor time 距 now 最近者（平局取 updatedAt 最新），保留"有子任务优先看子任务"作为此步的候选过滤；
4. `extraTaskCount` = 候选池数 - 1。

**3. 时间轴维度+四象限**（规则集，已确认）：
- R1 跨天 OR isAllDay 优先→day：`_selectTask` 在 isToday 判断前先查 `_isMultiDayNode(task) || task.isAllDay`，命中且 hour→切 day。需给 `_TimelineTask` 补 `isAllDay` 字段并在 `_loadData` 带出（DB `Task.isAllDay`）。
- R2 非今天单日→day（保留）；R3 今天非全天小时任务→hour（保留）；R4 postFrame 统一滚动
- R5 象限高亮：`_buildQuadrant.taskItem` 加 `isSelected = task.id == _selectedTaskId`，主色描边+辉光容器（不做自动滚动可见）
- R6 守卫语义不变；R7 180天窗外为已知边界

## Decision (ADR-lite)

- **Context**: 便签丑(黑线)+点击行为错(跳详情而非首页定位)+时间轴/象限不联动
- **Decision**: 便签方案A(无描边+阴影分层)；定位用控制器一次性 pendingFocusTaskId+token，_loadData postFrame 消费；时间轴规则"跨天或全天→day、今天小时→hour"；象限仅高亮
- **Consequences**: 零新依赖；象限高亮但极靠后任务需用户横向/纵向手动查看；isAllDay 需穿透 `_TimelineTask`

---

## V2 复盘：实测反馈 + 根因（2026-08-03，4 子 agent 调研）

### 用户实测反馈（上一轮 3 项中仅"跳首页定位"生效）
1. **黑线仍在** — 方案A 只处理卡片内描边，未触及真实根因。
2. **便签不是最近任务** — "进行中优先"规则选出陈旧进行中任务，非时间最近。
3. **关闭便签再打开 → 白屏** — 新增回归（缩小窗口方案固有代价）。
4. **点击跳首页卡顿** — HomePage 互斥重建 + 8~10 个串行 IPC。
5. **本质质疑** — 确认：便签 = 主窗口 `setSize(360x112)` 缩小，非独立便签窗。

### 根因（子 agent 调研，含 window_manager 原生源码与 GitHub issue 佐证）
| 问题 | 根因 | 证据 |
|------|------|------|
| 黑线 | window_manager `TitleBarStyle.hidden` 时 Windows `WM_NCCALCSIZE` 内缩 8px 绘制 OS 非客户区深色边框；窗口未设透明（`ensureWindowManagerInitialized` 未传 WindowOptions），卡片四周 8px Padding 透出窗口背景 | window_manager_bridge_desktop.dart:11；window_manager.cpp:165-179/812-823 |
| 非最近任务 | `rankCandidates` 池内存在 `status==1` 就只看进行中 → 陈旧进行中压过今天到期待办；无日期任务 anchor=now 距 0 恒赢 | desktop_floating_tab_controller.dart:267-279 |
| 白屏 | window_manager 0.5.1 hide→show 后 surface 不重绘（GitHub #155/#258/#571，社区方案 = hide 前 `setOpacity(0)`、show 后 `setOpacity(1)`）；最大化恢复触发 #383 | controller:145-147/121-135；leanflutter/window_manager issues |
| 跳转卡 | main.dart:300-341 BlocBuilder 互斥重建 HomePage → 全量重查库 + Supabase 拉取 + 360 天时间轴重算 + 通知重调度（约 40-50%）；restore 链 8~10 个串行 windowManager IPC（约 30-40%）；_scrollToTask 300ms（约 15-20%） | main.dart / controller:185-211 |
| 非独立便签 | 确认：无独立窗口，整个 App 引擎/路由/数据随缩小窗口运行 | controller:150-183 |

### 修复方向（待用户确认，见 Open Questions V2）
- **黑线**：`_enterFloatingMode` 加 `setTransparent(true)` + `setBackgroundColor(transparent)`；`_restoreWindowChromeAndBounds` 对称 `setTransparent(false)`。
- **白屏**：`hideToTray` hide 前 `setOpacity(0)`；`restoreFullWindow` show 后 `setOpacity(1)`；`_restoreWindowChromeAndBounds` 先 show 再 maximize（规避 #383）。
- **卡顿**：main.dart home 改 `Stack + Offstage` 常驻 HomePage（State 不销毁、数据在内存、滚动控制器就绪 → 恢复近瞬时）；`_restoreWindowChromeAndBounds` 中 6 个独立 chrome 调用 `Future.wait` 并行。blast radius：restoreFullWindow/DesktopFloatingTaskTab/HomePage 均 LOW。
- **选任务规则**：重定（见 Open Questions V2 Q1）。
- **架构**：`desktop_multi_window` 独立便签窗（RustDesk/Mixin 生产级）可根治黑线/白屏/卡顿，但需改 `flutter_window.cpp` 重注册插件 + 跨引擎数据同步，投入数天 → 列为 V2 单独立项。

### Open Questions (V2) — 已确认
- **Q1 选任务规则 → 分层纯时间最近（用户 2026-08-03 最终确认）**：候选池 = 未完成任务（`status==0` 待办 + `status==1` 进行中，`deleted==0 && archived==0`）。分层：**① 小时级任务（单日非全天）优先**；**② 跨天/全天任务（isAllDay || 跨日）靠后**。每层内排序：**进行中（status==1）优先 → 距当前时间最近（anchor=startDate，无 startDate 不进入排序）→ 平局取 updatedAt 最新**。整体顺序 = 层①结果 + 层②结果。`rankCandidates` 重写 + 单测更新。
- **Q2 架构路径 → 直接重构独立便签窗（用户 2026-08-03 确认）**：用 `desktop_multi_window` 做第二个轻量引擎窗承载便签，根治黑线/白屏/卡顿三个旧架构固有 bug。主窗口常驻不缩小；便签窗独立透明无边框置顶。见下方 V3 重构方案。

### V3 重构方案：desktop_multi_window 独立便签窗（已确认，实施中）

**目标架构**：
```
[主引擎 main.dart]                    [便签引擎 NoteWindow（同进程第二 Flutter engine）]
  主窗口 HomePage 常驻（不缩小/不重建）        透明 360x112 无边框置顶小窗
  关闭→ hideToTray() 隐藏主窗口               显示任务摘要（标题/优先级/时间）
  + 创建并显示便签窗（compute 摘要后推送）      点击 → invokeMethod('openMain', taskId)
  接收 invokeMethod → show+focus 主窗口         关闭 → 销毁便签窗 + 置 dismissed
  + pendingFocusTaskId 消费定位
```

**关键要点**：
1. 依赖：新增 `desktop_multi_window`（与 window_manager 的兼容性/是否需要 MixinNetwork fork 以调研结论为准）。
2. 原生：`windows/runner/flutter_window.cpp` 为第二窗口注册插件（desktop_multi_window README 的 Setup 节）。
3. 数据同步：主引擎算好 `DesktopFloatingTaskSummary`（复用 rankCandidates 纯时间最近）→ 通过窗口间 MethodChannel 推给便签窗；便签窗是纯展示壳，不读 SQLite，避免双引擎并发 DB。
4. 便签窗窗口管理：WindowController → alwaysOnTop + hidden 标题栏 + 透明背景（去黑线）+ setSize(360x112) + 右上角对齐 + skipTaskbar。
5. 点击唤起：便签窗 invokeMethod('openMain', taskId) → 主引擎 `windowManager.show()+focus()` + 写 `pendingFocusTaskId` → HomePage（常驻）`_loadData` postFrame 消费定位。
6. 关闭语义：便签窗"关闭"→ 销毁便签窗 + 主引擎置 `_dismissedUntilRestore`（下次关闭不弹便签，直到主窗恢复）。
7. 移除：`_enterFloatingMode`/`_restoreWindowChromeAndBounds` 的缩小/恢复逻辑（窗口不再 resize）。

**行为契约（V3，待实施时落 .behavior_contract）**：
- C1 关闭主窗 → 主窗隐藏 + 便签窗出现，摘要=纯时间最近任务
- C2 点便签 → 主窗 show+focus，便签窗销毁，首页定位到该任务（维度/象限联动沿用 V1 R1-R7）
- C3 便签关闭 → 便签窗销毁，主窗保持隐藏；再次关闭主窗不弹便签（dismissed）
- C4 便签窗无黑线（透明背景）、无白屏（独立引擎不重绘主窗）、点击恢复无卡顿（主窗常驻）

### V3 实施计划（待用户确认后落地）

**架构一句话**：主窗常驻永不缩放；关闭→隐藏主窗 + 懒建并复用（#484 句柄泄漏规避）独立便签窗（第二引擎，desktop_multi_window）；点便签→便签自隐 + invokeMethod 唤起主窗定位；便签窗内自己初始化一份 window_manager（透明去黑线 + 无边框 + 置顶 + 360x112 右上）。

**改动文件清单**
| 文件 | 操作 | 说明 |
|------|------|------|
| `pubspec.yaml` | 改 | `+ desktop_multi_window: ^0.3.0`（不依赖 window_manager、Windows 无需换 fork；window_manager ^0.5.1 不变） |
| `windows/runner/flutter_window.cpp` | 改 | `+ #include "desktop_multi_window/desktop_multi_window_plugin.h"`；OnCreate 内 `RegisterPlugins` 后加 `DesktopMultiWindowSetWindowCreatedCallback([](void* c){ RegisterPlugins(reinterpret_cast<flutter::FlutterViewController*>(c)->engine()); });`（第二引擎自动重注册插件，无需改 main.cpp） |
| `lib/main.dart` | 改 | main() 顶部 `WidgetsFlutterBinding.ensureInitialized()` 后分支：`if (!kIsWeb && isDesktop) { final role = await _noteWindowRole(); if (role == 'note') { runApp(const NoteWindowApp()); return; } }`（跳过 Supabase/服务/托盘/通知等全部重初始化）；`_MyAppState.build` home 的 BlocBuilder **删除 DesktopFloatingTaskTab 浮动分支** → 已认证即返回 HomePage |
| `lib/core/desktop/desktop_floating_tab_controller.dart` | 改 | **删**：`_enterFloatingMode`/`_restoreWindowChromeAndBounds`/`_mode`/`_lastFullBounds`/`_lastFullWasMaximized`/`DesktopWindowMode`/`currentTask`/`isFloating`。**新增**：便签窗生命周期（懒建 `WindowController.create(hiddenAtLaunch:true, args:{role:note,summary})` + 常驻 show/hide）+ 主窗收消息 handler（`showMain`/`dismissNote`）+ `_selectTaskForFloatingTab` 推 `notifyTask` + `rankCandidates` 改分层规则（小时级优先→进行中→时间最近，无 startDate 不入排序；跨天/全天同规则靠后）。`handleCloseRequested`→计算摘要→确保便签窗→push→便签自显→隐藏主窗；`restoreFullWindow`→show+focus 主窗 + `hideNote` + pendingFocus + 重置 dismissed；`closeFloatingTab`→置 dismissed + 便签自隐（主窗保持隐藏） |
| `lib/presentation/pages/floating_note/note_window_app.dart` | **新增** | `NoteWindowApp`：透明 MaterialApp+Scaffold 内嵌复用 `DesktopFloatingTaskTab`。便签引擎 main() 内 window_manager 初始化（`setTransparent(true)`+`setBackgroundColor(transparent)`+`setTitleBarStyle(hidden)`+`setAlwaysOnTop(true)`+`setSkipTaskbar(true)`+`setSize(360x112)`+`setAlignment(topRight)`，hide/show 用 setOpacity(0/1) 包裹规避 #571）+ 注册 `notifyTask`/`hideNote` handler + 从 arguments 读初始摘要 |
| `lib/presentation/widgets/desktop_floating_task_tab.dart` | 复用 | 卡片 UI 不动，被 NoteWindowApp 内嵌（onTap→hide self + invokeMethod('showMain')；onClose→hide self + invokeMethod('dismissNote')） |
| `test/floating_tab_controller_test.dart` | 改 | `rankCandidates` 用例改纯时间最近语义：待办今天 > 进行中3天后；同距进行中优先；平局 updatedAt |
| `CHANGELOG.md` / `.trellis/.../code/change_report.md` | 改 | 记录重构落地 |

**窗口间协议（MethodChannel，先 register 后 invoke 防 #477）**
| 方向 | 方法 | 载荷 | 含义 |
|------|------|------|------|
| 主→便签 | notifyTask | summary JSON | 更新便签显示的任务摘要 |
| 主→便签 | hideNote | - | 主窗恢复时隐藏便签 |
| 便签→主 | showMain | {openTaskId} | 点便签：唤起主窗 + 定位任务 |
| 便签→主 | dismissNote | - | 点关闭：主窗保持隐藏，置 dismissedUntilRestore |

**行为契约（V3，落地时写 .behavior_contract）**
- C1 关闭主窗（认证态）→ 主窗隐藏 + 便签窗显示分层选出的任务（小时级优先→进行中→时间最近；无候选→只隐藏不弹）
- C2 点便签 → 主窗 show+focus，便签自隐，首页定位该任务（维度/象限联动沿用 V1 R1-R7）
- C3 便签"关闭" → 便签自隐，主窗保持隐藏；再次关闭主窗不弹便签；恢复主窗后重置
- C4 托盘恢复 → 主窗 show+focus + 便签 hide
- C5 二次关闭主窗 → 复用既有便签窗（不重复创建），notifyTask 更新摘要
- C6 便签窗无黑线（透明背景去 OS 边框）/无白屏（主窗零缩放、便签窗独立引擎）/恢复无卡顿（主窗常驻零重建）

**平台兼容**
- desktop_multi_window 仅桌面：main() 便签分支、控制器便签窗方法全部 `if (!kIsWeb && isDesktop)` 守卫；**Web 构建需回归**（`flutter build web` 必须仍绿，Vercel 部署依赖）
- 便签窗内 window_manager 初始化仅在便签引擎分支执行，不影响主引擎

**风险与验证**
- 原生 cpp 改动 → `flutter build windows --debug` 验证编译；`flutter analyze` + 单测兜底；第二窗口渲染无法本机可视验证 → 交用户 release 构建实测
- 便签窗 hide/show 复用同引擎（规避 #484 句柄泄漏），隐藏用 setOpacity(0) 包裹（规避 #571 白屏）

---

## V4 崩溃+白屏修复（2026-08-03 release 实测后）

**用户实测**：关闭主窗 → 弹出一个小窗口（白屏）→ 一两秒内整个应用消失。

### 根因诊断（事件日志 + 原生源码三级证据）

| 证据 | 结论 |
|------|------|
| Windows 事件日志（16:25:23 = 关闭时刻，偏移 `0xa015` 稳定） | `Taskora.exe` 在 `window_manager_plugin.dll` 崩溃，异常码 `0xc0000005`（空指针访问） |
| window_manager 0.5.1 `SetSkipTaskbar`（window_manager.cpp:949） | 直接解引用 `taskbar_->HrInit()`；`taskbar_`（ITaskbarList3*）**只在 `WaitUntilReadyToShow()`（window_manager.cpp:227 `CoCreateInstance`）里初始化** |
| 项目对照 | 主引擎 `tray_service_desktop.dart` 先 `waitUntilReadyToShow()` 再 `setSkipTaskbar` → 不崩；**便签引擎 `_initNoteWindowChrome` 漏 `waitUntilReadyToShow`，直接 `setSkipTaskbar(true)` → `taskbar_` 为 null → 崩溃** |

**连锁**：desktop_multi_window 是**同进程多引擎**，便签引擎崩溃 = 整个进程崩溃 → 便签窗（白屏窗口）随进程消失。日志在命中候选后 88ms 戛然而止正是崩溃点。

**白屏**：主引擎 `_showNoteWindow` 在 create 后立即 `note.show()`，此时便签引擎还没 `runApp`，窗口无内容 → 白屏。

### 修复方案 A（用户已确认 2026-08-03，对齐官方 waitUntilReadyToShow 模式）

**改前**：`runNoteWindow` 先 `_initNoteWindowChrome`（含 `setSkipTaskbar`→崩溃）再 `runApp`；主引擎 create 后立即 show。

**改后**：
1. `runNoteWindow`：先注册通道 + 加载摘要 + `runApp`，首帧渲染完成后再初始化窗口样式并**自显示**（`addPostFrameCallback`）。
2. `_initNoteWindowChrome`：`setSkipTaskbar` 前先 `waitUntilReadyToShow()`（初始化 taskbar_，**修崩溃**）；末尾 `windowManager.show()`（渲染后显示，**消白屏**）。
3. 主引擎 `_showNoteWindow`：首次创建不再调 `note.show()`（等便签引擎渲染后自显示）；复用时才 `_notifyNote` + `show()`。

**行为契约（V4）**
- C1 关闭主窗（认证态）→ 便签窗出现且**不白屏**（渲染后显示），主进程**不崩溃**
- C2 点便签 → 主窗 show+focus + 首页定位；点关闭 → 主窗保持隐藏
- C3 二次关闭主窗 → 复用便签窗，notifyTask 更新摘要后显示
- C4 便签窗无黑线（透明背景）；恢复主窗无卡顿（主窗常驻）

**验证方式**：`flutter analyze` + 单测 + `flutter build windows --debug` 编译验证；真实窗口渲染/崩溃消失需 release 构建实测（交用户）。
