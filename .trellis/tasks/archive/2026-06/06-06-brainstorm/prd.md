# brainstorm: 思维导图切换筛选项目后布局错乱

## Goal

修复思维导图页面在切换筛选项目（project filter）后，节点坐标布局变成随机/自动布局，而不是保留用户最后手工拖拽修改的位置。

## What I already know

- 思维导图使用 `SharedPreferences` 存储每个 task 的手工拖拽位置，key 为 `mindmap_offsets_${userId}`
- 存储形式：`{"<taskId>": [x, y], ...}`，仅存储被拖拽过的节点
- 节点位置管理：`_positionNotifiers` (Map<String, ValueNotifier<Offset>>) + `_draggedIds` (Set<String>)
- 布局自动计算：`_computeLayoutCache()` 基于树形结构计算每个节点的默认坐标

## 根因分析（来自代码审计）

**核心 bug：`_loadOffsets()` 只在 `initState()` 中调用一次，切换筛选项目后不再重新加载。**

完整路径：

1. `initState()` → `_computeLayoutCache()` → `_loadOffsets()` ← 只有这里加载 SharedPreferences
2. 用户切换到项目 B → `didUpdateWidget()` → `_computeLayoutCache()` → `_syncNotifiersToLayout()`
3. `_syncNotifiersToLayout()` 中，项目 A 的节点不在新 task 集合中 → notifier 被 dispose，`_draggedIds` 被清除
4. 用户切回项目 A → `didUpdateWidget()` → `_computeLayoutCache()` → `_syncNotifiersToLayout()`
5. 项目 A 的节点是新创建的 notifier（步骤 3 被清理了）→ 拿到的是 **自动计算的布局坐标**
6. **`_loadOffsets()` 从未再次执行** → 存储在 SharedPreferences 中的手工位置丢失

**导致的现象**：每次切换筛选项目，导图都回到自动计算布局，而不是用户最后修改的样子。

**次要观察**：`_initialFocusDone` 在 `didUpdateWidget` 中被重置为 `false`，触发 `_focusNearestTask()`，也可能让用户以为布局变化了。

## 已检查的代码文件

- `lib/presentation/pages/tasks/widgets/mind_map_view.dart` — 全部逻辑
- `lib/presentation/pages/tasks/tasks_page.dart` — MindMapView 使用处

## Open Questions

*（无）*

## Requirements

### 核心需求
- 用户对导图的节点位置修改（拖拽）在切换筛选项目后必须保留
- 切换回来时导图应该呈现用户最后离开时的样子

### 非功能需求
- 不引入性能退化（`_loadOffsets()` 是异步 IO，不应在每次 rebuild 触发）
- 不改动现有的拖拽交互逻辑

## Acceptance Criteria

- [ ] 切换到项目 A → 拖拽节点 → 切换到项目 B → 切回项目 A → 节点的位置与拖拽后一致
- [ ] 切换到项目 B → 拖拽节点 → 切回项目 A → 切回项目 B → 节点位置与拖拽后一致
- [ ] 首次打开导图（无存储数据）→ 节点使用自动计算布局
- [ ] 重置布局按钮正常工作

## Definition of Done

- [ ] 修改验证通过（flutter analyze 无 error/warning）
- [ ] 手动测试通过
- [ ] 根因写入 spec 文档（若为新的模式）

## Decision (ADR-lite)

**Context**: `_loadOffsets()` 只在 `initState()` 中调用一次，切换筛选项目后不再重新加载，导致手工拖拽位置丢失。

**Decision**: 采用方案 A — 在 `didUpdateWidget` 中 task 列表变化后，重新从 SharedPreferences 加载 offset。新增 `_reloadOffsets()` 方法（区别于 `_loadOffsets()`，不重新触发 `_focusNearestTask`）。

**Consequences**:
- 改动最小（约 5 行），仅修改 `mind_map_view.dart`
- 兼容现有数据格式（`mindmap_offsets_${userId}`）
- 异步 IO 仅在 task 列表/展开状态变更时触发，不影响 rebuild 性能

## Out of Scope

- 不涉及连接线/展开折叠的布局问题
- 不涉及新节点的创建交互
- 不涉及空状态/首次加载的优化

## Technical Notes

### 推荐方案（方案 A）：`didUpdateWidget` 中重新加载 offset

在 `didUpdateWidget` 中，当 task 或 expandedIds 变化后，新增 `_reloadOffsets()` 调用。

```dart
@override
void didUpdateWidget(MindMapView oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.tasks != widget.tasks ||
      oldWidget.expandedIds != widget.expandedIds) {
    _computeLayoutCache();
    _reloadOffsets();  // 新增
  }
  if (oldWidget.selectedFilter != widget.selectedFilter ||
      oldWidget.selectedProjectId != widget.selectedProjectId) {
    _initialFocusDone = false;
  }
}
```

`_reloadOffsets()` 与 `_loadOffsets()` 的核心区别：
- 不重置 `_offsetsLoaded`（避免重复的 `_focusNearestTask` 触发）
- 不触发 `setState` 性质的 `_focusNearestTask`
- 使用 `_storageKey` 从 SharedPreferences 读取已存储位置
