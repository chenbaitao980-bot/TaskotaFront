# Delta: task-hierarchy-time-precision

## 与主规范关系
Added to existing `task-management-redesign`

## 命中的主规范
- Capability: `task-management-redesign`
- Requirement: 任务 CRUD
- Scenario: 追加

## 变更类型
追加 Scenario

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 任务 CRUD |
| 关系判断 | 追加 Scenario |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否（追加 Scenario） |
| 归档完整性 | ✅ |

## 原规则
一次完整的任务创建/编辑流程

## 新规则

### Requirement: 任务时间精度

#### Scenario: 创建任务时设置精确时间
- Given 用户在创建任务 BottomSheet 或编辑页
- When 用户点击「开始日期」
- Then 弹出 DatePicker
- When 用户选择日期
- Then 自动弹出 TimePicker 让选择时分
- When 用户确认时间
- Then 日期按钮显示 `MM/dd HH:mm` 格式
- When 用户保存任务
- Then 任务的时间精确到分钟保存

#### Scenario: 任务卡片显示时间
- Given 任务列表有带时间的任务
- Then 卡片上显示 `MM/dd HH:mm` 格式
- And 今天/明天等语义化标签仍然保留

#### Scenario: 详情页显示完整时间
- Given 用户打开任务详情
- Then 信息区显示 `yyyy-MM-dd HH:mm` 完整时间格式

### Requirement: 子任务树

#### Scenario: 添加子任务
- Given 用户在任务详情页
- When 用户在「子任务」区域输入子任务名称并提交
- Then 新子任务出现在树中，作为当前任务的直接子节点
- And 如果当前任务之前没有子任务，自动展开

#### Scenario: 多层递归子任务
- Given 任务 A 有子任务 A-1
- When 进入 A-1 的详情页或直接在 A 的树中
- And 给 A-1 添加子任务 A-1-a
- Then A-1-a 出现在树中，缩进在 A-1 下
- And 支持的层级深度无限制（实际限制 10 层）

#### Scenario: 展开/折叠子树
- Given 树中某个任务有子任务
- When 点击节点的展开箭头（▸）
- Then 子节点展开显示
- When 再次点击折叠箭头（▾）
- Then 子节点折叠隐藏

#### Scenario: 拖拽移动子任务
- Given 树中存在多个子任务
- When 用户长按节点拖拽手柄
- Then 节点可被拖动
- When 拖到另一个节点上方/内部/下方
- Then 该节点被移动到目标位置
- And 更新层级关系（可能变更父节点）

#### Scenario: 勾选子任务完成
- Given 树中存在子任务
- When 用户点击子任务前的复选框
- Then 子任务状态切换完成/未完成
- And 树中实时更新

## 改动明细

### 修改文件
- `lib/data/database/app_database.dart` — Tasks 表加 parent_id，schema v2 迁移
- `lib/data/repositories/task_repository.dart` — 新增子任务树方法
- `lib/presentation/blocs/task_new/task_event.dart` — 新增树操作事件
- `lib/presentation/blocs/task_new/task_bloc.dart` — 新增树操作 handler
- `lib/presentation/blocs/task_new/task_state.dart` — 新增 subTrees 状态
- `lib/presentation/pages/tasks/widgets/task_card.dart` — 时间格式含时分
- `lib/presentation/pages/tasks/widgets/task_create_sheet.dart` — 追加 TimePicker
- `lib/presentation/pages/tasks/widgets/task_edit_page.dart` — 追加 TimePicker
- `lib/presentation/pages/tasks/task_detail/widgets/task_info_section.dart` — 时间格式含时分
- `lib/presentation/pages/tasks/task_detail/task_detail_page.dart` — 插入子任务树区域

### 新增文件
- `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart`
