# Delta: task-management-redesign

## 与主规范关系
New Capability

## 命中的主规范
- Capability: `task-management-redesign`
- Requirement: 任务管理（CRUD + 项目分组 + 检查项）

## 变更类型
ADDED

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无 |
| 关系判断 | 新增 |
| 其他 active change 撞车 | 无 |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 是 |
| 归档完整性 | ✅ |

## 原规则
无（全新独立模块，与旧 TaskBreakdown 系统并行运行）

## 新规则

### Requirement: 项目管理

用户可创建和管理任务项目（分组容器），用于组织相关任务。

#### Scenario: 创建项目
- Given 用户在任务页的侧边栏
- When 用户点击「新建项目」
- Then 弹出项目名称输入框
- And 用户输入名称并确认
- Then 新项目出现在侧边栏列表

#### Scenario: 编辑项目
- Given 侧边栏存在项目列表
- When 用户长按一个项目
- Then 弹出操作菜单（编辑/归档/删除）
- When 用户选择编辑
- Then 弹出编辑项目名称对话框

#### Scenario: 删除项目
- Given 侧边栏存在项目列表
- When 用户长按项目并选择删除
- Then 项目被删除
- And 该项目下的任务自动移至默认「未分类」项目

#### Scenario: 归档项目
- Given 侧边栏存在项目列表
- When 用户长按一个项目并选择归档
- Then 项目从活跃列表中消失
- And 归档到「已归档」区域

### Requirement: 任务 CRUD

用户可创建、查看、编辑、删除任务，任务归属于项目。

#### Scenario: 创建任务（快速）
- Given 用户在任务列表页
- When 用户点击右下角 FAB
- Then 弹出创建任务 BottomSheet
- And 必填项：标题
- And 选填项：所属项目、描述、优先级、开始日期、截止日期
- And 用户可立即添加检查项
- When 用户点击保存
- Then 新任务出现在任务列表中

#### Scenario: 查看任务详情
- Given 任务列表中有任务
- When 用户点击任务卡片
- Then 跳转至任务详情页
- And 显示标题、描述、优先级、日期、所属项目
- And 显示检查项列表及完成进度（如 N/M）

#### Scenario: 编辑任务
- Given 用户在任务详情页
- When 用户点击编辑按钮
- Then 进入编辑全屏页，预填当前值
- When 用户修改字段并保存
- Then 更新生效，列表页同步刷新

#### Scenario: 删除任务
- Given 任务列表或详情页
- When 用户左滑卡片点击删除，或详情页点击删除按钮
- Then 任务被永久删除

#### Scenario: 完成任务
- Given 任务列表或详情页
- When 用户点击任务复选框
- Then 任务状态变为已完成
- And 记录完成时间
- And 任务自动移至已完成区域

#### Scenario: 按项目筛选任务
- Given 任务列表页
- When 用户在侧边栏点击一个项目
- Then 列表只显示该项目下的任务
- When 用户点击「所有任务」
- Then 显示所有活跃项目的任务

#### Scenario: 按日期/优先级筛选
- Given 任务列表页
- When 用户在侧边栏点击「今天」
- Then 显示截止日期为今天的任务
- When 用户点击「重要」
- Then 显示高优先级（P5）任务

### Requirement: 检查项管理

用户可在任务详情页管理子任务/检查项。

#### Scenario: 添加检查项
- Given 用户在任务详情页
- When 用户在检查项输入框中输入并提交
- Then 新检查项添加到列表末尾

#### Scenario: 勾选检查项
- Given 任务详情页存在检查项
- When 用户点击检查项的复选框
- Then 检查项标记为已完成
- And 记录完成时间
- And 检查项区进度更新

#### Scenario: 编辑检查项
- Given 任务详情页存在检查项
- When 用户点击检查项的文本
- Then 进入编辑模式
- When 用户修改标题并确认
- Then 检查项标题更新

#### Scenario: 删除检查项
- Given 任务详情页存在检查项
- When 用户左滑检查项
- Then 显示删除按钮
- When 用户点击删除
- Then 检查项被删除

### Requirement: 导航与访问

#### Scenario: 底部导航访问任务模块
- Given 用户在应用任意页面
- When 点击底部导航的「任务」Tab
- Then 进入任务管理主页
- And 侧边栏和任务列表正确加载

## 改动明细

### 新增文件

```
lib/data/database/app_database.dart
lib/data/database/database_config.dart
lib/data/repositories/project_repository.dart
lib/data/repositories/task_repository.dart
lib/data/repositories/checklist_repository.dart
lib/data/models/project.dart
lib/data/models/task.dart
lib/data/models/checklist_item.dart
lib/presentation/blocs/task_new/task_bloc.dart
lib/presentation/blocs/task_new/task_event.dart
lib/presentation/blocs/task_new/task_state.dart
lib/presentation/pages/tasks/tasks_page.dart
lib/presentation/pages/tasks/widgets/project_sidebar.dart
lib/presentation/pages/tasks/widgets/task_list_view.dart
lib/presentation/pages/tasks/widgets/task_card.dart
lib/presentation/pages/tasks/widgets/task_create_sheet.dart
lib/presentation/pages/tasks/widgets/task_edit_page.dart
lib/presentation/pages/tasks/task_detail/task_detail_page.dart
lib/presentation/pages/tasks/task_detail/widgets/checklist_section.dart
lib/presentation/pages/tasks/task_detail/widgets/task_info_section.dart
```

### 修改文件

```
lib/presentation/pages/home/home_page.dart    -- 底部导航新增任务Tab (4→5)
pubspec.yaml                                  -- 添加 drift 等依赖
lib/main.dart                                 -- 注入新 TaskBloc 和数据库
```

### 本次不修改（保留旧系统）

```
lib/models/entities/task_breakdown.dart       -- 保留，供日历/AI聊天使用
lib/services/local_storage_service.dart       -- 保留任务方法
lib/services/supabase_service.dart            -- 保留任务方法
lib/presentation/blocs/task/                  -- 保留旧 task_bloc
lib/presentation/pages/task/                  -- 保留旧任务页面
lib/presentation/pages/calendar/             -- 不涉及
lib/presentation/pages/ai_chat/               -- 不涉及
lib/core/router/app_router.dart               -- 不涉及（新页面独立导航）
```
