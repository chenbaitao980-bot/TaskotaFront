# 设计：home-quadrant-task-navigation

## 需求澄清依据
1. 首页四象限点击任务→时间轴定位到该节点；详情子任务点击→切换子任务详情+时间轴定位；父任务展示+点击切回
2. 时间轴默认从天维度改为当天24小时维度，支持天/小时切换，两种模式均可左右滑动

## 方案

### 总体架构
所有改动集中在 `_HomeContent` 组件内，不涉及其他页面和数据层。

### 1. _TimelineTask增加parentId
新增 `String? parentId` 字段，`_loadData()` 中从 `Task.parentId` 赋值。

### 2. 时间轴天/小时视图切换

**状态**：
- `_timelineMode`: `'day'` | `'hour'` （默认 `'hour'`）
- `_timelineDate`: 当天日期（小时视图锚点）

**天视图**（保留现逻辑）：
- `_dayWidth = 72.0`，前后各 180 天
- 按日分列，任务以圆点展示

**小时视图**（新增）：
- 当天 24 小时，每小时一列
- `_hourWidth = 120.0`（更宽以显示时间文字）
- 每列显示该小时内的任务
- 任务按 `date.hour` 定位到对应小时列
- 无小时信息的任务放在"全天"区域

**切换按钮**：
- 时间轴左上角或右上角加 `SegmentedButton` 或 `ToggleButtons`
- 天/小时切换，切换时保留当前滚动位置

### 3. 四象限点击任务选中 + 时间轴滚动
`_buildQuadrant()` 任务项包裹 `GestureDetector`：
- `_selectTask(task)` 切换选中
- `_scrollToTask(task)` 滚动时间轴（天模式滚日期偏移，小时模式滚小时偏移）

### 4. 子任务点击切换 + 时间轴滚动
`_buildSubtaskTree()` 子任务行加 `GestureDetector`：
- 在 `_timelineTasks` 中查找匹配 `taskId` 的子任务
- 找到则 `_selectTask` + 时间轴滚动
- 找不到时从 repository 加载并构建临时 `_TimelineTask`

### 5. 父任务展示和点击切换
`_buildTaskDetail()` 顶部：
- 选中任务有 `parentId` 时，title 上方显示父任务名（带返回箭头图标）
- 从 `_timelineTasks` 查找或 repository 加载
- 点击后 `_selectTask(parentTask)` + 时间轴滚动

## 关键取舍
- 不新增页面，所有交互在 `_HomeContent` 内完成
- 小时视图只显示当天，不显示前后日期
- 左右滑动通过 ListView 水平滚动实现（与天视图一致）

## 回归测试
- 用例文件：`regression-tests/cases/home-quadrant-task-navigation.md`
- 运行记录：`regression-tests/runs/home-quadrant-task-navigation.json`
