# 方案：任务层级与时间精度

## 一、背景

当前任务管理模块已完成基础 CRUD，但有两个关键能力缺失：

1. **时间只精确到日**：创建/编辑任务时只能用 DatePicker 选择日期，无法设置具体的小时和分钟。对于需要精确时间线的日程类任务，不够用。
2. **任务只有单层**：任务不能嵌套子任务，而用户需要树形结构来组织复杂任务（如一个项目下有多层子任务）。

## 二、解决方案

### 2.1 时间精确到分

保持数据库毫秒时间戳不变（`start_date` / `due_date` / `completed_time` 都是 INTEGER 毫秒时间戳，天然支持精度），只改 UI 层：

- 创建任务的 BottomSheet 和编辑全屏页：日期选择器后追加 **TimePicker**
- 任务卡片的日期展示：显示 `MM/dd HH:mm` 格式
- 详情页信息区：显示 `yyyy-MM-dd HH:mm` 格式

### 2.2 子任务树形结构

在数据库中给 `tasks` 表新增 `parent_id` 字段（自引用外键），通过 schema migration 从 v1 升级到 v2。

```
Task A (parent_id = null)      ← 根任务
  ├── Task A-1 (parent_id = A) ← 子任务
  │     ├── A-1-a (parent_id = A-1) ← 孙任务
  │     └── A-1-b (parent_id = A-1)
  └── Task A-2 (parent_id = A)
```

UI 上在任务详情页新增「子任务」区域，展示完整树形结构，支持：
- 展开/折叠节点
- 拖拽移动节点到其他父节点下
- 内联添加子任务
- 节点层级缩进

### 2.3 新旧关系

| 功能 | 本次变更 |
|------|----------|
| 检查项（checklist_items） | **不变**，与子任务共存 |
| 现有 tasks 表 | 新增 `parent_id` 列，不影响现有数据 |
| drift schema | v1 → v2（新增列 + 索引） |

---

## 三、范围

### 3.1 本次做

1. **数据库迁移**
   - Tasks 表新增 `parent_id TEXT REFERENCES tasks(id)`
   - 新增索引 `idx_tasks_parent_id`
   - schema 版本 1 → 2

2. **Repository 后端**
   - `getSubTasks(parentId)` → 直接子任务列表
   - `getDescendantTree(taskId)` → 递归获取所有后代（扁平列表 + 层级映射）
   - `moveTask(taskId, newParentId)` → 移动任务到新的父节点
   - `reorderSubTasks(parentId, orderedIds)` → 同级重排序

3. **UI：时间精度**
   - 任务创建 BottomSheet：日期选择后追加 TimePicker
   - 任务编辑全屏页：日期选择后追加 TimePicker
   - 任务卡片日期格式：`MM/dd HH:mm`
   - 详情页日期格式：`yyyy-MM-dd HH:mm`
   - 详情页信息区展示完整时间

4. **UI：子任务树（详情页内嵌）**
   - 详情页新增「子任务」区域
   - 树形展开/折叠视图（递归缩进）
   - 每个节点显示标题 + 完成状态 + 展开箭头
   - 内联添加子任务输入框
   - 拖拽手柄，拖拽改变父节点

5. **BLoC 事件**
   - `LoadSubTasks(taskId)` → 加载子任务树
   - `AddSubTask(parentId, title)` → 添加子任务
   - `MoveTask(taskId, newParentId)` → 拖拽移动
   - `ReorderSubTasks(parentId, orderedIds)` → 同级排序
   - `ToggleTaskInTree(id)` → 树中勾选完成

### 3.2 本次不做

- 子任务的甘特图/时间线视图
- 子任务批量操作（全选、批量移动）
- 子任务模板/预设
- 跨任务复制粘贴子任务
- 看板视图的层级展示

---

## 四、关键取舍

| 决策 | 选择 | 理由 |
|------|------|------|
| 数据库设计 | 自引用 parent_id | 无限递归的直接实现方式，查询时递归拉取 |
| 树渲染方式 | 递归组件（非扁平列表） | 保留树形语义，展开/折叠灵活 |
| 拖拽实现 | `LongPressDraggable` + `DragTarget` 自定义 | 比 ReorderableListView 更灵活，支持跨层级 |
| 拖拽触发 | 拖拽手柄图标 | 避免与左滑操作冲突 |
| 子任务与检查项 | 共存 | 子任务用于层级组织，检查项用于简单勾选 |

---

## 五、验收标准

1. ✅ 创建任务可选择日期+时间
2. ✅ 编辑任务可修改日期+时间
3. ✅ 任务列表卡片显示 `MM/dd HH:mm`
4. ✅ 任务详情页显示完整时间
5. ✅ 详情页可添加子任务（递归无限层级）
6. ✅ 子任务树可展开/折叠
7. ✅ 拖拽子任务可改变层级
8. ✅ 子任务完成勾选正常
9. ✅ 检查项功能不受影响
10. ✅ 数据库迁移不丢数据

---

## 六、风险与缓解

| 风险 | 等级 | 缓解措施 |
|------|------|----------|
| 递归查询深度过大影响性能 | 低 | 实际使用中层级不会太深，限制最大 10 层 |
| 拖拽交互复杂，实现成本高 | 中 | 先实现基本的拖拽到目标节点上/下/内部，不做动画对齐 |
| 数据库迁移失败丢数据 | 高 | 写迁移前备份，迁移失败回滚到 v1 仍可用（parent_id 列为空） |
