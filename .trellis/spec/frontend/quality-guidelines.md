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

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
