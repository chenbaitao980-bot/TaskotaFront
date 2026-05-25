# 任务：task-hierarchy-time-precision

## 阶段1：数据库迁移
- [ ] 1.1 Tasks 表新增 parentId 列
- [ ] 1.2 schema 版本 1→2 迁移逻辑

## 阶段2：Repository 后端
- [ ] 2.1 添加 getSubTasks / getDescendants 方法
- [ ] 2.2 添加 moveTask / reorderSubTasks 方法

## 阶段3：BLoC 事件和状态
- [ ] 3.1 新增 LoadSubTree / AddSubTask / MoveSubTask / ToggleSubTask 事件
- [ ] 3.2 新增 subTrees / expandedNodes 状态
- [ ] 3.3 实现对应 handler

## 阶段4：时间精度 UI
- [ ] 4.1 创建任务 BottomSheet 添加 TimePicker
- [ ] 4.2 编辑任务页面添加 TimePicker
- [ ] 4.3 任务卡片时间格式改为含时分
- [ ] 4.4 详情页信息区时间格式改为含时分

## 阶段5：子任务树 UI
- [ ] 5.1 创建 SubtaskTreeSection 组件（树形展开/折叠）
- [ ] 5.2 详情页嵌入子任务树区域
- [ ] 5.3 实现拖拽移动（LongPressDraggable + DragTarget）
- [ ] 5.4 内联添加子任务

## 验证
- [x] V1. 创建任务设置日期+时间 → 保存后显示正确
- [x] V2. 编辑任务修改时间 → 卡片和详情页刷新
- [x] V3. 添加子任务（含多层递归）→ 树正确展开
- [x] V4. 子任务展开/折叠
- [x] V5. 拖拽移动子任务到其他父节点
- [x] V6. 勾选子任务完成
- [x] V7. 检查项功能不受影响
