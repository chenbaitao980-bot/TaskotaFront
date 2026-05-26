# 设计：task-tree-drag-reorder

## 需求澄清依据
主任务列表改为树形结构，展示父子任务层级关系，支持拖拽排序、跨父级移动、升降为根节点。

## 当前状态

### 数据层（已完备）
- `Tasks` 表：`parentId`（可空）表示父子关系，`sortOrder` 表示同级排序
- `TaskRepository`：
  - `getRootTasks()` — 获取 parentId == null 的任务
  - `getSubTasks(parentId)` — 获取直接子任务
  - `getDescendants(taskId)` — BFS 递归获取所有后代
  - `moveTask(taskId, newParentId)` — 改变父级
  - `reorderSubTasks(parentId, orderedIds)` — 重排子任务

### UI 层（当前问题）
- `TaskListView`：用 `taskRepository.getAll()` 拉取平铺列表，按 pending/completed 分组展示 `TaskCard`
- `TaskCard`：简单卡片，无缩进、无展开箭头、无拖拽手柄
- `SubtaskTreeSection`（详情页）：已有树形展示 + `Draggable<String>` / `DragTarget<String>` 拖拽，是本次重构的**参考实现**

### BLoC 层
- `TaskNewLoaded` 已有 `expandedNodes: Map<String, Set<String>>`（只用于详情页子树）
- `LoadTasks` 事件加载全量 task 平铺列表
- `MoveSubTask` / `ToggleTreeNode` 等事件只服务于详情页子树

## 方案

### 总体策略
**最小侵入**：复用已有 Repository 方法，不改数据层；UI 层从平铺列表改为树形递归渲染；复制 `SubtaskTreeSection` 的拖拽模式到主列表。

### 核心数据结构

```dart
// 树节点包装，用于渲染
class _TaskTreeNode {
  final Task task;
  final int depth;          // 缩进深度（0=根节点）
  final bool hasChildren;   // 是否有子任务
  final bool isExpanded;    // 当前是否展开
}
```

### 树构建算法

```dart
List<_TaskTreeNode> _buildFlatTree(
  List<Task> allTasks,
  Set<String> expandedIds,
) {
  final result = <_TaskTreeNode>[];
  final rootTasks = allTasks
    .where((t) => t.parentId == null)
    .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  
  for (final root in rootTasks) {
    _addNode(root, 0, allTasks, expandedIds, result);
  }
  return result;
}

void _addNode(
  Task task, int depth, List<Task> allTasks,
  Set<String> expandedIds, List<_TaskTreeNode> result,
) {
  final children = allTasks
    .where((t) => t.parentId == task.id)
    .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  
  final hasChildren = children.isNotEmpty;
  result.add(_TaskTreeNode(task, depth, hasChildren,
    expandedIds.contains(task.id)));
  
  if (hasChildren && expandedIds.contains(task.id)) {
    for (final child in children) {
      _addNode(child, depth + 1, allTasks, expandedIds, result);
    }
  }
}
```

### 拖拽交互模型

参照 `SubtaskTreeSection` 的 `Draggable<String>` + `DragTarget<String>` 模式：

1. **拖拽手柄**：每个树节点左侧显示六点图标，长按拖拽
2. **放置目标**：每个树节点本身是 DragTarget，收到拖放时将被拖任务移为放置目标的子任务
3. **根级放置区**：列表顶部添加一个"拖到此处移为根任务"的 DragTarget
4. **同级排序**：通过 DragTarget 的 onAcceptWithDetails 配合 reorderSubTasks 实现

```
┌─────────────────────────────────┐
│ [拖到此处 → 移为根任务]           │  ← DragTarget (parentId = null)
├─────────────────────────────────┤
│ ≡ ▼ 父任务A                      │  ← DragTarget + Draggable
│   ≡ 子任务A1                     │  ← DragTarget + Draggable
│   ≡ ▶ 父任务B (折叠)              │  ← DragTarget + Draggable (子不可见)
│   ≡ ▼ 父任务C (展开)              │  ← DragTarget + Draggable
│     ≡ 子任务C1                   │
│       ≡ 孙任务C1a                 │
└─────────────────────────────────┘
```

### 展开/折叠状态管理

- 复用 `TaskNewLoaded.expandedNodes`，将 key 从 `rootTaskId` 改为全局 `'main_tree'`
- 新增 `ToggleTaskExpand(taskId)` 事件
- 折叠后子节点从 `_buildFlatTree()` 结果中消失，无需额外隐藏逻辑

### 已完成任务处理

已完成任务区域保持现有 `ExpansionTile` 折叠展示，不在已完成区内做树形结构（已完成任务通常无需层级操作）。

## 改动明细

### 文件 1: `lib/presentation/blocs/task_new/task_event.dart`
**新增事件**：
```dart
class MoveTaskToParent extends TaskEvent {
  final String taskId;
  final String? newParentId;  // null = 移为根任务
}

class ToggleTaskExpand extends TaskEvent {
  final String taskId;
}

class ReorderTaskSiblings extends TaskEvent {
  final String? parentId;  // null = 根级任务
  final List<String> orderedIds;
}
```

### 文件 2: `lib/presentation/blocs/task_new/task_state.dart`
**修改**：`expandedNodes` 增加主列表 key `'main_tree'` 的初始化。

### 文件 3: `lib/presentation/blocs/task_new/task_bloc.dart`
**新增 handler**：
- `_onMoveTaskToParent`：调用 `taskRepository.moveTask(taskId, newParentId)`，然后刷新列表
- `_onToggleTaskExpand`：切换 `expandedNodes['main_tree']` 中的节点 ID
- `_onReorderTaskSiblings`：调用 `taskRepository.reorderSubTasks(parentId, orderedIds)`，刷新列表

### 文件 4: `lib/presentation/pages/tasks/tasks_page.dart`
**修改**：
- `TaskListView` 新增 `expandedIds`、`onToggleExpand`、`onMoveToParent`、`onReorderSiblings` 回调
- 从 `state.expandedNodes['main_tree']` 读取展开状态

### 文件 5: `lib/presentation/pages/tasks/widgets/task_card.dart`
**新增属性**：
```dart
final int depth;              // 缩进层级
final bool hasChildren;       // 是否有子任务
final bool isExpanded;        // 是否展开
final VoidCallback? onToggleExpand;  // 展开/折叠回调
final bool showDragHandle;    // 是否显示拖拽手柄
```

**UI 变化**：
- 左侧增加 `depth * 24px` 缩进
- 有子任务时显示展开/折叠箭头 (`▶` / `▼`)
- 可拖拽时显示六点拖拽图标

### 文件 6: `lib/presentation/pages/tasks/widgets/task_list_view.dart`
**重构**：
- 从 `StatelessWidget` + `ListView(children: [...])` 改为 `StatefulWidget` + 树形递归构建
- 构建 `List<_TaskTreeNode>` 后渲染
- 每个节点包裹在 `Draggable<String>` + `DragTarget<String>` 中
- 顶部添加"移为根任务"DragTarget
- 已完成任务区域保持原样

### 文件 7: `regression-tests/cases/task-tree-drag-reorder.md`
新建回归测试用例文件。

## 业务规则处理
- 原 Requirement / Scenario：无（New Capability）
- 本次处理方式：ADDED
- 不修改已有 spec，创建新 spec

## 回归测试方案
- 用例文件：`regression-tests/cases/task-tree-drag-reorder.md`
- 测试方法：手工验证 — 运行 Flutter app，逐一验证验收项

## 回滚方案
删除 `openspec/changes/task-tree-drag-reorder/` 目录，代码通过 git 回退。
