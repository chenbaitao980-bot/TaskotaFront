# Research: 便签点击定位任务 — 时间轴维度自动对应 + 四象限对应规则

- **Query**: 桌面便签点击 → 首页定位任务时，时间轴（跨天→day 维度，小时任务→hour 维度）与四象限都要对应上的精确规则
- **Scope**: internal（仅本项目代码）
- **Date**: 2026-08-03

## 结论摘要

现有 `_selectTask` 已经实现了大部分时间轴维度切换，但**判定基准是"`task.date` 是否今天"，完全不区分跨天任务**。便签点击当前走 `_openTaskDetail` 直接 push 详情页，**完全没进首页的 `_selectTask`**，首页收不到便签任务。四象限 item **没有选中高亮**（`_selectedTaskId` 在象限中完全未使用）。需要新增：便签任务注入首页 → `_selectTask`（时间轴维度切换已具备）→ 象限高亮样式。

---

## 1. 跨天判定依据（file:line）

| 位置 | 判定逻辑 | 是否用 isAllDay |
|---|---|---|
| `home_page.dart:1063-1068` `_isMultiDayNode(_TimelineTask t)` | `endDate != null` 且 `date` 与 `endDate` 的 年/月/日 不相等 → 跨天。**无 `isAllDay`** | 否 |
| `calendar_page.dart:221-230` `_isMultiDayTask(Task)` | 有子任务的父任务**无条件**当跨天长条；否则 `startDate`/`dueDate` 不同日历日 | 否 |
| `calendar_page.dart:1629-1635` | `multiDayTasks = tasks.where(_isMultiDayTask && 与本周重叠)` | — |
| `multi_day_task_list_page.dart:104-110` `_taskDays` | `(dueDate - startDate)/86400000` ceil，仅算"天数跨度"，不做判定 | — |

**关键事实**：
- DB `Task.isAllDay`（`app_database.g.dart:1109`）字段存在，但**首页与日历页判定跨天都不用它**；首页转 `_TimelineTask` 时（`home_page.dart:900-924`）**直接把 isAllDay 丢弃**，`_TimelineTask` 类里没有该字段。
- 跨天判定**唯一依据** = `date`(startDate) 与 `endDate`(dueDate) 是否为不同日历日（`_isMultiDayNode`）。同一日历日内的"全天"任务不算跨天。
- 仅 `home_page.dart:4891`（子任务列表复写 Task 对象）引用 `isAllDay`，与定位逻辑无关。

## 2. `_TimelineTask` 字段表

定义于 `home_page.dart:5475-5501`。

| 字段 | 类型 | 来源/含义 |
|---|---|---|
| `id` | String | 用于选中比对（`== _selectedTaskId`）。DB 任务 = DB task id；storage 任务 = TaskBreakdown id |
| `title` | String | 标题 |
| `description` | String? | 描述 |
| `date` | DateTime | **定位锚点**。DB：`startDate ?? dueDate ?? now`（`home_page.dart:901-905`）；storage：`startDate ?? endDate ?? now`（`881`）。跨天任务落在此 = startDate 那天 |
| `endDate` | DateTime? | DB = `dueDate`（`906-908`）；storage = `endDate`。用于跨天判定与长条渲染 |
| `isCompleted` | bool | DB `status == 2` |
| `priority` | String | DB 经 `_dbPriorityToLabel`（`1229-1240`）：5→P0,3→P1,1→P2,其他→P3 |
| `source` | String | 'storage' / 'db' |
| `projectId` | String? | 项目筛选用 |
| `taskId` | String | = DB task id（与 `id` 相同），`_processPendingNotificationTask` 用它匹配（`1032`） |
| `parentId` | String? | 父子关系 |

## 3. `_selectTask` / `_scrollToTask` 现有逻辑与边界表

### 现有逻辑（home_page.dart:1195-1226 `_selectTask`）

```dart
isToday = (task.date 的日历日 == 今天)
if (_modeSwitchGuard) { _scrollToTask(task); return; }   // 用户手动切模式时跳过自动切换
if (!isToday && _timelineMode=='hour')   → setState(_timelineMode='day');  postFrame _scrollToTask
else if (isToday && _timelineMode=='day') → setState(_timelineMode='hour'); postFrame _scrollToTask
else → _scrollToTask(task)
```

- `_modeSwitchGuard` 只在 `_buildModeChip`（`3476-3510`）用户手动点击小时/天切换时置 true（`3481`），postFrame 后置回 false（`3485`）。`_selectTask` 不修改它。

### `_scrollToTask`（home_page.dart:1140-1167）

- hour 分支（`1146-1154`）：任务不在今天 → 跳到 `12*_hourWidth`（中午，占位）；在今天 → 跳到 `task.date.hour*_hourWidth`，再减去半屏居中。
- day 分支（`1155-1160`）：`baseDate = today - 180天`；`dayOffset = task.date.difference(baseDate).inDays * _dayWidth(=72)`；居中。**用 `task.date`（startDate），不是 endDate**。只对下限 `max(0.0, target)` 做钳制。
- 天窗常量（`724/726/730-731`）：`_dayWidth=72`，`_hourWidth 默认120(可拖60~300)`，`_daysBefore=180`，`_daysAfter=180` → day 模式共 361 天窗口。

### 维度切换边界表

| 任务场景 | 当前 hour 模式 | 当前 day 模式 | 当前逻辑评价 |
|---|---|---|---|
| 非今天、单日（含过去、3天后、2周后） | **切 day** + 滚到该日（`!isToday` 成立） | 保持 day + 滚到该日 | 正确，符合"非今天→day" |
| 今天、单日（小时任务） | 保持 hour + 滚到该小时 | **切 hour** + 滚到该小时 | 正确，符合"今天→hour" |
| 跨天任务、start **在 3 天后** | **切 day** + 滚到 start 那天（bar 渲染跨日） | 保持 day + 滚到 start 那天 | 正确（`!isToday` 成立） |
| 跨天任务、start **在今天**（如今天→明天） | **保持 hour**（`isToday` 成立，不切） | 保持 day（`isToday` 成立，只在 day 时切 hour → 会切成 hour！） | **不符合"跨天→day"**：按当前代码，跨天且 start 今天的任务会被推进 hour 维度，只显示 start 时刻的圆点而非跨天长条 |
| 跨天任务、start 在过去但 end 在未来（如本周周一→周日） | 切 day + 滚到 start（过去某天） | 保持 day + 滚到 start | 功能正确，滚动落在 start 而非 end |
| 任务在 180 天以前 | 切 day；`dayIndex<0` 不渲染，滚动目标负数被钳到 0（最左） | 同左 | 边界：天窗外的过去任务无法定位到具体日 |
| 任务在 180 天以后 | 切 day；`dayIndex>=totalDays` 不渲染，滚动目标超过 maxScrollExtent | 同左 | 边界：天窗外未来任务无法定位 |

> 注：任务是否今天，判定用 `task.date`（startDate）。跨天任务 start 今天时 `isToday=true`，这是当前逻辑与"跨天→day"需求的**唯一冲突点**。

## 4. 四象限现状

### 数据与分类（home_page.dart:5246-5274 `_buildQuadrantChart`）

- 输入 = `_displayTasks`（**已剔除完成项** `if (t.isCompleted) continue`，`5251`）。
- 排序分 `p*2 + u`：`u = inDays<0?10 : <=3?5 : <=7?2 : <=30?0 : -2`（`5254-5263`）。
- 分桶（`5270-5273`）：`urgent = date.difference(now).inDays <= 3`；`important = priority=='P0' || 'P1'`。q1紧急重要 / q2重要不紧急 / q3紧急不重要 / q4不重要不紧急。

### 每格渲染（home_page.dart:5348-5468 `_buildQuadrant`）

- **无选中/高亮态**：`taskItem`（`5363-5410`）只画"逾期图标 或 优先级圆点 + 标题"，**完全未引用 `_selectedTaskId` / `_selectedTask`**。
- **横向**：`SingleChildScrollView(scrollDirection: horizontal)`（`5441`），每列宽 120，`maxPerColumn=5`（`5352`）块状分列；第 6 个任务起进第 2 列（需横向滚动才可见），**无 ScrollController，无法编程滚动定位**。
- **纵向**：不分页滚动，超 5 个换列（同 5358-5361）。
- **选中视觉**：时间轴 overlay 已有（`_buildTimelinePoint` 放大+主色描边+辉光 `3688-3711`；`_buildTimelineArrowBar` 主色边框 `3739-3744`；day 条同理 `4038-4067`），**象限没有**。

### 同屏关系

- 首页整体是 `CustomScrollView` + 单个 `SliverToBoxAdapter` + Column（`home_page.dart:1361-1393`），顺序：问候/统计 → 项目筛选 → lazy log 面板 → **`_buildTimeline()`** →（选中时）**`_buildTaskDetail()`** → **`_buildQuadrantChart()`**。
- 时间轴与四象限**同页同 Column**，但纵向相隔很远：选中后详情面板夹在中间。**"对应"意味着：时间轴滚动到任务 + 象限高亮该项**；页面本身不自动滚动去露象限，象限不保证视口可见（用户需下拉）。
- 由于 `_applyProjectFilter`（`1099-1107`）与 `_loadData` 完成后会把 `_selectedTaskId` 自动设为"最近任务"（`_nearestTask`，`1104-1107`），时间轴默认就高亮最近任务；象限若加高亮也会默认高亮同一任务，行为一致。

## 5. 便签点击现状（接线缺口）

- 便签 `DesktopFloatingTaskTab.onTap` → `DesktopFloatingTabController.restoreFullWindow(openTaskId)`（`main.dart:313-321`）→ `_openTaskDetail(taskId)`（`desktop_floating_tab_controller.dart:288-306`）→ `pushNamedAndRemoveUntil('/')` 回首页，100ms 后 **直接 push 数据库版 TaskDetailPage**。
- 首页定位机制 `_processPendingNotificationTask`（`home_page.dart:1013-1041`）只读 `NotificationService.pendingTaskId`（`1021`），**便签没走这条路** → 首页全新实例 `_selectedTaskId` 为 null（除非被 `_applyProjectFilter` 自动选了最近任务），时间轴/象限都不对应。
- 可行接线：复用 `NotificationService.pendingTaskId` 静态变量（在 `restoreFullWindow`/`_openTaskDetail` 里 set 后导航回首页），首页 postFrame 即自动 `_selectTask` + `_scrollToTask`（`1038-1039`）。便签 taskId 是 DB 任务 id，`_processPendingNotificationTask` 用 `t.id == taskId || t.taskId == taskId`（`1032`）可命中。

## 6. 推荐的"对应"实现规则集

> 以"在 `_selectTask` 中统一实现"为准；便签/通知共用此入口。不破坏 `_modeSwitchGuard`：守卫命中时保持现行为（只 `_scrollToTask`，不自动切维度）。

**R1 跨天优先 → day**：在 `isToday` 判断**之前**检查 `_isMultiDayNode(task)`（`home_page.dart:1063`）。若跨天且当前是 hour 模式 → 切 day（修复第 3 节"跨天 start 今天"被推进 hour 的缺陷）。切完滚动锚点用 `task.date`（start），与 day 渲染 bar 的 `startIndex`（`3597`）一致。

**R2 非今天单日 → day**：`!isToday && hour` → 切 day（现逻辑保留）。

**R3 今天单日/小时任务 → hour**：`isToday && !_isMultiDayNode && day` → 切 hour（现逻辑保留）；hour 模式滚动到 `task.date.hour`。

**R4 统一滚动**：切换维度用 `WidgetsBinding.instance.addPostFrameCallback` 后 `_scrollToTask`（现模式，`1215-1217/1220-1222`）；不切换直接 `_scrollToTask`。

**R5 象限高亮**：
- 前提：任务必须存在于 `_displayTasks`（未被项目/完成/节点类型筛选剔除）。若被筛掉，象限里没有该项 → 建议 `_processPendingNotificationTask`/定位前先校验 `_displayTasks.any((t)=>t.id==task.id)`，或提示用户清筛选。
- 在 `_buildQuadrant.taskItem`（`5363`）加 `final isSelected = task.id == _selectedTaskId;`，给整行包一层高亮容器（参考时间轴：主色描边 `AppTheme.primaryColor` border + 轻微辉光；或加呼吸动画 AnimatedContainer）。**样式目前不存在，需新增**。
- 可见性：item 在第 1 列（前 5 个）内天然可见；若落后续列需横向滚动——象限目前无 ScrollController。最小改动先做高亮；若要求"必见"，再给每个象限格加横向 `ScrollController` 并 `jumpTo(index*122)`。

**R6 守卫语义不变**：所有自动维度切换只在 `_modeSwitchGuard == false` 时发生（现 `1202-1205` 已保证）；手动模式芯片点击仍只滚动不切（现行为）。

**R7 边界声明**：180 天窗外的任务无法在 day 维度渲染/精确滚动（`dayIndex` 越界，`3608-3609`），属已知边界；hour 模式下跨天任务非今天不渲染（`3557-3558`），所以跨天必须靠 day 维度呈现——这正是 R1 的必要性。

## Caveats / Not Found

- **未找到**：便签→首页的任何现成 taskId 注入机制（只有 `NotificationService.pendingTaskId` 一条通道，便签未用）。这是实现前必须先接的线。
- **未找到**：四象限任何选中/高亮代码（需新增）。
- **风险**：`_applyProjectFilter` 在数据重载时会把 `_selectedTaskId` 重置为 `_nearestTask`（`1099-1107`），若定位动作与重载并发，选中态可能被覆盖。
- 跨天判定全程不读 `isAllDay`；若需求要求"全天任务必进 day"，单靠 `_isMultiDayNode` 不够（同日全天任务不跨天），需在 `_TimelineTask` 上补一个 isAllDay 字段并在 `_loadData`（`900-924`）带出来——当前未实现。
