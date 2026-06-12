# 日历模块拖动卡顿/回弹 + 父任务范围约束问题

## Goal

修复两个日历时间线问题：
1. 拖动任务块松手后出现的视觉"回弹"现象（先跳回原位，再跳到目标位置）
2. 父任务时间范围约束不正确（应恰好等于子任务范围，改大改小都应弹回）

## What I already know

### 问题 1：拖动回弹
* `_ResizableTaskBlockState` 使用 `Transform.translate(offset: _moveDelta)` 做实时拖动预览
* `onEnd` 中先 `setState(() { _moveDelta = null; })`（清除视觉偏移），然后调用 `w.onMove(target)`
* `_moveTask` 是 async 方法：先 `await _taskRepo!.update(...)` → 再 `await expandAncestorDates(...)` → 最后 `setState` 更新 `_allTasks`
* 在 `_moveDelta = null`（帧1：跳回原位）和 `_moveTask` 的 `setState`（帧N：出现在新位置）之间有异步 DB 操作的时间差
* 同样的问题存在于多天任务条（`_EditableMultiDayBar` 的 `_moveDeltaX`）

### 问题 2：父任务范围约束
* 当前 `_parentRangeCoversDescendants` 只检查父任务是否**覆盖**子任务范围
* 允许父任务范围**大于**子任务范围（例如子任务跨2天，父任务可以改成3天）
* 用户期望：父任务时间范围必须**恰好等于**子任务范围，改大改小都应弹回

## Root Cause

### 问题 1 根因
```
onEnd 触发
  ↓
setState(() { _moveDelta = null; })  → 帧1: 任务块跳回原位 ❌
  ↓
w.onMove(target) → _moveTask(task, target)
  ↓
await _taskRepo!.update(...)         → 等待 DB I/O（几十~几百毫秒）
  ↓
await _taskRepo!.expandAncestorDates(...)
  ↓
setState(() { 更新 _allTasks })      → 帧N: 任务块出现在新位置
```

帧1→帧N 之间的时间差 = 视觉"回弹→跳跃"

### 问题 2 根因
```dart
bool _parentRangeCoversDescendants(...) {
  // 当前逻辑：normStart <= normChildStart && normEnd >= normChildEnd
  // 只检查"覆盖"，不检查"相等"
}
```

## Requirements

* 拖动松手后，任务块应平滑过渡到新位置，不出现回弹
* 多天任务条横向拖动同理
* 父任务时间范围必须恰好等于子任务范围（开始和结束日期都要匹配）
* 如果 DB 操作失败，任务块应回弹到原位（错误恢复）

## Acceptance Criteria

* [x] 单日任务拖动松手后不回弹
* [x] 多天任务条拖动松手后不回弹
* [x] 父任务扩大范围超过子任务时弹回并提示
* [x] 父任务缩小范围小于子任务时弹回并提示
* [x] DB 操作失败时任务块正确回弹到原位

## Decision (ADR-lite)

**Context**: 拖动和 resize 共用同一模式，但用户只要求修拖动；父任务范围约束需要加强
**Decision**: 
1. 只修 move 操作（单日 `_ResizableTaskBlockState.onEnd` + 多天 `_EditableMultiDayBarState.onHorizontalDragEnd`），resize 暂不动
2. 将 `_parentRangeCoversDescendants` 改为 `_parentRangeMatchesDescendants`，检查精确匹配
**Consequences**: resize 仍可能有回弹，后续如有需要再补修

## Technical Approach

### Fix 1: 延迟清除 delta，等待 async 操作完成

核心改动：`onMove` / `onMoveDay` 回调签名从 `void Function(...)` → `Future<void> Function(...)`

```dart
// Before (bug):
..onEnd = (details) {
  setState(() { _moveDelta = null; }); // ← 立即清除
  w.onMove(target);                     // ← fire & forget async
}

// After (fix):
..onEnd = (details) async {
  await w.onMove(target);               // ← 等待 async 完成
  if (mounted) setState(() { _moveDelta = null; });
}
```

这样 `_moveDelta` 保持非 null → `Transform.translate` 继续把块显示在拖动位置 → `_moveTask` 的 `setState` 更新 Positioned 的 top/left 到新位置 → 清除 `_moveDelta`（此时 Positioned 已接管定位，视觉上无跳跃）。

### Fix 2: 父任务范围精确匹配子任务

```dart
// Before: 只检查覆盖
bool _parentRangeCoversDescendants(...) {
  return !normStart.isAfter(normChildStart) &&
         !normEnd.isBefore(normChildEnd);
}

// After: 检查精确匹配
bool _parentRangeMatchesDescendants(...) {
  return normStart.isAtSameMomentAs(normChildStart) &&
         normEnd.isAtSameMomentAs(normChildEnd);
}
```

## Out of Scope

* resize 操作的回弹修复（上下边缘拖动调整时间）
* 多天任务条的 resize（左右边缘拖动）
* 甘特图视图的拖动（如果有）
* 拖动画面的动画插值优化（当前是即时跟随，不需要补间动画）

## Technical Notes

* 文件: `lib/presentation/pages/calendar/calendar_page.dart`
* `_ResizableTaskBlockState`: 单日任务块的拖动 + resize
* `_EditableMultiDayBarState`: 多天任务条的横向拖动 + resize
* `_moveTask`, `_moveTaskMultiDay`: async 方法（已有 setState + _reloadData）
* `_parentRangeCoversDescendants`: 需改为 `_parentRangeMatchesDescendants`
* `descendantTaskTimeRange`: 计算子任务的时间范围（已有函数）
