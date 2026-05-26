# Delta: task-tree-drag-reorder

## 与主规范关系
New Capability — 任务列表树形视图 + 拖拽操作

## 命中的主规范
- Capability: `task-tree-drag-reorder`
- Requirement: 主任务列表须以树形结构展示任务父子层级关系
- Scenario: 用户在任务列表页查看任务时，可直观看到任务的父子从属关系

## 变更类型
ADDED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无（新增能力） |
| 关系判断 | 新增 |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是 |
| 归档完整性 | ✅ |

## 原规则
无 — 主任务列表为平铺展示，`TaskListView` 使用 `ListView(children: [pendingTasks, completedTasks])` 按状态分组卡片。

## 新规则

### Requirement: 主列表树形展示
主任务列表 SHALL 以树形结构展示所有未完成任务，根任务（parentId == null）平级展示，子任务缩进显示。已完成任务保持现有折叠区域，不参与树形展示。

#### Scenario: 查看任务层级
- **GIVEN** 用户有任务 A（2 个子任务 A1, A2）和任务 B（无子任务）
- **WHEN** 用户打开任务列表
- **THEN** 任务 A 显示在任务 B 前方（或按 sortOrder），A1、A2 在 A 下方缩进显示，B 与 A 同级

#### Scenario: 展开/折叠节点
- **GIVEN** 任务 A 有子任务 A1、A2，当前展开状态
- **WHEN** 用户点击任务 A 的折叠箭头
- **THEN** A1、A2 在列表中隐藏，A 的箭头变为 `▶`
- **WHEN** 用户再次点击展开箭头
- **THEN** A1、A2 重新显示，箭头变为 `▼`

#### Scenario: 空子任务不显示箭头
- **GIVEN** 任务 A 无子任务
- **WHEN** 渲染任务 A 的树节点
- **THEN** 不显示展开/折叠箭头，仅显示占位空白

### Requirement: 树形列表拖拽操作
任务列表 SHALL 支持通过拖拽调整任务的父级关系和同级排序。

#### Scenario: 拖拽子任务成为其他任务的子任务
- **GIVEN** 任务 A 的子任务 A1，以及任务 B
- **WHEN** 用户拖拽 A1 的拖拽手柄，放到 B 上
- **THEN** A1 的 parentId 变为 B 的 id，A1 从 A 的子节点列表消失，变为 B 的子节点

#### Scenario: 拖拽子任务移为根任务
- **GIVEN** 任务 A 的子任务 A1
- **WHEN** 用户拖拽 A1 到列表顶部的"移为根任务"区域
- **THEN** A1 的 parentId 变为 null，A1 从 A 下消失，成为独立的根级任务

#### Scenario: 同级拖拽排序
- **GIVEN** 任务 A 有子任务 A1 (sortOrder=0)、A2 (sortOrder=1)
- **WHEN** 用户拖拽 A1 放到 A2 后方
- **THEN** A1.sortOrder 更新为 ≥ A2.sortOrder，列表重排

#### Scenario: 不能拖拽到自己身上
- **GIVEN** 任务 A
- **WHEN** 用户拖拽 A 放到 A 自身上
- **THEN** 无操作，不触发任何事件

#### Scenario: 拖拽反馈
- **GIVEN** 用户正在拖拽任务 X
- **WHEN** X 悬停在可放置目标上方
- **THEN** 目标节点高亮（背景色变为 primaryColor 8% 透明度 + 边框）
- **WHEN** X 离开或放下
- **THEN** 高亮消失

### Requirement: 筛选兼容
树形展示 SHALL 在所有筛选条件下正确工作。

#### Scenario: 按项目筛选时树形正确
- **GIVEN** 用户在项目 P 下
- **WHEN** taskRepository.getByProject('P') 返回任务列表
- **THEN** 树形结构仅在项目 P 的任务内构建，不跨项目

#### Scenario: 今天/重要筛选
- **GIVEN** 用户选择"今天"或"重要"筛选
- **WHEN** 返回的任务列表包含父子关系
- **THEN** 树形结构在筛选结果内正确展示

## 改动明细
- 文件：`lib/presentation/pages/tasks/widgets/task_list_view.dart` — 核心重构
- 文件：`lib/presentation/pages/tasks/widgets/task_card.dart` — 新增缩进/展开/拖拽属性
- 文件：`lib/presentation/pages/tasks/tasks_page.dart` — 新增回调
- 文件：`lib/presentation/blocs/task_new/task_event.dart` — 新增 3 个事件
- 文件：`lib/presentation/blocs/task_new/task_state.dart` — expandedNodes 初始化
- 文件：`lib/presentation/blocs/task_new/task_bloc.dart` — 新增 3 个 handler
- 文件：`regression-tests/cases/task-tree-drag-reorder.md` — 回归用例
