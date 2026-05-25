# Capability Spec：AI 计划时间线与 WBS 思维导图

## Capability ID
`plan-timeline-mindmap-fix`

## 所属变更
`plan-timeline-mindmap-fix`

## 概述
AI 生成训练/学习计划后，在聊天界面中提供：具有正确时间约束的时间线视图（取代原来的"思维导图"流程图），以及展示任务层次结构的 WBS 思维导图。

## 变更类型
- ADDED：WBS 任务分解思维导图（新能力）
- MODIFIED：流程图 → 时间线（重命名+UI重构）
- MODIFIED：时间约束解析（Prompt + 后处理）
- MODIFIED：计划表时间格式（开始/结束合并到同一行）

## 前置条件
- AI 已经生成了包含 `[TABLE_BEGIN]...[TABLE_END]` 标记的计划回复
- 计划数据已通过 `_extractEditablePlanRows` 解析为 `_PlanRow` 列表

## 场景

### SC-01：时间约束生效
**Given** 用户输入"只在早上踢球并且只在这周踢球"
**When** AI 生成训练计划
**Then** 所有计划行的开始日期 ≤ 本周日（当前周的周日）

### SC-02：标签显示为"时间线"
**Given** AI 聊天界面展示了计划视图
**Then** 原"思维导图"标签显示为"时间线"

### SC-03：时间线正确排序
**Given** 计划存在多个行，部分行有特定时间/日期
**When** 用户查看时间线
**Then** 所有节点按 start 时间升序排列（从上到下）

### SC-04：时间线 UI 为横向紧凑布局
**Given** 用户展开时间线视图
**Then** 节点以横向时间轴样式排列，可水平滚动，每节点 ≤ 160×56px

### SC-05：WBS 思维导图展示任务树
**Given** 计划视图已渲染
**Then** 在"一键分配任务"按钮下方显示"任务分解"区域
**And** 按 `stage` 分组，展示为树形结构（根节点→阶段→任务项）

### SC-06：WBS 可展开折叠
**Given** WBS 思维导图已显示
**When** 用户点击阶段节点
**Then** 该阶段下的子任务展开或收起

### SC-07：无显式日期时截断到本周
**Given** 计划行没有 AI 提供的显式日期（使用 `_defaultPlanStart` 回退）
**When** `_defaultPlanStart` 计算的日期超出本周日
**Then** 该日期被截断到本周日的 23:59

### SC-08：计划表时间同排显示
**Given** 计划表已渲染
**Then** 每行的开始时间和结束时间合并为同一行展示
**And** 格式为 `MM-dd HH:mm ~ HH:mm`（同日）或 `MM-dd HH:mm ~ MM-dd HH:mm`（跨日）
**And** 仍可点击编辑

## 接口

### 新增 Widget
```dart
Widget _buildTimelineView(List<_PlanRow> rows)  // 取代 _buildScreenshotPlanFlow
Widget _buildWBSMindMap(List<_PlanRow> rows)    // 新增 WBS 组件
```

### 新增工具方法
```dart
DateTime _clampToThisWeek(DateTime date)  // 截断日期到本周日
```

### 修改方法
```dart
DateTime _defaultPlanStart(int index)     // 内部添加 _clampToThisWeek 调用
```

## 数据流

```
AI 回复 → _extractEditablePlanRows → List<_PlanRow>
  ├─ _buildPlanTable              → 可编辑计划表
  ├─ _buildTimelineView           → 时间线（纵向排序）
  └─ _buildWBSMindMap             → WBS 树状图
```

## 错误处理

| 条件 | 行为 |
|---|---|
| 计划行为空列表 | 时间线/WBS不渲染，显示"暂无计划数据" |
| 所有行 start 相同 | 按原始顺序展示 |
| WBS 分组数 > 10 | 只展开前 5 个阶段，其余折叠 |
