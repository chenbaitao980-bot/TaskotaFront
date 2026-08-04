# Quality Guidelines

> Code quality standards for frontend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

### 重复取消已取消的资源

在循环或批处理中，避免对同一组资源执行多次取消/清理操作。

```dart
// ❌ 错误：reschedule 内部已 cancel，又遍历 cancel 一次
List<someIds> ids = [];
for (final task in tasks) {
  cancelReminderForSchedule(task.id); // 已取消
  ids.add(task.id);
}
await _clearOverdueAlarms(ids); // 又取消一次 ← 重复工作
```

**解决方法**：取消操作只在一个位置执行，移除重复调用。

---

### setOpacity(0) 强制重绘 → WS_EX_LAYERED 分层窗口病理

窗口显示/隐藏时**禁止用 `setOpacity` 做"强制重绘/闪白兜底"**——它是本任务"便签定位白屏"复发轮的最大回归源（prd 复发根因 RC1）。

```dart
// ❌ 错误：hideToTray 先 setOpacity(0)，restoreFullWindow 后 setOpacity(1)
// → SetWindowLong(GWL_EXSTYLE|WS_EX_LAYERED) 把主窗变分层窗口
// → alpha=0 时 show() 整窗全透明不可见（需点任务栏）
// → 分层窗口 + 未聚焦渲染节流 → 全窗卡顿直到点击强制重绘
await windowManager.setOpacity(0); // ← 病理源头
```

**为什么坏**：window_manager 的 `setOpacity` 走 `WS_EX_LAYERED` + `SetLayeredWindowAttributes(alpha)`。alpha=0 使窗口全透明；分层窗口不走正常 D3D 合成 + Windows 对后台未聚焦窗口降渲染优先级 → "不弹出 + 全窗冻结"。

**替代**：白屏应修根因（网络守卫/懒加载），不是透明度兜底。置前台用 TOPMOST 双切（见 platform-compatibility 的 Windows 窗口模式）。

---

## Required Patterns

### AppLifecycle onResume 节流（≥30s）+ 移除秒级重调度

`AppLifecycleListener.onResume` 会被窗口激活/置顶/第二引擎抢焦点**反复触发**。若回调里有重活（全量 reschedule、LoadTasks），会变成每 6-12s 成对重载风暴。

```dart
// ✅ 正确：时间节流 + 只做必要的本地刷新，不重调度提醒
DateTime? _lastResumeLoadTime;

void _onAppResume() {
  final now = DateTime.now();
  if (_lastResumeLoadTime != null &&
      now.difference(_lastResumeLoadTime!) < const Duration(seconds: 30)) {
    return; // 30s 节流
  }
  _lastResumeLoadTime = now;
  _debounceLoadTasks(); // 本地刷新
  // 不要 await _rescheduleTaskReminders() —— 启动已调度一次，Timer 存活即有效
}
```

**关键**：`rescheduleTaskReminders` 每任务产生 N 次平台通道取消调用（本任务实测 24 次/任务，115 任务 ~6.4s）——每次回前台全量重排会拖死首帧。启动 `_initStorage` 调度一次即可，窗口激活无需重排。

### 平台通道批量调用降量（cancelRepeats 折叠）

批量重调度路径调用的平台通道方法必须支持"跳过重活"参数，否则每任务 × 每重复次数的通道调用在数据量大时秒级阻塞。

```dart
// ✅ 正确：cancelRepeats=false 折叠 21 次 repeat 取消（每任务 24→2 次）
Future<void> cancelReminderForSchedule(
  String scheduleId, {
  bool cancelRepeats = true, // 批量重调度传 false，单任务删除传默认 true
}) async {
  await cancelNotification(notificationIdForSchedule(scheduleId));
  await cancelNotification(notificationIdForSchedule(scheduleId, offset: 1));
  if (!cancelRepeats) return; // ← 跳过 21 次 repeat 循环
  ...
}
```

**注意**：批量重调度路径会立刻用相同 id 重建 repeat 通知，无需先清；单任务删除/停用才需全量取消。

---

### 通知防重复弹窗模式

当定时/周期性回调可能多次触发通知显示时，缓存上次已通知的状态值，仅当状态变化时才弹窗。

```dart
// ✅ 正确：数量不变不重复弹
int _lastShownOverdueCount = 0;

Future<void> _showOverdueDigest(int count) async {
  if (count <= 0) { _lastShownOverdueCount = 0; return; }
  if (count == _lastShownOverdueCount) return; // ← 去重
  _lastShownOverdueCount = count;
  // ... 显示通知
}
```

**适用场景**：过期任务摘要、批量提醒、轮询状态通知

### ValueNotifier + ValueListenableBuilder 替代 setState 做局部重建

当 `setState` 会导致大面积 widget 树重建时，用 `ValueNotifier` + `ValueListenableBuilder` 将重建范围缩小到最小子树。

```dart
// ❌ 错误：setState 重建了整个 StatefulWidget 的 build()
BottomNavigationBar(
  currentIndex: _currentIndex,
  onTap: (index) {
    setState(() => _currentIndex = index); // ← build() 全量重跑
  },
);

// ✅ 正确：ValueNotifier + ValueListenableBuilder 只重建受影响子树
final ValueNotifier<int> _tabIndex = ValueNotifier<int>(0);

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (ctx, index, _) => IndexedStack(index: index, children: _pages),
    ),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: _tabIndex,
      builder: (ctx, index, _) => _BottomNavBar(currentIndex: index, onTap: _onNavTap),
    ),
  );
}

void _onNavTap(int index) {
  _tabIndex.value = index; // ← 仅 ValueListenableBuilder 子树重建
}
```

**适用场景**：
- Tab 底部导航切换（IndexedStack + BottomNavigationBar）
- 大面积 Scaffold 内仅需局部刷新
- 需要避免 `setState` 重建父 widget 树中的庞大或复杂子节点

**注意事项**：
- 底部导航栏的 widget 内容应提取为独立 `StatelessWidget`，让框架可以高效复用 widget 引用
- 需要在 `dispose()` 中调用 `valueNotifier.dispose()`

### Canvas 分层渲染：AnimatedBuilder 只包 CustomPaint，节点层用独立 VLB

画布内拖拽时，**不要**用单个 `AnimatedBuilder(Listenable.merge(all_notifiers))` 包裹整个 Stack。这会在每次任意一个节点位置改变时重建全部 N 个节点，60fps 下 = O(N) 全量 rebuild/frame。

**正确做法**：连线层和节点层分开渲染：

```dart
// ❌ 错误：整个 Stack 被同一个 AnimatedBuilder 包裹
AnimatedBuilder(
  animation: Listenable.merge(_positionNotifiers.values.toList()),
  builder: (context, _) => Stack(children: [
    CustomPaint(painter: LinesPainter(...)),  // 需要所有位置
    ...nodes.map((n) => Positioned(..., child: NodeCard(n))),  // 各自只需自己的位置
  ]),
);

// ✅ 正确：连线层 AnimatedBuilder 只包 CustomPaint；节点层各自 VLB
Stack(children: [
  // 连线层：必须感知所有位置，但只重建 CustomPaint
  AnimatedBuilder(
    animation: Listenable.merge(_positionNotifiers.values.toList()),
    builder: (_, __) => CustomPaint(painter: LinesPainter(...)),
  ),
  // 节点层：各节点独立 VLB，只在自身位置变化时 rebuild
  ...nodes.map((node) {
    final notifier = _positionNotifiers[node.id]!;
    return ValueListenableBuilder<Offset>(
      valueListenable: notifier,
      builder: (_, pos, child) => Positioned(left: pos.dx, top: pos.dy, child: child!),
      child: NodeCard(node),   // child 只在 parent VLB 重建时才重建（不受位置变化影响）
    );
  }),
]);
```

**效果**：拖拽时只有 `CustomPaint` + 被拖节点的 `Positioned` 更新；其余 N-1 个节点零 rebuild。

**适用场景**：MindMapView 或任何包含大量独立可移动元素的 Canvas 组件。

---

### 拖拽开关用 ValueNotifier<bool> + VLB，禁止 setState

`onDragStart`/`onDragEnd` 需要切换 `InteractiveViewer.panEnabled`。若用 `setState` 驱动，会重建整个 State 的 `build()`，触发所有节点 VLB 重建。

```dart
// ❌ 错误：setState 导致全量重建
setState(() => _nodeDragging = true);

// ✅ 正确：只重建 InteractiveViewer 这一棵子树
final ValueNotifier<bool> _nodeDragging = ValueNotifier(false);

// 在 build 中包裹 InteractiveViewer：
ValueListenableBuilder<bool>(
  valueListenable: _nodeDragging,
  builder: (context, dragging, _) => InteractiveViewer(
    panEnabled: !dragging,
    child: ...,
  ),
);

// 在 onDragStart / onDragEnd 中：
_nodeDragging.value = true;   // 不触发 build()
```

**注意**：必须在 `dispose()` 中调用 `_nodeDragging.dispose()`。

---

### build() 中的 O(n²) 查找必须提前提取为 Set

任何在 `build()` 中对 `List<T>` 执行的 `any()` / `contains()` 嵌套循环，在节点数增长后都会成为帧率杀手。

```dart
// ❌ 错误：每次 build 时 O(n²)
final allParentIds = state.tasks
    .where((t) => state.tasks.any((c) => c.parentId == t.id))  // O(n²)
    .map((t) => t.id)
    .toSet();

// ✅ 正确：先建 Set，再查，O(n)
final parentIdSet = state.tasks
    .map((t) => t.parentId)
    .whereType<String>()
    .toSet();
final allParentIds = state.tasks
    .where((t) => parentIdSet.contains(t.id))  // O(1) per lookup
    .map((t) => t.id)
    .toSet();
```

**Prevention**：`build()` 中若出现 `.any((c) => list.xxx == yyy)` 嵌套，立即提取为 Set。

---

### SharedPreferences 写入必须防抖，不得在拖拽热路径中同步触发

拖拽结束时每次都直接写 SharedPreferences 会在低端设备上造成可感知卡顿。

```dart
// ❌ 错误：每次 onDragEnd 直接写
void _saveOffsets() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_storageKey, jsonEncode(map));  // 每次触发 I/O
}

// ✅ 正确：300ms 防抖，仅合并最后一次写
Timer? _saveOffsetDebounce;

void _saveOffsets() {
  _saveOffsetDebounce?.cancel();
  _saveOffsetDebounce = Timer(const Duration(milliseconds: 300), _flushOffsets);
}

Future<void> _flushOffsets() async {
  final prefs = await SharedPreferences.getInstance();
  // ... 实际写入
}
```

**注意**：`dispose()` 中必须 `_saveOffsetDebounce?.cancel()`，避免 widget 销毁后异步回调访问已释放资源。显式"重置布局"等用户主动操作可跳过防抖，直接调用 `_flushOffsets()`。

---

### 首屏数据本地优先（Local-First），网络后合入

任何影响首屏/首批数据展示的网络请求，必须遵循：先用本地缓存立即上屏，后台拉取云端数据，有差异时静默合并。

```dart
// ❌ 错误：首屏数据等网络返回才上屏
if (state is! TaskNewLoaded) {
  final localPrefs = _storage.getTaskFilterState();
  final cloudPrefs = await supabaseService?.fetchPreferences(); // 网络阻塞
  final prefs = cloudPrefs ?? localPrefs;
  // ... 用 prefs 继续加载
}
final allTasks = (await taskRepository.getAll())...; // 首发数据被上面网络请求卡住

// ✅ 正确：本地数据立即上屏，云端后台拉取
if (state is! TaskNewLoaded) {
  final localPrefs = _storage.getTaskFilterState();
  if (localPrefs != null) {
    // 立即用本地偏好继续（不 await 网络）
    preservedFilter = localPrefs['selectedFilter'] as String? ?? 'all';
    // ...
  }
  unawaited(_syncCloudPrefsAfterLoad(localPrefs)); // 后台同步
}
final allTasks = (await taskRepository.getAll())...; // 首发数据不依赖网络
```

**适用场景**：
- 启动时恢复用户偏好/筛选状态
- 会员配置、订阅状态（`init()` 只 `_loadFromCache()`，`refresh()` 放首帧后）
- 任何"云端有当然好，没有本地也能跑"的数据

**核心原则**：用户打开 App 的体感 = 本地 I/O 延迟；绝不能 = 网络 RTT。


---

## Testing Requirements

### Flutter widget 测试：drift `watch()` 流 + `pumpAndSettle` 陷阱

**Symptom**: 对基于 `StreamBuilder(stream: repository.watchXxx())`（drift 流）的页面做 widget 测试时，`pumpAndSettle()` 卡死直到超时，或测试结束时抛 `A Timer is still pending even after the widget tree was disposed`。

**Cause**: drift 的 `watch()` 是持续流，`StreamBuilder` 订阅期间 widget 树存在 pending timer；`pumpAndSettle` 等待所有帧结束，而流始终活跃导致永不 settle；测试结束后订阅未取消则 `_verifyInvariants` 报 timer pending。

**Fix**:
- 用**固定时长 pump** 替代 `pumpAndSettle`（bottom sheet 动画：`pump()` + `pump(const Duration(milliseconds: 600))`）。
- 每个 `testWidgets` 末尾**卸载 widget 树**取消流订阅：`await tester.pumpWidget(const SizedBox()); await tester.pump(const Duration(milliseconds: 100));`
- 用 `NativeDatabase.memory()` 构造内存库，测试结束 `database.close()`。

**Prevention**: 涉及 drift 流的页面测试统一走此模式；`pumpAndSettle` 只用于无持续流的纯 UI 动画测试。

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)

---

## 通知与原生集成模式

### Android 原生 AlarmManager 兜底模式

当 `flutter_local_notifications` 的 `zonedSchedule` 在进程被杀后不触发时，使用原生 `AlarmManager.setAlarmClock()` 兜底。

**架构**：
```
Dart: alarm_service.dart
  → MethodChannel('com.taskora/native_alarm')
    → Kotlin: MainActivity.kt (MethodChannel handler)
      → NotificationAlarmHelper.kt (AlarmManager.setAlarmClock)
        → NotificationAlarmReceiver.kt (BroadcastReceiver → 系统通知)
```

**MethodChannel 签名**：

| 方法 | 参数 | 说明 |
|------|------|------|
| `scheduleNotification` | `{id: int, title: String, body: String, scheduledAtMillis: long}` | 调度闹钟 |
| `cancelNotification` | `{id: int}` | 取消闹钟 |

**切换开关**：
```dart
AlarmService.useNativeAlarm = true;  // 原生方案（默认）
AlarmService.useNativeAlarm = false; // 回滚到 alarm 包
```

### 通知通道合并模式（清理旧通道）

当需要精简通知分类时，先删除旧通道再创建统一通道：
```dart
await androidPlugin.deleteNotificationChannel('old_channel_1');
await androidPlugin.deleteNotificationChannel('old_channel_2');
const androidPluginDetails = AndroidNotificationChannel(
  'unified_channel',    // 统一通道 ID
  '统一通道名称',         // 用户可见的名称
  importance: Importance.high,
  playSound: true,
);
await androidPlugin.createNotificationChannel(androidPluginDetails);
```

**注意**：删除旧通道后，系统设置中会保留历史条目，但不再产生新通知。

### 通知音效设置

| 场景 | 设置 |
|------|------|
| `flutter_local_notifications` 通道 | `playSound: true`（通道级默认音）|
| 原生 `NotificationChannel` | `setSound(Settings.System.DEFAULT_NOTIFICATION_URI)` |
| `alarm` 包回滚路径 | `VolumeSettings.fixed(volume: null)` 使用当前系统音量 |
| 自定义音效 | ❌ 不使用 `assetAudioPath` |
