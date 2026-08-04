# Research: 首页时间轴定位缺陷 + 日历创建"非跨天任务"链路

- **Query**: 首页 tab0 时间轴定位缺陷（便签/四象限点击定位、day/hour 自动切换、日历创建任务后定位、"非跨天任务创建失败"）根因
- **Scope**: internal（全部基于代码实读 + git 历史，未改任何文件）
- **Date**: 2026-08-04

---

## 0. 结论先行（断点根因排序）

| # | 断点 | 根因 | 关键证据 | 严重度 |
|---|---|---|---|---|
| 1 | 便签点击 → 首页不定位（defect #1 便签路径） | **V3 独立便签窗设计下，restore 不再重建 HomePage**，`pendingFocusTaskId` 只在 `_loadData` postFrame 消费；而窗口 show 不触发 `_loadData`。唯一可能的触发器 `_onAppResume` 又被 `auth.currentUser == null` 挡住（本地登录用户直接 return）。08-03 归档 research 的"restore 时 HomePage 全新重建"前提在 V3 已失效。 | home_page.dart:1008-1012, 1047-1065, 112-126, 115-117; desktop_floating_tab_controller.dart:156-168; main.dart:319-342; 归档 research §1.1 vs V3 change_report | HIGH |
| 2 | 初始加载/创建后返回首页不自动切 day/hour（defect #2） | `_applyProjectFilter` 自动选中 `_nearestTask` 但**不切模式、不滚动**；hour 模式下非今天任务不渲染（3592 直接 return null）；postFrame 只 `_scrollToNow` 滚到今天。非今天 nearest 被"选中但不可见"。自动切换逻辑只在用户主动 `_selectTask` 时执行。 | home_page.dart:750, 1123-1131, 1008-1012, 3591-3592, 1231-1258 | HIGH |
| 3 | 四象限点击"没定位"（defect #3） | onTap 已正确接线到 `_selectTask`（会切模式+横向滚动），但**时间轴在页面顶部、四象限在底部**（同一 SliverToBoxAdapter 的 Column），用户滚到四象限处点击时，横向 `animateTo` 确实执行却不可见——**没有代码把外层竖向滚动拉回时间轴**。IndexedStack 使 `_timelineController.hasClients` 恒为 true，滚动照跑但屏幕上看不到。 | home_page.dart:5397-5401, 1164-1191, 1394-1426（1416 vs 1420）, 531 | MEDIUM |
| 4 | 日历创建任务后"期望定位"落空（defect #4 定位侧） | `_onCreateTask` 在 bloc snapshot 写了 `focusTaskId`，但 `_HomeContent` 的 BlocListener 只 `_loadData()`，**不读 focusTaskId**，创建的任务只被载入时间轴、不被选中/滚动。与根因 2 叠加：非今天单日任务在 hour 视图根本不可见。 | task_bloc.dart:757-758; home_page.dart:1368-1387; 归档 research §2.4 | MEDIUM |
| 5 | "非跨天任务创建不出来"（defect #4 创建侧） | **创建链路本身无单日/跨天差异分支**，本地写入一定会发生。唯一的单日专属闸门是创建弹层的冲突检测（单日才做），命中冲突且用户取消/关弹窗 → `return` 静默不创建。便签相关提交未触碰创建链路，怀疑方向基本排除。 | task_create_sheet.dart:897-978, 916-959, 917-918; task_bloc.dart:673-762; task_repository.dart:386-457; calendar_page.dart:754-803; git log a2e44eb/b411e13 | LOW（疑点基本排除） |

---

## 1. defect #1（便签点击定位）—— V3 设计下消费链路断裂

### 1.1 消费点：只在 `_loadData` postFrame（不是 initState、不是窗口显示回调）

`_HomeContentState._loadData` 末尾（home_page.dart:1008-1012）：

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  _processPendingNotificationTask();
  final focused = _processFloatingTabFocusTask();
  if (!focused) _scrollToNow(animated: false);
});
```

`_processFloatingTabFocusTask`（home_page.dart:1047-1065）读 `DesktopFloatingTabController.instance.pendingFocusTaskId`，命中则 `_selectTask`+`_scrollToTask` 并清空。

### 1.2 写入点：restoreFullWindow

desktop_floating_tab_controller.dart:156-168：

```dart
Future<void> restoreFullWindow({String? openTaskId}) async {
  if (openTaskId != null && openTaskId.isNotEmpty) {
    pendingFocusTaskId = openTaskId;
    pendingFocusRequestToken = DateTime.now().microsecondsSinceEpoch;
  }
  ...
  await windowManager.show();
  await windowManager.focus();
  desktopWindowVisible = true;
}
```

便签点击 → `_openMainWindow`（note_window_app.dart:158-166）invoke `'showMain'` → 主窗 `_registerMainWindowChannel` handler（controller:244-251）→ `restoreFullWindow(openTaskId)`。

### 1.3 断点：主窗只是 show，不重建，`_loadData` 不再触发

- **V3 独立便签窗**：main.dart:319-342 恒返回 `HomePage`（删了 V2 的 `DesktopFloatingTaskTab`/`isFloating` 分支）。主窗关闭时 `hideToTray`→`windowManager.hide()`（controller:176-179），点便签后仅 show+focus。`HomePage` State 不销毁、`initState` 不重跑，故 initState 的 postFrame `_loadData`（home_page.dart:816）不会再次执行。
- 归档 research（home-focus-mechanism.md §1.1-1.3）的前提"**restore 时 HomePage 是全新重建的**"是 **V2 同窗互斥切换**时的结论；V3 换独立窗口后该前提**失效**。change_report.md 亦自认"点击定位依赖真实窗口无法无头验证"（line 119），C2 只列人工实测未做。

### 1.4 `_loadData` 其余触发源均不覆盖"窗口 show"

- BlocListener TaskNewLoaded（home_page.dart:1375-1387，节流 2s）—— 需先有 bloc 事件。
- RefreshIndicator、`_onVisibleTabChanged`+`_needsRefresh`（home_page.dart:819-828）—— 与窗口显隐无关。
- `AppLifecycleListener(onResume:_onAppResume)`（home_page.dart:112）→ `_onAppResume`（115-126）→ `_debounceLoadTasks` → `LoadTasks` → TaskNewLoaded → `_loadData`。**这是唯一可能在恢复时触发 `_loadData` 的路径**，但：
  - home_page.dart:116-117 `if (client.auth.currentUser == null) return;` —— **本地登录用户（`LocalAuthenticated`，auth_state.dart:32）无 Supabase session，直接 return**，链路立刻断。
  - 对 Supabase 用户，还需依赖 Windows 引擎在 hide/show 时真的发 lifecycle 变更（window_manager 0.5.1 在 Windows 上 hide→show 是否触发 resumed 未验证），且整条异步链（forcePullAll→syncAll→LoadTasks→2s 节流→_loadData→postFrame）有多个异步 hop，竞态脆弱。

### 1.5 结论

便签定位在 V3 下**大概率完全不触发**（本地用户 100% 断；云端用户依赖未经验证的 AppLifecycle 触发）。修复方向（描述，不改码）：在 `restoreFullWindow` 的 `showMain` handler 或控制器侧直接给一个可被 `_HomeContent` 监听的信号（如控制器 `notifyListeners()` 后由 `_HomeContent` 用 `addPostFrameCallback`/监听器消费 pending 字段），或把消费点从 `_loadData` postFrame 移到窗口恢复事件上；同时把消费点的 `auth.currentUser==null` 门从 `_onAppResume` 中解耦。

---

## 2. defect #2（day/hour 不自动切换）—— 仅"加载/自动选中"路径缺失

### 2.1 现状：用户点击路径已内置自动切换（正确）

`_selectTask`（home_page.dart:1219-1259）：

```dart
if (_modeSwitchGuard) { _scrollToTask(task); return; }          // 1226-1229 手动切模式守卫
if ((_isMultiDayNode(task) || task.isAllDay) && _timelineMode == 'hour') { // 1232 R1
  setState(() => _timelineMode = 'day');
  addPostFrameCallback((_) => _scrollToTask(task));
  return;
}
final isToday = taskDay == today;
if (!isToday && _timelineMode == 'hour') { ... 切 day }         // 1246
else if (isToday && _timelineMode == 'day') { ... 切 hour }      // 1251
else { _scrollToTask(task); }                                    // 1257
```

- `_modeSwitchGuard` 置位/复位只在手动 UI 切模式（`_buildModeChip`，home_page.dart:3510-3544，置 3515 / 复位 3519 postFrame），程序化 `_selectTask` 不受挡。**regression 测试 test_regr_timeline_switch_guard.dart 全部为结构断言（字符串顺序），非运行时行为测试。**

### 2.2 断点：加载路径不调用 `_selectTask`

- `_timelineMode` 初始 = `'hour'`（home_page.dart:750）。
- `_applyProjectFilter`（home_page.dart:1107-1132）无选中时自动 `_selectedTask = _nearestTask(_filteredTasks)`（1128-1131），**只赋值不切模式、不滚动**。
- `_loadData` postFrame（1008-1012）在无 pending 时 `_scrollToNow(animated:false)`——滚到"今天"，不是 nearest 任务。
- hour 模式下 `_timelinePositionForTask` 对非今天任务直接 `return null`（home_page.dart:3591-3592：`if (!_isSameDayDate(task.date, today)) return null;`）。

### 2.3 后果

初始加载或"日历创建任务后切回 tab0"时：nearest 若为**非今天单日任务**，被选中（象限/详情高亮）但 hour 视图里该任务不渲染、且滚到今天——用户感知"没自动切到天视图、看不到该任务"。这与用户描述"任务在今天之外时应该自动切到天视图"完全吻合。

---

## 3. defect #3（四象限点击没定位）—— onTap 正确，但滚动发生在不可见区域

### 3.1 接线正确

`_buildQuadrant.taskItem`（home_page.dart:5397-5401）：

```dart
Widget taskItem(_TimelineTask task) {
  ...
  return GestureDetector(
    onTap: () => _selectTask(task),
    child: Container(...),
  );
}
```

`_selectTask` 会切模式（§2.1）+ `_scrollToTask`（home_page.dart:1164-1191，hour 按 `task.date.hour*_hourWidth`，day 按 `task.date.difference(baseDate).inDays*_dayWidth`，`animateTo` 300ms）。

### 3.2 断点：竖向视口不在时间轴，横向滚动不可见

- 布局：`CustomScrollView > SliverToBoxAdapter > Column`，时间轴在 Column 顶部（home_page.dart:1416 `_buildTimeline()`）、四象限在底部（1420 `_buildQuadrantChart()`），中间还有 taskDetail 等。
- 用户滚到四象限处点击 → `_scrollToTask` 动画确实跑在 `_timelineController`（横向 SingleChildScrollView，home_page.dart:3187）上，但**竖向页面仍停在四象限**，屏幕上看不到时间轴移动。代码中**没有任何一处把外层竖向 `ScrollController` 滚回时间轴**（`_timelineController` 只控制横向）。
- `_HomePageState.build` 用 `IndexedStack`（home_page.dart:531），tab0 恒 mount → 时间轴横向 `Scrollable` 恒挂载 → `_timelineController.hasClients` 恒 true（1165 前置永远通过），所以滚动"照跑但看不见"，不会报错也不会短路。

### 3.3 附加：切模式时的两次动画

`_processPendingNotificationTask`/`_processFloatingTabFocusTask` 里 `_selectTask(task)` 之后**又**同步 `_scrollToTask(task)`（home_page.dart:1041-1042 / 1062-1063）。若 `_selectTask` 已切模式（setState 同步改 `_timelineMode`），紧随的 `_scrollToTask` 用**新模式**算 target，但此时还没 rebuild、横向 maxScrollExtent 还是旧模式，`animateTo` 会被 clamp 到旧边界，随后 postFrame 的 `_scrollToTask` 再滚一次正确位置 → 肉眼两次动画。quadrant 路径只调 `_selectTask`，无此问题。

---

## 4. defect #4（日历创建任务后定位 / "非跨天创建失败"）

### 4.1 定位侧：`_HomeContent` 不消费 bloc 的 focusTaskId（确证）

- `_onCreateTask`（task_bloc.dart:673-762）在 `adjustSnapshot` 里写入 `focusTaskId: taskId` + `focusRequestToken`（757-758），期望下游消费。
- 但 `_HomeContent` 唯一的 `BlocListener<TaskNewBloc>`（home_page.dart:1368-1387）只做：`TaskNewError`→升级弹窗；`TaskNewLoaded`→节流后 `_loadData()`。**不读 `state.focusTaskId`**（归档 research §2.4 已确认）。
- 结果：日历（tab1，home_page.dart:179 `CalendarPage`）创建任务 → `_reloadData`/`_notifyBloc`（calendar_page.dart:801-802）→ 首页 BlocListener 触发 `_loadData`（tab0 不可见时置 `_needsRefresh`，切回时再 `_loadData`，home_page.dart:1376-1379 + 819-828）→ 任务被载入时间轴，但**不被选中、不滚动**。用户"期望定位"落空。

### 4.2 创建侧：链路无"单日/跨天"差异分支（专项排查）

完整链路（全部实读，无分支区分单日/跨天）：

1. `CalendarPage._openCreateTaskFromTimeline`（calendar_page.dart:754-803）：`startDate = day@hour`，`initialDueDateMillis = start+1h`（773-776）；返回 map 后 `CreateTask(projectId: 'inbox' 兜底, startDate/dueDate millis, ...)`（780-799）。
2. `TaskCreateSheet._submit`（task_create_sheet.dart:897-978）：校验 title 非空、start/due 非空、`due.isAfter(start)`（907-910）；随后 **仅单日任务**进入冲突检测（916-959）。
3. `TaskNewBloc._onCreateTask`（task_bloc.dart:673-762）→ `taskRepository.create`（task_repository.dart:386-457）→ drift `TasksCompanion` insert（412-435）→ 本地落库必然成功（配额、DB 异常除外）。
4. 失败兜底：`_runOptimisticTaskChange`（task_bloc.dart:554-582）catch `QuotaExceededException`→`TaskNewError`；其它异常→`restoreRawTasks` 回滚+`TaskNewError`。**均为通用逻辑，与单日/跨天无关。**

**唯一单日专属闸门**：task_create_sheet.dart:917-918 `!TaskConflictService.isRangeMultiDay(finalStart, finalEnd)` 为真才跑 `TaskConflictService.checkConflict`（task_conflict_service.dart:47-65）。命中冲突弹 `showTaskConflictDialog`，选择 `cancel` 或弹窗被关闭（`choice == null`）→ `_submit` `return`（934-956）→ **静默不创建**。`isRangeMultiDay` 只比日历日（task_conflict_service.dart:41-45）。

**便签相关工作未触碰创建链路**（git 实证）：
- a2e44eb 只改 `desktop_floating_task_tab.dart`（+9 行）；
- b411e13 只加测试文件 + 归档；
- 创建链路最近提交为 `5498380`（lazy log 创建）/`4946458`（reopen completed parents），早于便签提交。
- 故"因便签定位功能导致非跨天任务创建不出来"**基本可排除**；更可能是 §4.1 + §2 的组合（创建成功但首页 hour 视图不可见/未定位），或 §4.2 的冲突弹窗取消（单日才触发，恰好符合"只有非跨天失败"的表象）。

### 4.3 "非跨天任务在时间轴上的归属"（defect #5 相关）

- `_isMultiDayNode`（home_page.dart:1087-1092）：`t.endDate == null → false`；否则比 `t.date`(start) 与 `t.endDate` 的日历日。与日历 `_isMultiDayTask`（calendar_page.dart:221-230）判定一致。
- `_TimelineTask.date`（DB 源）= `startDate ?? dueDate ?? now`，`endDate = dueDate`（home_page.dart:901-909）。
  - 单日任务：date=今天/未来某日，endDate=同日 → 非 multi-day。**hour 视图只渲染今天（3592），未来单日任务在 hour 视图不可见；day 视图正常。**
  - 跨天任务（start 今天 23:00 / due 明天 00:00）：`_isMultiDayNode`=true → R1（§2.1）强制 day 视图，day 模式画跨列条（home_page.dart:3626-3640）。
- `_displayTasks`（home_page.dart:1094-1105）按 `_nodeTypeFilters`（parent/child/multiday/singleday）过滤，默认空集=全部；单日任务无被错误归类的分支。

---

## 5. 最小修复改动面建议（描述位置，不写代码）

1. **便签定位（断点 1）**：消费点从 `_loadData` postFrame 移到"窗口恢复"事件。具体：`DesktopFloatingTabController` 暴露 `pendingFocusTaskId` 变更通知（`restoreFullWindow` 写入后 `notifyListeners()`），`_HomeContent` 用 `addPostFrameCallback` 监听并消费（命中 `_selectTask`+`_scrollToTask`，未命中 `_scrollToNow`）；或把 `_onAppResume` 里 `auth.currentUser==null` 的提前 return 与"纯本地刷新"解耦（本地用户也应刷新数据/消费 focus）。
2. **加载自动切换（断点 2）**：`_applyProjectFilter` 自动选中 `_nearestTask` 后，复用 `_selectTask` 的切模式+滚动语义（而非仅赋值）；`_loadData` postFrame 对自动选中任务调用 `_scrollToTask` 而非无条件 `_scrollToNow`。
3. **四象限定位（断点 3）**：`_scrollToTask`（或 `_selectTask` 成功后）先滚动外层竖向 `CustomScrollView` 使时间轴回到可视区，再执行横向 `animateTo`；竖向滚动需一个独立的竖向 `ScrollController`（当前 build 未持有）。同时可去除 `_processPendingNotificationTask`/`_processFloatingTabFocusTask` 中紧随 `_selectTask` 的冗余 `_scrollToTask`（防两次动画）。
4. **创建后定位（断点 4）**：`_HomeContent` BlocListener 读取 `state.focusTaskId`（与 TasksPage 消费一致），命中后 `_selectTask`+`_scrollToTask`；或由日历创建路径向 `DesktopFloatingTabController.pendingFocusTaskId` 写入（复用断点 1 的消费）。
5. **"非跨天创建失败"（断点 5）**：先按 §4.3 复核——大概率非创建失败；若确为冲突弹窗静默取消，建议冲突取消时给明确 SnackBar 提示而非静默 return。

---

## 6. Caveats

- 便签定位断点（§1）的"onResume 在 Windows hide/show 是否触发"未经运行验证；本地用户路径（`auth.currentUser==null`）为代码级必然断点，置信度高。
- §3 的"横向滚动不可见"基于布局实读（时间轴在 Column 顶部、四象限底部）+ IndexedStack 恒挂载；运行期未验证，但逻辑自洽。
- 全部回归测试（test/test_regr_*.dart）为**源文件字符串结构断言**，不覆盖运行时定位/创建行为，因此无法防止上述断点。
- 创建链路与便签提交无重叠（git 实证），"便签导致创建失败"怀疑方向基本排除。
