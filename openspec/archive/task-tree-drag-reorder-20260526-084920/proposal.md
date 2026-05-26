# task-tree-drag-reorder

## 需求澄清摘要
主任务列表（TaskListView）当前平铺展示所有任务，不体现父子层级关系。虽然 `Tasks` 表已有 `parentId` 字段、详情页 `SubtaskTreeSection` 已有树形展示和拖拽，但主列表仍是扁平列表。本次变更将主列表改造为树形结构，集成拖拽排序能力，让用户在列表层即可感知和操作任务层级。

## 为什么
1. **结构不明朗**：用户在主列表看到一个平铺的任务流，无法区分"这是独立任务还是某个父任务的子任务"
2. **拖拽缺位**：调整任务层级必须进入详情页操作子任务树，路径长、不直观
3. **数据模型已就绪**：`parentId` 字段、`sortOrder` 字段、`moveTask()`、`reorderSubTasks()` 等 Repository 方法均已完备，只缺 UI 层表达

## 影响面
### 变更文件
| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `lib/presentation/pages/tasks/widgets/task_list_view.dart` | 重构 | 从平铺列表改为树形视图 + 拖拽 |
| `lib/presentation/pages/tasks/widgets/task_card.dart` | 修改 | 新增缩进、展开箭头、拖拽手柄属性 |
| `lib/presentation/pages/tasks/tasks_page.dart` | 修改 | 新增拖拽回调、展开/折叠状态管理 |
| `lib/presentation/blocs/task_new/task_event.dart` | 新增 | 新增 MoveTaskToParent、ToggleTaskExpand 事件 |
| `lib/presentation/blocs/task_new/task_state.dart` | 修改 | expandedNodes 扩展到主列表 |
| `lib/presentation/blocs/task_new/task_bloc.dart` | 修改 | 新增事件处理器 |
| `lib/presentation/pages/tasks/widgets/task_create_sheet.dart` | 修改 | 可选新增父任务选择 |

### 不变文件
- `lib/data/repositories/task_repository.dart` — 已有 `getRootTasks()`、`moveTask()`、`reorderSubTasks()`，无需改动
- `lib/data/database/app_database.dart` — 数据模型不变
- `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart` — 详情页子树逻辑不动

## 业务规范关系
- 命中的主 spec：无
- 关系判断：New Capability (ADDED)
- 不破坏已有功能：已完成任务折叠区域、筛选过滤、项目切换等均保持

## 改动范围
见 design.md §改动明细

## 验收
- [ ] 树形结构正确展示父子层级（根任务平级，子任务缩进）
- [ ] 拖拽排序生效（同一父级下重排）
- [ ] 子任务可拖到新父级下（跨父级移动）
- [ ] 子任务可拖回根节点（取消父级关系）
- [ ] 展开/折叠节点正确（折叠后子节点不可见）
- [ ] 已完成任务区域保持现有折叠展示（不在已完成区内做树形）
- [ ] 筛选（今天/重要/按项目）下树形结构仍然正确
- [ ] 已维护 `regression-tests/cases/task-tree-drag-reorder.md`
- [ ] 已执行 `gitnexus detect-changes`
- [ ] 无异常范围外变更
