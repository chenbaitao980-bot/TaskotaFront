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

## Required Patterns

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

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

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
