# 任务：task-tree-drag-reorder

## 实施
- [ ] 1. 新增 TaskEvent：MoveTaskToParent、ToggleTaskExpand、ReorderTaskSiblings
- [ ] 2. BLoC 新增 3 个 handler（_onMoveTaskToParent、_onToggleTaskExpand、_onReorderTaskSiblings）
- [ ] 3. TaskCard 新增 depth/hasChildren/isExpanded/onToggleExpand/showDragHandle 属性
- [ ] 4. 重构 TaskListView：从平铺 ListView 改为树形 StatefulWidget + Draggable/DragTarget
- [ ] 5. TasksPage 新增 expandedIds 读取、onToggleExpand/onMoveToParent 回调
- [ ] 6. 编辑 task_create_sheet.dart 新增可选父任务选择字段
- [ ] 7. 创建回归测试用例文件
- [ ] 8. 运行 flutter analyze 确保无警告
- [ ] 9. 运行 gitnexus detect-changes 确认影响范围

## 验证
- [x] <用户确认：树形结构正确展示父子层级（根任务平级，子任务缩进）>
- [x] <用户确认：拖拽排序生效（同一父级下重排）>
- [x] <用户确认：子任务可拖到新父级下（跨父级移动）>
- [x] <用户确认：子任务可拖回根节点>
- [x] <用户确认：展开/折叠正常（折叠后子节点隐藏）>
- [x] <用户确认：已完成任务区域保持折叠展示>
- [x] <用户确认：筛选条件下树形结构正确>
