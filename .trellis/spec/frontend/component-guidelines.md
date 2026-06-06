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
