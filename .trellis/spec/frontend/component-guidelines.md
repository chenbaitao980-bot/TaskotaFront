# Component Guidelines

> How components are built in this project.

---

## Overview

<!--
Document your project's component conventions here.

Questions to answer:
- What component patterns do you use?
- How are props defined?
- How do you handle composition?
- What accessibility standards apply?
-->

(To be filled by the team)

---

## Component Structure

<!-- Standard structure of a component file -->

(To be filled by the team)

---

## Props Conventions

<!-- How props should be defined and typed -->

(To be filled by the team)

---

## Styling Patterns

<!-- How styles are applied (CSS modules, styled-components, Tailwind, etc.) -->

(To be filled by the team)

---

## Accessibility

<!-- A11y requirements and patterns -->

(To be filled by the team)

---

## Common Mistakes

### 在 `initState` 加载异步数据后，`didUpdateWidget` 未重新加载

**Symptom**: 当父 widget 更新 props（如 filter、projectId）导致子 widget 重建内部状态时，子 widget 使用 `initState` 中加载的异步数据（如 `SharedPreferences`），但切换回来后数据消失或变为默认值。

**Cause**: `initState` 只在 widget 首次插入 widget tree 时调用一次。`didUpdateWidget` 在 props 变化时调用，但开发者容易忘记在其中重新执行 `initState` 中的异步加载逻辑。

```dart
// ❌ 错误：异步数据只在 initState 加载，didUpdateWidget 不重新加载
@override
void initState() {
  super.initState();
  _computeLayoutCache();
  _loadOffsets(); // ← 只执行一次
}

@override
void didUpdateWidget(Widget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.tasks != widget.tasks) {
    _computeLayoutCache();
    // ← 忘记重新加载 offsets
  }
}
```

**Fix**: 在 `didUpdateWidget` 中，当相关 props 变化时，重新加载异步数据。

```dart
// ✅ 正确：didUpdateWidget 中重新加载
@override
void didUpdateWidget(Widget oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.tasks != widget.tasks ||
      oldWidget.expandedIds != widget.expandedIds) {
    _computeLayoutCache();
    _reloadOffsets(); // ← didUpdateWidget 中也重新加载
  }
}
```

**Prevention**:
- 每当在 `initState` 中加载异步数据（SharedPreferences、API、数据库），问自己："这个数据在 props 变化后需要重新加载吗？"
- 为 reload 逻辑单独提取一个方法（如 `_reloadOffsets`），与 `initState` 中的初次加载区分
- 区分 "首次加载" 逻辑（含 setState / 焦点导航等副作用）和 "重新加载" 逻辑（仅更新数据，无副作用）

---

### 自由拖拽位置缓存在父子关系变更时未清除

**Symptom**: 思维导图中将节点拖入另一节点建立父子关系后，被移动节点仍停在旧的自由拖拽坐标处，不受新的自动布局控制。

**Cause**: `_draggedIds` 标记该节点为"已手动拖拽"，`_reloadOffsets()` 从 SharedPreferences 重新加载旧坐标并恢复该标记，导致 `_syncNotifiersToLayout()` 的新布局坐标被覆盖。

**Fix**: 使用"待重置集合"模式：在父子关系变更时记录需要重置的节点，并在下次布局加载时跳过其 SharedPreferences 缓存。

```dart
// 在 State 中添加：
final Set<String> _pendingLayoutResetIds = {};

// 代理 onMoveToParent 回调：
void _handleMoveToParent(String taskId, String? newParentId) {
  _pendingLayoutResetIds.add(taskId);
  _draggedIds.remove(taskId);             // 让 _syncNotifiersToLayout 立即生效
  widget.onMoveToParent(taskId, newParentId);
}

// 在 didUpdateWidget 中：
if (_pendingLayoutResetIds.isNotEmpty) {
  // 展开到完整子树（用新的 widget.tasks）
  final expanded = <String>{};
  for (final id in _pendingLayoutResetIds) {
    expanded.addAll(_collectSubtreeIds(id, widget.tasks));
  }
  _pendingLayoutResetIds..clear()..addAll(expanded);
  _draggedIds.removeAll(_pendingLayoutResetIds);   // 子树一并从 _draggedIds 移除
}
_computeLayoutCache();  // _syncNotifiersToLayout 此时已拿到正确坐标
_reloadOffsets().then((_) {
  if (_pendingLayoutResetIds.isNotEmpty) {
    _pendingLayoutResetIds.clear();
    _saveOffsets();    // 将重置节点的旧坐标从 SharedPreferences 中清除
  }
});

// 在 _reloadOffsets 中跳过待重置节点：
for (final entry in map.entries) {
  if (_pendingLayoutResetIds.contains(entry.key)) continue; // ← 跳过，保留自动布局坐标
  // ... 正常恢复
}
```

**Prevention**:
- 凡涉及"用户操作改变数据结构（而非仅位置）"的回调，都要问：位置缓存是否仍然有效？
- 对应"重置布局"按钮已有完整先例：`_draggedIds.clear()` + `_saveOffsets()`，父子关系变更是局部版本

---

### 分组多选 + 三态复选框 + 可折叠（Group Tri-state Multi-select）

**Pattern**: 适用于"项目按分组显示，可整组选中/取消/半选"的筛选 UI（如导出页项目筛选区）。

**State**:
```dart
Set<String> _selectedIds = {};           // 已选项目 id
Set<String> _expandedGroupIds = {};      // 已展开分组 id
```

**Tri-state 计算**（每个分组头复选框的 value）：
```dart
// ✅ 正确：null = 半选态（indeterminate）
final groupItemIds = items.where((p) => p.groupId == group.id).map((p) => p.id).toSet();
final selectedCount = groupItemIds.intersection(_selectedIds).length;
final bool? groupValue = selectedCount == 0
    ? false
    : selectedCount == groupItemIds.length
        ? true
        : null; // indeterminate

// CheckboxListTile 用法：
CheckboxListTile(
  value: groupValue,
  tristate: true,
  onChanged: (v) => _onGroupChanged(group.id, groupItemIds, v),
  ...
)
```

**分组勾选逻辑**（点击分组头复选框）：
```dart
void _onGroupChanged(String groupId, Set<String> groupItemIds, bool? value) {
  setState(() {
    final next = Set<String>.from(_selectedIds);
    if (value == true || value == null) {
      // null（半选）点击后变全选
      next.addAll(groupItemIds);
    } else {
      next.removeAll(groupItemIds);
    }
    _selectedIds = next;
  });
}
```

> **⚠️ 注意**：`tristate: true` 时，`onChanged` 的 `value` 参数循环顺序是 `false → null → true → false`，而非 `false → true`。分组复选框的点击语义应覆盖：未选→全选，半选→全选，全选→取消。因此判断 `value == true || value == null` → addAll。

**折叠展开**：用 `_expandedGroupIds.contains(id)` 条件渲染子列表（而非 `AnimatedCrossFade`，避免不必要的性能开销）。

**未分组区块**：用哨兵 ID（如 `'__ungrouped__'`）统一处理未分组项目，逻辑与正常分组一致，避免 if/else 分叉。

**Related**: 导出页实现参见 `lib/presentation/pages/profile/task_export_page.dart`；折叠状态管理的更底层模式见下方"多层级列表的独立折叠状态管理"。

---

### 多层级列表的独立折叠状态管理

**Pattern**: 将一组任务按父任务分组、支持每组独立折叠/展开（日历跨天区使用此模式）。

**State**: 用 `Set<String>` 存储已折叠的组根 id，而非 `bool` 全局开关。

```dart
// ✅ 正确：每组独立折叠状态
final Set<String> _collapsedMultiDayGroups = {};

// 切换某组：
setState(() {
  if (_collapsedMultiDayGroups.contains(rootId)) {
    _collapsedMultiDayGroups.remove(rootId);
  } else {
    _collapsedMultiDayGroups.add(rootId);
  }
});

// 全部折叠/展开（仅针对有子任务的组）：
final groupsWithChildren = sortedRootIds
    .where((id) => childrenByRoot[id]!.isNotEmpty).toList();
final allCollapsed = groupsWithChildren.isNotEmpty &&
    groupsWithChildren.every((id) => _collapsedMultiDayGroups.contains(id));

setState(() {
  if (allCollapsed) {
    _collapsedMultiDayGroups.clear();
  } else {
    _collapsedMultiDayGroups.addAll(groupsWithChildren);
  }
});
```

**Grouping logic**: 找到任务在 lane 内的最顶层祖先作为组根（需加循环引用保护）：

```dart
Task groupRoot(Task task) {
  var cur = task;
  final visited = <String>{};
  while (cur.parentId != null && taskIds.contains(cur.parentId!) && visited.add(cur.id)) {
    final parent = tasks.where((t) => t.id == cur.parentId).firstOrNull;
    if (parent == null) break;
    cur = parent;
  }
  return cur;
}
```

**Sort**: 组间按父任务总跨度降序（最长在最上方）；父任务自身无日期时，取所有子任务跨度最大值作为组的排序依据：

```dart
int effectiveGroupSpan(String rootId) {
  final rootSpan = spanMs(rootById[rootId]!);
  if (rootSpan > 0) return rootSpan;
  final children = childrenByRoot[rootId] ?? [];
  return children.map(spanMs).fold(0, (a, b) => a > b ? a : b);
}
```

**⚠️ 组内排序必须用 DFS 递归，禁止扁平化后直接排序**：将所有非 root 任务扁平化后按 `sortOrder/startDate` 排序，在多层级（祖→父→子）结构中会导致父任务被子任务压到下面。正确做法是 DFS 递归，保证任何父节点永远先于其子节点输出：

---

## Notification Service Patterns

### Pattern: Persistent In-App Reminder Dialog (Desktop)

When desktop notifications must not auto-dismiss, replace the OS Toast with a Flutter Dialog:

**Foreground detection**:
```dart
bool _isAppInForeground() {
  final hasContext = AppRouter.navigatorKey.currentContext != null;
  final lifecycle = SchedulerBinding.instance.lifecycleState;
  // Desktop apps often report null lifecycle when active (not paused/detached)
  return hasContext && (lifecycle == AppLifecycleState.resumed || lifecycle == null);
}
```

**Dialog queue** (prevents stacking when multiple notifications fire at once):
```dart
final Queue<_PendingDialog> _dialogQueue = Queue();
bool _dialogShowing = false;

void _showInAppReminderDialog(int id, String title, String body, String? payload) {
  _dialogQueue.add(_PendingDialog(id: id, title: title, body: body, payload: payload));
  if (!_dialogShowing) _processDialogQueue();
}

void _processDialogQueue() {
  if (_dialogQueue.isEmpty) { _dialogShowing = false; return; }
  _dialogShowing = true;
  final item = _dialogQueue.removeFirst();
  final ctx = AppRouter.navigatorKey.currentContext;
  if (ctx == null) { _showOsNotificationFallback(item); _processDialogQueue(); return; }
  showDialog(
    context: ctx,
    barrierDismissible: false,  // MUST be false — user must confirm
    builder: (_) => ReminderDialog(...),
  ).whenComplete(_processDialogQueue);
}
```

**Rule**: `barrierDismissible` MUST be `false`. Never use `true` for reminder dialogs — the whole point is to prevent accidental dismissal.

**Snooze re-scheduling**:
```dart
void _rescheduleNotification(int id, String title, String body, String? payload, Duration delay) {
  Timer(delay, () => _showDesktopNativeNotification(id, title, body, payload: payload));
}
```

---

### Pattern: `pendingTaskId` — Cross-Widget Navigation from Notifications

When a notification is tapped, the app may not be running or the home widget may not be mounted yet. Use the static `pendingTaskId` field on `NotificationService` as a rendezvous point:

```dart
// In notification click callback (NotificationService.init):
pendingTaskId = response.payload;   // stash the payload
AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil('/', ...);

// In the home widget (after data is loaded — postFrameCallback):
void _processPendingNotificationTask() {
  final taskId = NotificationService.pendingTaskId;
  if (taskId == null) return;
  NotificationService.pendingTaskId = null;   // consume once

  if (taskId == 'overdue_navigate') {
    _navigateToFirstOverdueTask();
    return;
  }
  // find task in timeline and select + scroll
}
```

**Rule**: Always consume `pendingTaskId` in a `postFrameCallback` after the data is fully loaded — never consume it before the timeline tasks are populated.

**Reserved payloads**:
- `'overdue_navigate'` — navigate to the earliest overdue task in the timeline

**`pendingMarkDoneTaskId`** — companion field for mark-done from reminder dialog:
```dart
// In ReminderDialog's "标记完成" callback:
NotificationService.pendingMarkDoneTaskId = taskId;
AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil('/', ...);

// In home widget (after data loaded):
final markDoneId = NotificationService.pendingMarkDoneTaskId;
if (markDoneId != null) {
  NotificationService.pendingMarkDoneTaskId = null;  // consume once
  context.read<TaskNewBloc>().add(ToggleTaskStatus(taskId: markDoneId));
}
```

> **Gotcha**: Both `pendingTaskId` and `pendingMarkDoneTaskId` are static fields on `NotificationService`. If the project uses a web stub (`notification_service_web.dart`), any new static field added to the native file **must also be added to the web stub**. The `trellis-check` sub-agent caught this — see platform-compatibility.md for the stub-sync rule.

---

### Gotcha: Windows Notification Click Callback

`FlutterLocalNotificationsWindows.initialize()` uses a **different** parameter name than the mobile plugin:

```dart
// ✅ Windows — parameter is `onNotificationReceived`
await _windowsPlugin!.initialize(
  const WindowsInitializationSettings(...),
  onNotificationReceived: (response) {
    pendingTaskId = response.payload;
    AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil('/', ...);
  },
);

// ✅ Mobile — parameter is part of FlutterLocalNotificationsPlugin.initialize()
await _plugin!.initialize(
  initSettings,
  onDidReceiveNotificationResponse: (response) { ... },
);
```

**Also**: `_showWindowsPluginNotification` must explicitly pass `payload:` to `plugin.show()`. Without it, the callback receives `response.payload == null` and cannot route to the correct task.

---

### Pattern: Persist Notification Throttle State — Never Use In-Memory Counters

In-memory throttle state (e.g., `int _lastShownOverdueCount`) resets on every app restart, causing the same notification to fire on every cold launch.

```dart
// ❌ Wrong — resets on every restart
int _lastShownOverdueCount = 0;
if (count == _lastShownOverdueCount) return;
_lastShownOverdueCount = count;

// ✅ Correct — persist timestamp to SharedPreferences
final lastMs = LocalStorageService().overdueLastNotifMs;
final intervalMs = LocalStorageService().overdueNotifIntervalHours * 3600 * 1000;
if (DateTime.now().millisecondsSinceEpoch - lastMs < intervalMs) return;
await LocalStorageService().setOverdueLastNotifMs(DateTime.now().millisecondsSinceEpoch);
```

**Why**: `LocalStorageService` wraps `SharedPreferences`, which survives app restarts. The timestamp approach also makes the interval user-configurable with no additional logic.

```dart
List<Task> dfsChildren(List<Task> allChildren, String parentId) {
  final direct = allChildren
      .where((t) => t.parentId == parentId)
      .toList()
    ..sort((a, b) {
      final so = a.sortOrder.compareTo(b.sortOrder);
      if (so != 0) return so;
      return (a.startDate ?? 0).compareTo(b.startDate ?? 0);
    });
  final result = <Task>[];
  for (final child in direct) {
    result.add(child);
    result.addAll(dfsChildren(allChildren, child.id)); // 递归子树
  }
  return result;
}

// 使用：
for (final rootId in sortedRootIds) {
  orderedRows.add(rootById[rootId]!);
  orderedRows.addAll(dfsChildren(childrenByRoot[rootId]!, rootId));
}
```
