# Research: issue1a — 便签点击 → 主窗恢复 → 首页定位任务 链路断点

- **Query**: 点击桌面悬浮便签后主窗为何不回到首页 tab0 时间轴并定位该任务（缺陷 1/2/3 + 关联 4）
- **Scope**: internal（全部基于代码实读，未修改任何文件）
- **Date**: 2026-08-04

## 0. 结论先行

**核心根因：`restoreFullWindow` 恢复主窗时，主窗 widget 树是"隐藏"而非"销毁"的，恢复后既不重建 `HomePage`，也不重跑 `_loadData`，因此 `pendingFocusTaskId` 的唯一消费点（`_loadData` 完成后的 postFrame）永远不会被触发。** 8-03 机制 A 的"restore 时 HomePage 全新重建 → tab0 → initState → _loadData → postFrame 消费"前提已不成立。

缺陷 1（跳到任务视图）、缺陷 3（不定位）是同一根因的不同表现；缺陷 2（任务消失）是"便签候选任务"与"时间轴过滤"两套数据集不一致 + focus 失败后 `_scrollToNow` 兜底导致的。详见 §5 断点排序。

---

## 1. 期望链路 vs 实际链路

### 期望链路（8-03 设计，见 archive/08-03/.../home-focus-mechanism.md §1、§4）

1. 点便签 → 便签窗自隐 + invoke `showMain(openTaskId)`（note_window_app.dart:158-166）
2. 主窗 handler 收 showMain → `restoreFullWindow(openTaskId)`（desktop_floating_tab_controller.dart:250）
3. `restoreFullWindow` 写 `pendingFocusTaskId` + token（desktop_floating_tab_controller.dart:159-161）
4. **主窗切换 mode / 清 currentTask / `notifyListeners()` → `ListenableBuilder` rebuild → `MaterialApp.widget.home` 从任务 tab 换成 HomePage → Element 整棵替换 → `_HomePageState` 全新 → `_visibleTabIndex` 归 0（tab0）→ `_HomeContentState.initState` 重跑 → postFrame `_loadData()`**
5. `_loadData` 完成 → postFrame 消费 pending → `_selectTask` + `_scrollToTask`（home_page.dart:1008-1012, 1047-1065）

### 实际链路

1. 点便签 → showMain(openTaskId)（note_window_app.dart:158-166）
2. 主窗 handler → `restoreFullWindow(openTaskId)`（desktop_floating_tab_controller.dart:244-256）
3. 写 pending + token（desktop_floating_tab_controller.dart:159-161）；`_hideNoteWindow()`（163）；`windowManager.show()+focus()`（165-166）；`desktopWindowVisible=true`（167）
4. **`restoreFullWindow` 无任何 `notifyListeners()`/mode 切换/清空逻辑**（desktop_floating_tab_controller.dart:156-168 全文）→ `ListenableBuilder`（main.dart:297-301）不重建；且即使重建，`HomePage` 是同一 widget 类型 → Element 保留 → `_HomeContentState.initState` 不重跑
5. 主窗一直是 `HomePage`（main.dart:328-337，**无 DesktopFloatingTaskTab 分支**），hide 只做 OS 级 `windowManager.hide()`（desktop_floating_tab_controller.dart:176-179）→ widget 树存活，tab 索引、滚动位置、Navigator 栈全部保留
6. **唯一能触发 `_loadData` 的旁路**：`AppLifecycleListener(onResume: _onAppResume)`（home_page.dart:112, 115-126）→ forcePullAll + syncAll + `_debounceLoadTasks()`(500ms) → LoadTasks → TaskNewLoaded → `BlocListener`（home_page.dart:1375-1387）→ 若 tab0 可见且距上次 >2s → `_loadData()`。此链路依赖网络同步、被 2s 节流和 `!_visible` 闸门拦截，非确定。

---

## 2. main.dart 如何决定显示 HomePage（Q1）

- main.dart:297-301 `ListenableBuilder(listenable: Listenable.merge([themeController, _desktopFloatingTabController]))` —— 仅控制器 `notifyListeners()` 时重建 MaterialApp。
- main.dart:319-342 `home:` = `BlocBuilder<AuthBloc, AuthState>`：`Authenticated`/`LocalAuthenticated` → **无条件返回 `HomePage(...)`**（328-337），否则 `LoginPage`（339）。
- **当前代码已无 8-03 文档记载的 `isFloating && currentTask != null ? DesktopFloatingTaskTab : HomePage` 分支**（文档 main.dart:300-341 描述的是重构前）。`DesktopFloatingTaskTab` 现在只在**便签窗引擎**使用：note_window_app.dart:146。
- 主窗被 hide 时 widget 树存活（`windowManager.hide()` 是 OS 级隐藏，desktop_floating_tab_controller.dart:176-179；`_TrayCloseListener.onWindowClose` window_manager_bridge_desktop.dart:45-55 也走同一 hide）。**restore/show 不重建 widget 树** —— 这是机制 A 失效的框架级原因。

---

## 3. pendingFocusTaskId 的消费点（Q2，核心）

### 写入（唯一）
- desktop_floating_tab_controller.dart:159-160（`restoreFullWindow` 内，openTaskId 非空时）。

### 读取 + 清空（唯一）
- home_page.dart:1047-1065 `_processFloatingTabFocusTask()`：读 `controller.pendingFocusTaskId`（1049）→ **先清空**（1051-1052）→ 在 `_timelineTasks` 里按 `t.id == taskId || t.taskId == taskId` 找（1054-1060）→ 未命中返回 false 且 pending 已丢（1061）→ 命中 `_selectTask` + `_scrollToTask`（1062-1063）。
- 仅被 home_page.dart:1010 调用（`_loadData` 的 postFrame，同帧 `_processPendingNotificationTask` 在 1009、`_scrollToNow(animated:false)` 兜底在 1011）。

### `_loadData` 何时会跑（决定消费点是否触发）
- home_page.dart:816 —— `_HomeContentState.initState` postFrame。**只有 widget 树重建才跑**；hide→show 不触发。
- home_page.dart:819-828 `_onVisibleTabChanged` —— tab0 由不可见变可见且 `_needsRefresh`。
- home_page.dart:1375-1387 `BlocListener<TaskNewBloc>` —— `TaskNewLoaded` && `!_loading` && `mounted`；tab0 不可见则只置 `_needsRefresh`（1376-1378）；距上次 <2s 直接 return（1381-1384）。
- 关键闸门：home_page.dart:848-851 `if (!_visible) return;`（`_visible` = `widget.visibleTabIndex.value == 0`，814）。

### 结论
restore 时不会发生 `_HomeContentState` 重建，`_loadData` 也不被 restore 直接触发。唯一旁路（onResume→sync→LoadTasks→BlocListener）**非确定**：依赖网络、被 2s 节流、被 `_visible` 闸门拦截。且 `_processFloatingTabFocusTask` 是"**读到即清**"，一旦某次 `_loadData` 在 pending 写入后运行时任务未命中（被过滤），pending 就永久丢失。**这是缺陷 3 的直接根因。**

---

## 4. 为何"跳到任务视图"（Q3）

- 主窗 restore 后**保留旧状态**：tab 索引 `_tabIndex`/`_visibleTabIndex`（home_page.dart:82-85）不重置；`IndexedStack(index: index, children: _pages)`（home_page.dart:528-531）。用户关主窗时在哪个 tab（如"任务"tab1、日历 tab2），restore 后仍停在那。
- home tab0 时间轴**恒有选中任务**：`_applyProjectFilter` 无选中时自动选 `_nearestTask`（home_page.dart:1128-1131）；`_buildTaskDetail()` 选中时必渲染（home_page.dart:1418）→ restore 后 tab0 常显示一个任务详情面板，观感上就是"任务视图"。
- **Navigator 栈跨 hide 保留**：hide 不弹路由。若关主窗前打开了 `TaskDetailPage`（home_page.dart:5034-5042 / tasks_page.dart:683-691 / task_list_page.dart:49），restore 后仍盖在顶层。便签链路**没有任何** `pushNamedAndRemoveUntil('/')` 清栈（只有通知/推送链路有：notification_service_io.dart:171-175, 181-185, 214-226, 568；aliyun_push_service_io.dart:74）。
- restoreFullWindow 本身无任何 tab/路由重置（desktop_floating_tab_controller.dart:156-168）。
- 即便最终 onResume→sync→_loadData 触发 focus 成功，`_selectTask` 会自动切 day/hour（home_page.dart:1232-1258）并打开对应任务详情面板，若 `_scrollToTask` 因 `hasClients` 未就绪 no-op（home_page.dart:1165），观感仍是"跳到任务视图"而非"时间轴定位"。

---

## 5. 任务为何"过一会儿消失"（Q4）

便签候选与时间轴数据是**两套口径**：

- **便签候选（无过滤）**：`_selectTaskForFloatingTab` 用 `getAllRaw()`，只过滤 status 0/1 + 未删除/未归档，**不看项目/首页过滤器**（desktop_floating_tab_controller.dart:262-294）。
- **时间轴（多重过滤）**：home_page.dart:869-872 剔除 `storage.excludedProjectIds`；home_page.dart:938-949 从本地恢复首页项目筛选 `_filterProjectIds`/`_completionFilter`；home_page.dart:950-977 从**云端 `fetchPreferences`** 覆盖同批筛选；home_page.dart:1107-1132 `_applyProjectFilter` 应用项目+完成状态过滤；home_page.dart:1094-1105 `_displayTasks` 再按 `_nodeTypeFilters`（parent/child/multiday/singleday）过滤。

消失的几条机制（按可能性）：

1. **focus 失败 + `_scrollToNow` 兜底**：任务被过滤 → `_processFloatingTabFocusTask` 返回 false（home_page.dart:1061）→ postFrame 执行 `_scrollToNow(animated:false)`（home_page.dart:1011）→ 视口跳到"现在"，便签里的任务（如在未来某天/小时）滚出屏幕 → "消失"。这是最直接的机制。
2. **云端首页筛选恢复**：restore→onResume→sync 后 `_loadData` 首次恢复云端 `homeFilters`（home_page.dart:950-977），若该任务项目不在 `_filterProjectIds` → 被过滤（1111-1116）。
3. **onResume 全量对账改变任务本身**：home_page.dart:115-126 → forcePullAll + syncAll，任务日期/状态/删除在云端被改 → reload 后任务移动/变完成。
4. **通知 markdone 副作用**：notification_service_io.dart:158-165 置 `pendingMarkDoneTaskId` → home_page.dart:1018-1022 `ToggleTaskStatus` → 任务变完成 → `_completionFilter=='pending'` 时被滤掉（1118-1119）。**与 pendingFocus 不直接冲突**（同 postFrame 先通知后便签，1009-1010），但会间接让被点任务消失/变灰。

---

## 6. 断点清单（Q5，按最可能根因排序）

| # | 断点 | file:line | 一句话根因假设 |
|---|---|---|---|
| BP1 | **消费点只在 `_loadData` postFrame；restore 不触发 `_loadData`** | desktop_floating_tab_controller.dart:156-168（无 notifyListeners/mode 切换）+ home_page.dart:1010（唯一消费）+ home_page.dart:816（initState postFrame 只在重建时跑） | hide 保留 widget 树 → 恢复不重建 → pending 永不消费 |
| BP2 | **restore 不重置 tab 索引 / Navigator 栈** | home_page.dart:82-85, 528-531；desktop_floating_tab_controller.dart:156-168 | 用户关主窗时的 tab/路由原样保留 → 显示"任务视图"而非 tab0 |
| BP3 | **便签候选 vs 时间轴过滤口径不一致 → focus 未命中 → pending 被清 + `_scrollToNow` 兜底** | desktop_floating_tab_controller.dart:262-294 vs home_page.dart:869-872/938-977/1107-1132；home_page.dart:1049-1061, 1011 | 便签能显示的任务，时间轴可能被过滤掉 → "消失/不定位" |
| BP4 | **`_scrollToTask` 在 `hasClients==false` 时静默 no-op** | home_page.dart:1165；模式切换 postFrame home_page.dart:1232-1237, 1246-1255 | restore 后时间轴未布局/用户不在 tab0 → 选中但不滚动 |
| BP5 | **旁路触发 `_loadData` 的闸门** | home_page.dart:848-851（`!_visible` return）、1381-1384（2s 节流）、1376-1378（不可见只置 `_needsRefresh`） | onResume→sync 链路非确定，任一门可拦截 reload |
| BP6 | **通知/推送链路清栈会 push 无参数空 HomePage** | notification_service_io.dart:171-175, 181-185, 214-226, 568；app_router.dart:25（`const HomePage()` 无 repo） | 与便签链路并发/先后触发时会覆盖 home 状态（与本次便签缺陷弱相关，作为环境干扰记录） |

---

## 7. 最小改动面建议（只描述位置，不写代码）

- **主修复点 = 给 restore 一个确定性的 `_loadData` 触发**。`DesktopFloatingTabController` 已是 ChangeNotifier 且被 main.dart 监听；最小做法是在 `_HomePageState` 侧监听控制器（home_page.dart:105-113 initState 附近），收到"恢复"通知时：`_tabIndex.value=0; _visibleTabIndex.value=0; _needsRefresh=true; _loadData();`。消费逻辑（home_page.dart:1047-1065）已完备，缺的只是可靠触发。
  - 备选：`restoreFullWindow` 在写 pending 后调用 `notifyListeners()`（desktop_floating_tab_controller.dart:156-168），并在 `_HomePageState` 加监听（注意：仅靠 main.dart 的 ListenableBuilder 重建不够，HomePage 同类型不重建 state）。
  - 不要走通知链路那种 `pushNamedAndRemoveUntil('/',...)`（app_router.dart:25 会生成无 repo 的空 HomePage）。
- **次修复点 = BP3 口径对齐**：要么便签候选也套用 `excludedProjectIds` + 首页筛选（desktop_floating_tab_controller.dart:262-294），要么 `_processFloatingTabFocusTask` 未命中时不清 pending 而回退 `_scrollToNow` 并提示（home_page.dart:1049-1061）。
- **回归测试缺口**：`.trellis/tests/lib/coverage/floating_tab_controller_test.dart:201-207` 只断言"写 pending + show/focus"，**没有端到端断言 hide→show 后 HomePage 消费 pending**；应补一个驱动 `_processFloatingTabFocusTask` 的用例。

---

## 8. Caveats

- 未运行应用验证 `windowManager.hide()/show()` 在 Windows 上是否触发 `AppLifecycleListener.onResume`（home_page.dart:112）；若触发，旁路可能"碰巧"成功过（解释了为何缺陷时有时无）。建议后续在 `_onAppResume` 或 `restoreFullWindow` 加日志确认。
- 8-03 归档的机制 A 文档基于重构前 main.dart（有 DesktopFloatingTaskTab 分支、restore 会 notifyListeners 切 mode）；当前代码已把任务 tab 移入便签窗引擎，机制前提失效 —— 本文件已按当前代码重新取证。
- 缺陷 4（"创建非跨天任务失败"）不在本文件范围，但 BP3/BP5 链路中未发现与创建链路直接交叉的异常；如后续需要，可单独追踪 `TaskNewBloc` 的创建事件。
