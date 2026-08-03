# Research: 便签点击 → 恢复窗口 → 首页 tab0 时间轴定位任务

- **Query**: 从桌面悬浮便签点击 → 恢复窗口 → 跳到首页 tab0 → 定位到该任务（时间轴选中并滚动）的最靠谱实现机制
- **Scope**: internal（全部基于代码实读，未修改任何文件）
- **Date**: 2026-08-03

## 0. 结论先行

**推荐机制 A：在 `DesktopFloatingTabController` 上加"一次性 focus 请求字段"（taskId + 时间戳 token），由 `_HomeContentState` 在 `_loadData` 完成后的 postFrame 回调中消费** —— 这与代码库中已有的通知点击定位模式 `NotificationService.pendingTaskId` + `_processPendingNotificationTask()` 完全同构，改动面最小、无导航副作用、行为可预期。

关键前提（已确认）：**restore 时 HomePage 是全新重建的**（见 §1），因此"initState 一次性消费"可行，消费点可确定。

---

## 1. HomePage 是否新建？—— 是，每次 restore 全新重建

### 1.1 触发链（restore → 重建）

`main.dart` 用 `ListenableBuilder` 监听控制器（main.dart:277-281）：

```dart
ListenableBuilder(
  listenable: Listenable.merge([themeController, _desktopFloatingTabController]),
  builder: (context, _) => MaterialApp(...),
)
```

`BlocBuilder<AuthBloc, AuthState>` 的 builder（main.dart:300-341）在 `isFloating && currentTask != null` 时返回 `DesktopFloatingTaskTab`，否则返回 `HomePage(...)`（main.dart:330-337）。两者**互斥**，`DesktopFloatingTaskTab` 与 `HomePage` 是不同 widget 类型。

`restoreFullWindow`（desktop_floating_tab_controller.dart:121-135）在模式为 floating 时先调 `_restoreWindowChromeAndBounds()`，其中：

```dart
_mode = DesktopWindowMode.full;
_currentTask = null;
notifyListeners();            // desktop_floating_tab_controller.dart:188-190
```

`notifyListeners()` → `ListenableBuilder` rebuild → `MaterialApp` 的 `widget.home` 从 `DesktopFloatingTaskTab` 变为 `HomePage`。

### 1.2 Flutter 框架层面确认（home 路由确实重建）

- `WidgetsAppState._onGenerateRoute`（`E:\flutter\flutter\packages\flutter\lib\src\widgets\app.dart:1552-1553`）为 `/` 路由生成的 builder 是 `(BuildContext context) => widget.home!` —— 闭包读的是**当前** `widget.home`，每次页面重建都会重读。
- Navigator widget 更新时 `NavigatorState.didUpdateWidget`（navigator.dart:4055-4059）对每个 route 调 `route.changedExternalState()`。
- `ModalRoute.changedExternalState`（routes.dart:2234-2240）→ `_scopeKey.currentState!._forceRebuildPage()` → `setState(() => _page = null)`（routes.dart:1141-1145），强制 home 路由页面重建，重新读 `widget.home`。
- 新 home widget 类型（`DesktopFloatingTaskTab` → `HomePage`）与旧不同 → Element 整棵替换 → **`_HomePageState` 全新创建**。

### 1.3 对 _HomeContent 的影响

- `_HomePageState` 全新 → `late final List<Widget> _pages = _buildPages()`（home_page.dart:101）重新执行 → 新的 `_HomeContent`（含 `ValueKey('home_content')`，home_page.dart:174）→ **`_HomeContentState.initState` 重跑**（home_page.dart:795-816）→ `WidgetsBinding.instance.addPostFrameCallback((_) => _loadData())`（home_page.dart:815）。
- `_tabIndex` / `_visibleTabIndex` 均以 `ValueNotifier<int>(0)` 初始化（home_page.dart:81-84）→ **restore 后天然落在 tab0**，`_visible == true`（home_page.dart:813），`_loadData` 会正常执行。

### 1.4 由此确定

"一次性 focus token 在 initState 消费"是**可行**的（HomePage 每次 restore 都重建）。但更稳妥的消费点是 `_loadData()` 完成后的 postFrame（见 §6 边界），因为数据是异步的。

---

## 2. home_page.dart 关键结构

### 2.1 `_TimelineTask` 字段（home_page.dart:5475-5501）

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | String | 节点 id；DB 源 == `task.id`，storage 源 == `t.id` |
| `title` | String | 标题 |
| `description` | String? | 描述 |
| `date` | DateTime | 锚点日期：DB 源 = `startDate`（有）否则 `dueDate`（有）否则 now（home_page.dart:901-905） |
| `endDate` | DateTime? | DB 源 = `dueDate`（home_page.dart:906-908）；storage 源 = `t.endDate` |
| `isCompleted` | bool | DB 源：`t.status == 2`（home_page.dart:916）；storage 源：`t.status == 'completed'` |
| `priority` | String | **已归一化为标签** 'P0'/'P1'/'P2'/'P3'（`_dbPriorityToLabel`，home_page.dart:1229-1240：DB int 5/3/1 → P0/P1/P2，默认 P3） |
| `source` | String | 'db' 或 'storage' |
| `projectId` | String? | DB 源 = `t.projectId`；storage 源 = null |
| `taskId` | String | 与 `id` 相同（DB 与 storage 都是 `t.id`） |
| `parentId` | String? | 父节点 id |

注意：对 DB 源任务 `id == taskId == DB task.id`，所以便签携带的 DB `taskId` 可直接按 `t.id == taskId || t.taskId == taskId` 匹配（与 `_processPendingNotificationTask` home_page.dart:1032 一致）。

### 2.2 数据来源与生成链路

- `_loadData()`（home_page.dart:844-1010）：
  - 项目/项目组缓存：`widget.projectRepository.getActive()`、`widget.projectGroupRepository.getAll()`（854-861）。
  - 主数据源：`widget.taskRepository.getAll()`（866），再剔除 `storage.excludedProjectIds`（868-871）。
  - storage 源：`widget.storage.getTasks()` 中不在 DB 里的项（878-897），`source: 'storage'`。
  - DB 源：遍历 `dbTasks`（899-924），`source: 'db'`。
  - 排序：`date` 升序、再按 `title`（927-931）。
  - 恢复持久化筛选（local + 云端，936-975）→ `_applyProjectFilter()`（977）→ postFrame 里 `_processPendingNotificationTask()` + `_scrollToNow()`（1006-1009）。
- `_displayTasks`（home_page.dart:1070-1081）= `_filteredTasks` 按 `_nodeTypeFilters`（parent/child/multiday/singleday）过滤。
- `_applyProjectFilter`（1083-1108）：按 `_filterProjectIds` + `_completionFilter` 过滤；若当前选中项被过滤掉 → `_selectedTask = _nearestTask(_filteredTasks)`；无选中时也默认选中 `_nearestTask`（距 now 最近，1127-1138）。

### 2.3 `_selectTask`（home_page.dart:1195-1226）与 `_scrollToTask`（1140-1167）

`_selectTask`：
1. `setState` 写 `_selectedTaskId`/`_selectedTask`（1197-1198）。
2. `_modeSwitchGuard` 为 true（手动 UI 切模式时置位，home_page.dart:3481-3486）→ 只 `_scrollToTask` 返回（1202-1205）。**程序化 focus 不经过手动切模式路径，不受 guard 影响。**
3. 自动切维度：任务不在今天且当前为 hour → 切 day（1213-1217）；在今天且当前为 day → 切 hour（1218-1222）；切完在 postFrame 里 `_scrollToTask`。否则直接 `_scrollToTask`（1224）。
   - **即 `_selectTask` 已内置"自动切 day/hour + 滚动"，定位到该任务只需调用它即可。**

`_scrollToTask`：
- hour 模式：目标 `task.date.hour * _hourWidth`（今天）或 `12 * _hourWidth`（非今天，默认中午），再 `- midScreen + _hourWidth/2` 居中（1146-1154）。
- day 模式：`task.date.difference(baseDate).inDays * _dayWidth - midScreen + _dayWidth/2`，baseDate = 今天前 `_daysBefore`(=180) 天（1156-1159）。
- `animateTo(300ms, easeInOut)`（1162-1166）；前置条件 `_timelineController.hasClients`，否则直接 return（1141）。

### 2.4 已有"外部一次性定位"入口

- **通知点击路径（现有可复用范式）**：`NotificationService.pendingTaskId` / `pendingMarkDoneTaskId` 是**静态字段**（notification_service_io.dart:61-64），由 `_processPendingNotificationTask`（home_page.dart:1013-1041）在 `_loadData` 完成后的 postFrame 中消费并**清空**（1023）。命中后 `_selectTask(task)` + `_scrollToTask(task)`。这是机制 A 的直接模板。
- `_jumpToMindMap`（home_page.dart:550-562）：向 `TaskNewBloc` 发 `LoadTasks(focusTaskId:, focusRequestToken:)`。该 focus 字段由 **TasksPage（tab1）** 消费（tasks_page.dart:356-400、446-447 传入 MindMapView/TaskListView；task_bloc.dart:441-480 只影响 main_tree/viewMode）。**`_HomeContent`（tab0）不读 `state.focusTaskId`** —— `_HomeContent` 唯一的 `BlocListener<TaskNewBloc>`（home_page.dart:1335-1355）只用 `state is TaskNewLoaded` 触发 `_loadData()`（节流），不读 focus 字段。

---

## 3. 机制对比（A/B/C）

### 候选 A：控制器一次性 focus 字段（推荐）

- **做法**：`DesktopFloatingTabController` 增加 `String? pendingFocusTaskId` + `int? pendingFocusRequestToken`（时间戳），`restoreFullWindow` 开头写入（或 main.dart onTap 先写入再调 restore），**不清空**（`_restoreWindowChromeAndBounds` 只清 `_currentTask`）。`_HomeContentState` 在 `_loadData` 完成 postFrame 消费：命中则 `_selectTask` + `_scrollToTask`，随后清空字段。
- **优点**：与 `NotificationService.pendingTaskId` 范式 100% 同构；不新增 widget 参数、不引入导航；HomePage 每次 restore 重建 → 消费点确定；token 防陈旧 focus。
- **缺点**：`home_page.dart` 需 import 控制器单例（新增跨层依赖，方向 core→presentation 是常规允许方向）。
- **改动面**：控制器 1 字段 + 1 消费方法（或复用 `_processPendingNotificationTask` 一并处理）。

### 候选 B：HomePage 构造参数 `initialFocusTaskId`

- **做法**：`HomePage` 增 `String? initialFocusTaskId`，`main.dart` builder 传入；`_HomePageState._buildPages` 透传给 `_HomeContent`；`_HomeContentState` 在 initState/加载后消费。
- **优点**：数据流显式、可测试、home_page.dart 不 import 控制器。
- **缺点**：**致命细节** —— `main.dart` builder 运行时 `_currentTask` 已被置 null（`notifyListeners` 在 `_restoreWindowChromeAndBounds` 内先发生），builder 读不到 `currentTask`，**仍需先存到控制器/某处再读**。也就是说 B 本质上还是要 A 的"暂存字段"，只是把消费改成构造参数传递，成本更高（HomePage → _HomePageState → _HomeContent 三层透传）。仅当希望 home_page.dart 与控制器解耦时可考虑。

### 候选 C：复用 TaskNewBloc 的 focusTaskId/focusRequestToken

- **做法**：像 `_jumpToMindMap` 那样 `context.read<TaskNewBloc>().add(LoadTasks(focusTaskId: ...))`，`_HomeContent` 监听 bloc state 消费。
- **优点**：复用已有机制。
- **缺点**：**`_HomeContent` 当前不读 `state.focusTaskId`**（§2.4），该字段只被 TasksPage/MindMap 消费；且 LoadTasks 会 `viewMode = 'mindmap'`、只对 tab1 生效，会污染 tab1 状态；bloc state 里的 focus 字段无"一次性清除"语义（要手动置回 null，而 bloc 是全局单例，与"restore 重建 HomePage"生命周期错配）。**不推荐。**

---

## 4. 推荐（机制 A）与理由

推荐 A，并**复用现有 `_processPendingNotificationTask` 的消费骨架**：

1. 控制器加：
   ```dart
   String? pendingFocusTaskId;
   int? pendingFocusRequestToken; // DateTime.now().microsecondsSinceEpoch
   ```
2. `restoreFullWindow` 开头（`_restoreWindowChromeAndBounds` 之前）写入：`pendingFocusTaskId = openTaskId`、token 打时间戳；删除/替换 `_openTaskDetail` 里的导航逻辑（desktop_floating_tab_controller.dart:288-306）。**不再 push 任何页面** —— 恢复窗口后 `widget.home` 自动重建为完整 `HomePage`（带全部 repository），落在 tab0。
3. `_HomeContentState` 在 `_loadData` 完成后的 postFrame（home_page.dart:1006-1009，`_processPendingNotificationTask` 旁）新增消费：从控制器读 pending 字段 → 在 `_timelineTasks` 按 `t.id == taskId || t.taskId == taskId` 匹配（同 home_page.dart:1032）→ 命中则 `_selectTask(task)` + `_scrollToTask(task)` → 清空 pending 字段。

理由：
- **消费点确定且无竞态**：HomePage 每次 restore 全新重建（§1 已证），`_loadData` 必然重跑，postFrame 消费一定发生。
- **行为同构**：与通知点击定位同一条路，已被验证。
- **零导航副作用**：不触发 `pushNamedAndRemoveUntil('/', ...)`。注意当前 `_openTaskDetail` 的该调用会用 `AppRouter` 的 `/` 生成一个**无 repository 参数的空 `HomePage()`**（app_router.dart:25），这在旧设计里被 TaskDetailPage 盖住；新设计必须避免。
- **token 防御**：若未来某路径下 HomePage 未重建（或 `_loadData` 多次触发），时间戳 token + 消费即清空可防止陈旧 focus 反复触发。

---

## 5. 边界处理建议

1. **数据异步就绪**：必须等在 `_loadData()` 完成后的 postFrame 消费（不能 initState 同步读，`_timelineTasks` 此时为空、`_timelineController.hasClients == false`）。`_loadData` 结尾已有 postFrame 钩子（home_page.dart:1006-1009）。
2. **任务未出现在时间轴**：若被 `excludedProjectIds`（home_page.dart:868-871）或持久化项目筛选（936-975 → 1083-1098）过滤掉，`_selectTask` 找不到该 task。建议：未命中时 `_scrollToNow(animated: true)` 兜底（可复用 1169 逻辑），不报错。注意 `_applyProjectFilter` 在无选中时会自动选 `_nearestTask`（1104-1107），不要被它覆盖刚设置的 focus —— 消费应在 `_applyProjectFilter` 之后（postFrame 位置天然满足）。
3. **维度自动切换**：`_selectTask` 内置"非今天切 day / 今天切 hour"（1195-1226），无需额外处理。
4. **`_modeSwitchGuard` 无关**：guard 只在手动 UI 切模式时置位（3481-3486）；程序化 `_selectTask` 走自动切换分支，不受影响。
5. **一次性消费**：消费后清空控制器 pending 字段，防止后续 `_loadData`（BlocListener 触发的节流加载，1335-1355）重复 focus。
6. **token 时机**：`restoreFullWindow` 中写入要放在 `_restoreWindowChromeAndBounds()`（会置空 `_currentTask`）**之前**，否则读不到 `openTaskId` 的来源。main.dart onTap 已先捕获 `currentTask?.taskId` 再传参（main.dart:315-321），控制器内再写入 pending 字段即可。
7. **父子任务**：focus 子任务时它就是独立节点，`_selectTask` 直接选中子任务节点（父链接信息在 `_parentIds` / `_isParentNode`，home_page.dart:1058-1061，不影响定位）。

---

## 6. 相关 Spec / 文档

- 无相关 `.trellis/spec` 文档。
- 本项目 `CLAUDE.md` 的 GitNexus 铁律：改前先跑 `impact`；本次为纯调研，未改动任何文件。

## Caveats

- §1 的框架链路结论基于本机 Flutter SDK（`E:\flutter\flutter`）源码实读（app.dart / navigator.dart / routes.dart）；若升级 Flutter 大版本，`WidgetsApp`/`Navigator` 处理 home 变更的细节可能变化，但"widget 类型切换 → State 重建"的 Element 语义是稳定的。
- 未验证运行期行为（未运行应用）；若对"HomePage 每次 restore 是否重建"仍有疑虑，可在 `_HomeContentState.initState` 临时加日志验证，但代码逻辑已支持该结论。
