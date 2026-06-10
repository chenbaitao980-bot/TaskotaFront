# Research: UI 渲染层性能审计（lib/presentation 全量）

- **Query**: 扫描 lib/presentation/ 下全部 pages/blocs/widgets，找出影响用户可感知性能的弱点
- **Scope**: internal
- **Date**: 2026-06-10
- **参照规范**: `.trellis/spec/frontend/quality-guidelines.md`（VLB 局部重建铁律 / O(n²) Set 提取铁律 / SharedPreferences 防抖铁律 / 拖拽开关 ValueNotifier 铁律）

文件规模背景：home_page.dart 4385 行、calendar_page.dart 2931 行、mind_map_view.dart 2115 行、tasks_page.dart 1591 行、task_bloc.dart 1526 行。

---

## 高影响（HIGH）

### H1. 日历周视图：每个 pointerMove 事件触发整页 setState

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:1554-1561`
**类别**: setState 大面积重建（热路径无防抖）

```dart
onPointerMove: (e) {
  if (_isTaskDragging || _editingTaskId != null) {
    _dragSkipped = true;
    return;
  }
  if (_dragStartX == null) return;
  _dragOffset = e.position.dx - _dragStartX!;
  setState(() {});   // ← 每个指针事件全页重建
},
```

**影响**: 高。横向拖动翻周时，120Hz 设备每秒最多 120 次重建 2931 行的 `build()`，且每次重建都执行 H2 的 O(n²) 过滤。是周视图拖动卡顿的最大单点。
**修复**: `_dragOffset` 改 `ValueNotifier<double>`，`Transform.translate`（line 1592）外层包 `ValueListenableBuilder`，其余子树作为 `child` 传入不重建。

### H2. 日历周视图：build 内 `_hasChildren` O(n²) 过滤

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:210-212, 1528-1535`
**类别**: build 内 O(n²) 查找（直接违反 quality-guidelines "Set 提取" 铁律）

```dart
bool _hasChildren(Task task) {
  return _allTasks.any((t) => t.parentId == task.id);   // O(n)
}
// _buildWeekTimeline 内：
final multiDayTasks = tasks
    .where((t) => _isMultiDayTask(t) && ...)   // _isMultiDayTask → _hasChildren → O(n²)
    .toList();
final singleDayTasks = tasks.where((t) => !_isMultiDayTask(t)).toList();  // 再来一次 O(n²)
```

**影响**: 高。每次 build 两次 O(n²)；叠加 H1（每 pointerMove 一次 build），任务数 300+ 时单帧即可超 16ms。`calendar_page.dart:211`（任务详情判断）同源。
**修复**: 在 `_reloadData` 装载 `_allTasks` 时一次性构建 `Set<String> _parentIdSet = _allTasks.map((t)=>t.parentId).whereType<String>().toSet()`，`_hasChildren` 改为 `_parentIdSet.contains(task.id)`。

### H3. 日历任务条拖拽开关用 setState（违反"拖拽开关 ValueNotifier"铁律）

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:1917-1920`（多日条）、`2097-2100`（单日块）
**类别**: setState 大面积重建（拖拽热路径）

```dart
final bar = Listener(
  onPointerDown: (_) => setState(() => _isTaskDragging = true),
  onPointerUp: (_) => setState(() => _isTaskDragging = false),
  onPointerCancel: (_) => setState(() => _isTaskDragging = false),
  child: _EditableMultiDayBar(...),
);
```

**影响**: 高。手指落在任意任务条上（哪怕只是点击）就触发两次全页重建（down+up），每次都跑 H2 的 O(n²)。规范中已有现成的 ValueNotifier<bool> 方案（quality-guidelines.md "拖拽开关用 ValueNotifier<bool> + VLB"）。
**修复**: `_isTaskDragging` 改 `ValueNotifier<bool>`；外层翻周 `Listener.onPointerMove` 直接读 `.value`（无需重建），不再 setState。

### H4. 首页时间轴拖拽：onDragUpdate 每帧 setState 重建 4385 行页面

**文件**: `lib/presentation/pages/home/home_page.dart:2660-2670`（更新）、`2652-2657`（开始）、`2675-2680`（结束）
**类别**: setState 大面积重建（拖拽热路径）

```dart
void _updateTimelineHourDrag(_TimelineTask task, double deltaDx) {
  ...
  _timelineDragRawDx += deltaDx;
  final shift = _clampedHourShift(task, _timelineDragRawDx);
  setState(() {                       // ← 每个 drag delta 全页重建
    _timelineDragDx = shift * _hourWidth;
    _timelineDragHourShift = shift;
  });
}
```

**影响**: 高。拖动一个时间轴节点时，每帧重建整个首页 build()：含 M3 的 `_timelineRenderItems()` 排序+泳道分配、M4 的四象限评分排序、greeting/stats/项目筛选条全部重建。
**修复**: 拖拽偏移量改 `ValueNotifier`，只让被拖 overlay 的 `Positioned`/`Transform` 子树监听；shift 不变时跳过赋值（值相同 VLB 不触发）。

### H5. 首页时间轴横向滚动 listener 触发整页 setState

**文件**: `lib/presentation/pages/home/home_page.dart:740-747`
**类别**: setState 大面积重建（滚动热路径）

```dart
_timelineController = ScrollController()
  ..addListener(() {
    _timelineScrollDebounce?.cancel();
    _timelineScrollDebounce = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() {});   // ← 滚动停顿后全页重建
    });
  });
```

**影响**: 高（持续滚动时每 120ms 一次全页重建；重建包含 M3/M4 全部重算）。其目的只是重算 `_timelineHeight()`（依赖可见区 lane 数）。
**修复**: 把时间轴高度计算改为 `ValueNotifier<double>`，仅时间轴 `SizedBox` 子树监听；或高度直接取全量 lane 最大值，去掉滚动重算。

### H6. 首页时间轴双指缩放：onScaleUpdate 每帧 setState 全页重建

**文件**: `lib/presentation/pages/home/home_page.dart:1987-1997`；日历同款 `calendar_page.dart:355`
**类别**: setState 大面积重建（手势热路径）

```dart
onScaleUpdate: (details) {
  if (details.pointerCount < 2) return;
  setState(() {
    _hourWidth = ((_scaleStartHourWidth ?? _hourWidth) * details.scale)
        .clamp(_hourWidthMin, _hourWidthMax);
  });
  _syncHourWidth();
}
```

**影响**: 高（缩放手势每帧触发，重建全页 + M3/M4 重算）。日历 `_hourHeight`（line 355 `setState(() => _hourHeight = nextHeight)`）同理，叠加 H2 的 O(n²) 更严重。
**修复**: `_hourWidth`/`_hourHeight` 改 `ValueNotifier<double>`，只包时间轴/周视图网格子树；网络同步已有 800ms 防抖（line 1057）可保留。

### H7. TaskListView：ListView 全量 children + O(n²) 树构建，每次 build 重算

**文件**: `lib/presentation/pages/tasks/widgets/task_list_view.dart:129-143, 61-118`
**类别**: 非懒加载列表 + build 内 O(n²) + 无缓存重算

```dart
return ListView(                       // ← 非 .builder，全量构建
  children: [
    ...,
    ..._buildTreeNodes(pendingTasks),  // 每次 build 调 _buildFlatTree
  ],
);
// _addNode 内（对每个节点执行）：
final children = allTasks.where((t) => t.parentId == task.id).toList()
  ..sort(...);                         // O(n) per node → 整树 O(n²)
```

**影响**: 高。任务主列表是核心页面；TaskNewBloc 任意 emission（含 M5 的无 buildWhen）都重建。500 任务 ≈ 25 万次比较 + 500 个 TaskCard 全量实例化，列表页打开/勾选/展开均可感知。
**修复**: ① 一次遍历建 `Map<String?, List<Task>> childrenByParent` 再 DFS（O(n log n)）；② 扁平结果用 `ListView.builder(itemCount: flat.length)` 懒加载；③ 扁平树结果可按 (tasks identity, expandedIds) 缓存。

---

## 中影响（MEDIUM）

### M1. TableCalendar eventLoader：每个日历格子全量过滤任务

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:1066-1067`
**类别**: build 内重复计算无缓存

```dart
eventLoader: (day) =>
    tasks.where((t) => _taskOverlapsDay(t, day)).toList(),
```

**影响**: 中。月视图 42 个格子 × O(n) = 每次 build O(42n)，每次 `setState`（选中日期、切月）都重跑。
**修复**: build 前按天分桶 `Map<DateTime, List<Task>>`，eventLoader 改 O(1) 查表。

### M2. 周视图日期条：每天一次 `tasks.any` 全量扫描

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:1367`
**类别**: build 内重复计算

```dart
final hasTasks = tasks.any((t) => _taskOverlapsDay(t, day));
```

**影响**: 中。O(days×n) 每 build；叠加 H1 每 pointerMove 重跑。
**修复**: 同 M1，分桶后查表。

### M3. 首页 `_timelineRenderItems` / `_displayTasks`：每次 build 排序+泳道分配+多次过滤

**文件**: `lib/presentation/pages/home/home_page.dart:2352-2385`（排序+泳道）、`1005-1016`（getter 过滤）
**类别**: build 内重计算无缓存

```dart
List<_TimelineTask> get _displayTasks {        // getter，每次访问重新 where+toList
  if (_nodeTypeFilters.isEmpty) return _filteredTasks;
  return _filteredTasks.where((t) { ... }).toList();
}
// _timelineRenderItems()：每 build 全量 sort + 贪心泳道分配
rawItems.sort((a, b) { ... });
```

**影响**: 中（与 H4/H5/H6 叠加后实际为高）。`_displayTasks` 在单次 build 中被访问多达 4 处（line 1352/2359/2702-2786/4063），每次都重新分配 List。
**修复**: `_displayTasks` 与 render items 结果缓存为字段，仅在 `_applyProjectFilter`/筛选变化/数据加载时重算。

### M4. 首页四象限：每次 build 重新评分+排序+分桶

**文件**: `lib/presentation/pages/home/home_page.dart:4059-4087`
**类别**: build 内重计算无缓存

```dart
Widget _buildQuadrantChart() {
  final scored = <_TimelineTask, int>{};
  for (final t in _displayTasks) { ... scored[t] = p * 2 + u; }
  final sorted = scored.keys.toList()
    ..sort((a, b) => scored[b]!.compareTo(scored[a]!));
  ...
}
```

**影响**: 中。本身 O(n log n) 不大，但位于首页 build 末端，被 H4/H5/H6 的每帧 setState 连带执行。另 line 4103 `GoogleFonts.interTextTheme()` 每 build 新建 TextTheme。
**修复**: 四象限数据在 `_loadData`/筛选变化时预计算；该区块抽成独立 widget + RepaintBoundary，不随拖拽/滚动重建。

### M5. tasks_page BlocConsumer 无 buildWhen，任意状态变化重建整个任务页

**文件**: `lib/presentation/pages/tasks/tasks_page.dart:111`；另 `login_page.dart`、`register_page.dart` 各 1 处（影响小）
**类别**: BlocBuilder 无 buildWhen

```dart
return BlocConsumer<TaskNewBloc, TaskNewState>(
  listener: ...,
  builder: (context, state) { ... }   // 无 buildWhen
);
```

**影响**: 中。TaskNewBloc 是全 App 共享 bloc（首页 BlocListener、日历 BlocListener 都挂着它），勾选/进度/checklist 等任何 emission 都触发任务页 Scaffold + MindMapView/TaskListView（H7）整体重建。
**修复**: 增加 `buildWhen`：仅 `TaskNewLoaded` 且 tasks/projects/viewMode/expandedNodes/筛选字段变化时重建（state 已是 Equatable 可比较字段）。

### M6. task_bloc：O(n²) 计算 allParentIds（规范铁律的原版反例代码仍在线上）

**文件**: `lib/presentation/blocs/task_new/task_bloc.dart:421-425, 1232-1235`
**类别**: O(n²) 查找（quality-guidelines 中所举 ❌ 反例与此代码逐字相同）

```dart
final allParentIds = tasks
    .where((t) => tasks.any((c) => c.parentId == t.id))   // O(n²)
    .map((t) => t.id)
    .toSet();
```

**影响**: 中。在 `LoadTasks`（每次进任务页/勾选后刷新）与 `ExpandAllTasks` 中各一处；虽在 bloc 异步路径不直接掉帧，但加大 emission 延迟，用户感知"点完等一下"。
**修复**: 按规范改 Set：`final parentIdSet = tasks.map((t)=>t.parentId).whereType<String>().toSet(); tasks.where((t)=>parentIdSet.contains(t.id))`。

### M7. task_bloc `_findRootId`：subTrees 嵌套 any 双重遍历

**文件**: `lib/presentation/blocs/task_new/task_bloc.dart:1098-1112`
**类别**: O(n²) 查找

```dart
for (final entry in loaded.subTrees.entries) {
  if (entry.key == taskId || entry.value.any((t) => t.id == taskId)) {
    for (final rootKey in loaded.subTrees.keys) {
      ...
      if (tree.any((t) => t.id == taskId)) return rootKey;   // 外层命中后又全量再扫一遍
    }
  }
}
```

**影响**: 中低。逻辑上外层命中 entry 后理应直接 `return entry.key`，现写法多一轮全 map 扫描。
**修复**: 命中即 `return entry.key`；或维护 `taskId → rootId` 反查 Map。

### M8. 子任务树 Section：每节点 where + any 递归 O(n²)

**文件**: `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart:156-185`
**类别**: build 内 O(n²)

```dart
final children = allTasks.where((t) => t.parentId == parentId).toList();
...
for (final child in children) {
  final hasChildren = allTasks.any((t) => t.parentId == child.id);  // O(n) per node
```

**影响**: 中。任务详情页打开时执行；有 buildWhen（好），但深树+多任务时首开有感。
**修复**: 进入 build 前建 `childrenByParent` Map 一次，递归只查表。

### M9. 首页时间轴：Stack 内全部列+全部任务 overlay 非懒加载

**文件**: `lib/presentation/pages/home/home_page.dart:2005-2024`
**类别**: 非懒加载（SingleChildScrollView + 全量 Stack）

```dart
child: SingleChildScrollView(
  controller: _timelineController,
  scrollDirection: Axis.horizontal,
  child: SizedBox(
    width: timelineWidth,
    child: Stack(children: [
      for (var i = 0; i < itemCount; i++) Positioned(... child: itemBuilder(ctx, i)),
      ..._buildTimelineTaskOverlays(),       // 全部任务 overlay 一次性构建
    ]),
  ),
),
```

**影响**: 中。day 模式 `totalDays`（_daysBefore+_daysAfter）列 + 全部任务 overlay（每个带 BoxShadow，line 2529/2890）全部常驻 widget 树；滚动只移动视口但每次 setState 全部重建。
**修复**: 不强求改 builder（Stack overlay 依赖绝对定位），但应：① overlay 列表缓存（M3）；② 整个时间轴包 RepaintBoundary；③ 视口外 overlay 可裁剪不构建。

### M10. 日历多日泳道：每次 build DFS 递归 where + 双重排序

**文件**: `lib/presentation/pages/calendar/calendar_page.dart:1744-1779`
**类别**: build 内重计算 + 递归 where（O(n²)）

```dart
List<Task> dfsChildren(List<Task> allChildren, String parentId) {
  final direct = allChildren.where((t) => t.parentId == parentId).toList()
    ..sort(...);                          // 每层 where 全扫
  ...
}
final sortedRootIds = rootById.keys.toList()..sort(...);
```

**影响**: 中。位于 `_buildMultiDayLane`，随 H1/H3 的每事件 build 重跑。
**修复**: 同 M8 分桶；排序结果随 `_allTasks` 版本缓存。

---

## 低影响（LOW）

### L1. 首页任务详情卡子任务行：每行 `_timelineTasks.where().firstOrNull`

**文件**: `lib/presentation/pages/home/home_page.dart:3673-3676`
**类别**: build 内 O(n×m) 查找

```dart
...subtasks.map((st) {
  final tlTask = _timelineTasks.where((t) => t.taskId == st.id).firstOrNull;
```

**影响**: 低（仅选中任务的直接子任务，m 小；但 _timelineTasks 可能很大）。
**修复**: `_loadData` 时建 `Map<String, _TimelineTask> byTaskId`。

### L2. project_sidebar：ListView 非 builder + build 内分桶排序

**文件**: `lib/presentation/pages/tasks/widgets/project_sidebar.dart:250-275`
**类别**: 非懒加载 + build 内排序

**影响**: 低（项目数通常 <50；Drawer 打开才 build）。
**修复**: 项目数大后改 ListView.builder；分桶结果可由 bloc 提供。

### L3. checklist_section：ReorderableListView shrinkWrap + 全量 children

**文件**: `lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart:96-110`
**类别**: shrinkWrap 全量构建

**影响**: 低（有 maxHeight 约束，checklist 条目少）。条目超 ~50 时改 `ReorderableListView.builder`。

### L4. task_create_sheet：build 内多处 `.any()` / `.where()` 过滤项目与父任务

**文件**: `lib/presentation/pages/tasks/widgets/task_create_sheet.dart:441-445, 466, 626-636`
**类别**: build 内查找

**影响**: 低（项目/父任务候选数小，sheet 内 setState 范围 1165 行偏大但交互频率低）。`availableParentTasks` 很大时 `_buildParentPicker` 的 where+any 才会显形。

### L5. 时间轴/日历任务块每个都带 BoxShadow

**文件**: `lib/presentation/pages/home/home_page.dart:2529-2533, 2890-2894`
**类别**: 滚动内容逐项 shadow

**影响**: 低（blurRadius 4-8 小；Impeller 下成本可控）。数量大时可改用预渲染描边/纯色边框。

### L6. tasks_page `_handleToggleTaskStatus` 中 `state.tasks.any`

**文件**: `lib/presentation/pages/tasks/tasks_page.dart:682`
**类别**: O(n) 查找，但在点击回调内非 build 热路径。

**影响**: 低。可与 M6 的 parentIdSet 一并由 state 提供。

---

## 合规确认（未发现问题的检查项）

- **mind_map_view.dart**: 已按规范实现 — 连线层 `AnimatedBuilder` 只包 `CustomPaint`（line 852-873），节点独立 VLB，`_nodeDragging` 为 ValueNotifier（line 94），SharedPreferences 写入 300ms 防抖（line 310-312），notifier 全部 dispose（line 199-208）。✅
- **dispose 泄漏**: 抽查 home_page（4 个 StreamSubscription + 6 个 Timer，line 134-145 全部 cancel）、calendar long-press Timer（line 2312）、vip_page `_pollSub`/`_countdownTimer`（line 360-362）、attachment_section `_syncSub`（line 53-55）、tasks_page 搜索 `_debounce`（line 1588）均正确释放。✅ 未发现泄漏。
- **搜索输入**: tasks_page SearchDelegate 已做 300ms 防抖（line 1516）。✅
- **MediaQuery**: home_page 5 处均在点击回调内而非 build 热路径。✅
- **BackdropFilter / saveLayer**: 全 presentation 层无使用。✅
- **profile/onboarding 等静态页 `ListView(children:)`**: 条目固定且少，无需 builder。✅

---

## 汇总表（按影响排序）

| # | 影响 | 文件:行 | 类别 | 问题 | 触发场景 |
|---|------|---------|------|------|----------|
| H1 | 高 | calendar_page.dart:1554-1561 | setState 热路径 | pointerMove 每事件全页 setState | 周视图横向拖动翻周 |
| H2 | 高 | calendar_page.dart:210-212, 1528-1535 | O(n²) | `_hasChildren` any 嵌套于 where 过滤 | 周视图每次 build |
| H3 | 高 | calendar_page.dart:1917-1920, 2097-2100 | setState 热路径 | `_isTaskDragging` 用 setState（违反铁律） | 触摸任意任务条 |
| H4 | 高 | home_page.dart:2660-2670 | setState 热路径 | 时间轴拖拽每帧重建 4385 行页面 | 拖动时间轴节点 |
| H5 | 高 | home_page.dart:740-747 | setState 热路径 | 滚动 listener 整页 setState | 时间轴横向滚动 |
| H6 | 高 | home_page.dart:1987-1997; calendar_page.dart:355 | setState 热路径 | 双指缩放每帧整页重建 | 缩放时间轴/周视图 |
| H7 | 高 | task_list_view.dart:61-143 | 非懒加载+O(n²) | ListView 全量 children + 每节点 where 建树 | 任务列表任意刷新 |
| M1 | 中 | calendar_page.dart:1066-1067 | 重复计算 | eventLoader 每格子全量过滤 | 月视图任意 setState |
| M2 | 中 | calendar_page.dart:1367 | 重复计算 | 日期条每天 tasks.any | 周视图每次 build |
| M3 | 中 | home_page.dart:1005-1016, 2352-2385 | 重复计算 | `_displayTasks` getter ×4 + 排序泳道每 build | 首页任意重建 |
| M4 | 中 | home_page.dart:4059-4087 | 重复计算 | 四象限评分排序每 build | 首页任意重建 |
| M5 | 中 | tasks_page.dart:111 | 无 buildWhen | BlocConsumer 任意 emission 重建任务页 | 任意 TaskNew 状态变化 |
| M6 | 中 | task_bloc.dart:421-425, 1232-1235 | O(n²) | allParentIds 嵌套 any（规范反例原版） | LoadTasks / 全部展开 |
| M7 | 中 | task_bloc.dart:1098-1112 | O(n²) | `_findRootId` 命中后重复全扫 | 子树展开/折叠 |
| M8 | 中 | subtask_tree_section.dart:156-185 | O(n²) | 每节点 where+any 递归建树 | 任务详情页打开 |
| M9 | 中 | home_page.dart:2005-2024 | 非懒加载 | 时间轴全列+全 overlay 常驻构建 | 首页每次 build |
| M10 | 中 | calendar_page.dart:1744-1779 | O(n²) | 多日泳道 DFS 递归 where | 周视图每次 build |
| L1 | 低 | home_page.dart:3673-3676 | O(n×m) | 子任务行全量 where | 详情卡展开 |
| L2 | 低 | project_sidebar.dart:250-275 | 非懒加载 | ListView 非 builder + build 内排序 | 打开侧边栏 |
| L3 | 低 | checklist_section.dart:96-110 | shrinkWrap | ReorderableListView 全量 children | 详情页 checklist |
| L4 | 低 | task_create_sheet.dart:441-636 | build 内查找 | 多处 any/where 过滤候选 | 新建任务 sheet |
| L5 | 低 | home_page.dart:2529, 2890 | shadow | 每个时间轴块 BoxShadow | 时间轴滚动 |
| L6 | 低 | tasks_page.dart:682 | O(n) 回调 | 勾选时 tasks.any | 点击完成 |

## 修复优先级建议

1. **第一批（日历可感卡顿）**: H1 + H2 + H3 + M2 + M10 — 同一页面同一热路径，一次重构（_parentIdSet + _dragOffset/_isTaskDragging 改 VLB）收益最大。
2. **第二批（首页拖拽/滚动/缩放）**: H4 + H5 + H6 + M3 + M4 — 核心是把拖拽偏移、滚动高度、hourWidth 三个状态 VLB 化 + render items 缓存。
3. **第三批（任务列表）**: H7 + M5 + M6 — childrenByParent 分桶 + ListView.builder + buildWhen。
4. 其余 M/L 项随顺手修复。

## Caveats / Not Found

- 本审计为静态扫描，未跑 DevTools profile 实测帧耗时；O(n²) 项的实际影响与用户任务量正相关。
- `task_bloc.dart` 文件含 GBK/乱码注释（如 line 418"榛樿灞曞紑"），不影响审计结论但说明该文件曾被错误编码写入。
- 未审计 lib/presentation 之外的渲染相关代码（如 main.dart 的 theme 重建、路由动画）。
