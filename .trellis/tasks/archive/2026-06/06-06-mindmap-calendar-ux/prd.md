# brainstorm: 思维导图拖拽后重置布局 + 日历跨天任务分组排序

## Goal

改善两处 UX 痛点：
1. 思维导图中把节点拖到另一节点下建立父子关系后，该子树布局保持旧的自由拖拽坐标，看起来很乱。
2. 日历模块顶部跨天长条区，父任务和子任务的排序/分组不清晰，缺乏按父节点折叠能力。

## What I already know

### Feature 1：思维导图拖拽重置布局

- 文件：`lib/presentation/pages/tasks/widgets/mind_map_view.dart`
- 节点有"自由拖拽坐标"存储在 `_draggedIds`（Set）+ `_positionNotifiers`（ValueNotifier<Offset>）
- 拖拽结束调用 `_saveOffsets()` 把自由坐标持久化到 SharedPreferences
- `onMoveToParent(draggedId, newParentId)` 触发时，外层 bloc 更新父子关系 → `didUpdateWidget` → `_computeLayoutCache()` + `_reloadOffsets()`
- **问题根因**：`_reloadOffsets()` 重新加载 SharedPreferences 中保存的旧坐标，`_draggedIds` 中还有被拖动节点的 id，因此节点继续停在旧位置，不受自动布局控制
- **修复方向**：当 `onMoveToParent` 完成后，清除受影响节点（被拖入子树 + 新父节点所在子树）的 `_draggedIds` 条目，让它们由自动布局重新定位，并保存更新后的 offsets

### Feature 2：日历跨天任务分组排序

- 文件：`lib/presentation/pages/calendar/calendar_page.dart`
- 方法：`_buildMultiDayLane(...)` 第 1669 行起
- 现有排序（第 1684 行）：按 `_depthOf(task)` 升序（浅层在上）→ 再按 startDate
- `_isMultiDayLaneCollapsed` 是一个全局折叠开关（全部折叠/展开）
- 已有 `day_task_lane_layout.dart` 提供 `assignDayTaskLanes` 算法（非重叠任务分配同行）

### 用户期望

**排序规则**：
- 父节点按跨度时长从长到短排序（最长的排最上面）
- 每个父节点下方紧跟其子节点
- 父节点之间支持**单独**折叠/展开（目前只有全局折叠）

**"并排（分组垂直堆叠）"**：不同父节点组各自独占行块，不共享行；每组内父行在上、子行在下；按父节点跨度降序排列

## Open Questions

（已全部确认）

## Requirements

### Feature 1（思维导图）

- 当 `onMoveToParent` 完成（任务父子关系变化后），自动清除被移动节点及其新父节点子树的 `_draggedIds` 条目
- 清除后触发自动布局（重新计算坐标）并保存 offsets
- 其余未受影响的节点保持其自由拖拽位置不变

### Feature 2（日历）

- 顶部跨天区按"父任务"组织（父 + 子为一组）
- 父任务组排序：跨度最长的组排在最上方
- 每组内：父任务行在最上，子任务紧跟其后（按 sortOrder 或 startDate）
- 每个父任务组有独立的折叠/展开 toggle（替代现有的全局 `_isMultiDayLaneCollapsed`）
- 全局折叠按钮改为"全部折叠/全部展开"

## Acceptance Criteria

- [ ] 思维导图：把节点拖到另一节点上方松手建立父子关系后，整棵子树重置为自动布局坐标（位置整齐）
- [ ] 思维导图：手动拖拽移动（不改变父子关系）时，自由坐标保持不变
- [ ] 日历：跨天区父任务按跨度降序排列，最长的在最顶部
- [ ] 日历：每个父任务组可单独折叠，折叠后只显示父任务行，展开显示父+子
- [ ] 日历：折叠状态不影响其他父任务组的展开状态

## Definition of Done

- 无 lint 错误
- Flutter analyze 无新 warning
- 在 Android/iOS/Desktop 都测试过拖拽和折叠交互

## Out of Scope

- 思维导图自动布局算法本身的优化（间距、方向等）
- 日历单日任务的排序逻辑
- 动画过渡效果

## Technical Notes

- 思维导图核心布局：`_assignPositions()` 第 448 行，父子坐标已正确计算，只需清除 `_draggedIds` 即可生效
- 日历 `_depthOf()` 第 212 行，可用于识别父任务（depth=0 或没有 parent）
- `_hasChildren()` 第 207 行，用于识别是否为父任务
- 日历折叠状态需改为 `Map<String, bool> _collapsedParentGroups`（key = 父任务 id）
