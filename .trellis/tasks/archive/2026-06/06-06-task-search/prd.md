# 任务模块搜索功能

## Goal

在任务模块的任务列表页添加搜索功能，允许用户通过关键字快速筛选任务，提升多任务场景下的查找效率。

## What I already know

- 主任务模块为 `TasksPage`（`lib/presentation/pages/tasks/tasks_page.dart`），使用 `TaskNewBloc` 管理状态
- 任务列表视图为 `TaskListView`（`lib/presentation/pages/tasks/widgets/task_list_view.dart`）和 `MindMapView`
- 已有过滤功能：状态筛选、项目筛选、日期筛选、排除项目
- **没有**关键字搜索功能
- 任务模型（`Tasks` 表）字段：id, projectId, parentId, title, description, priority, status, startDate, dueDate, ...
- 数据层：`TaskRepository` → SQLite (drift)
- Bloc 事件通过 `TaskEvent` 派发，状态通过 `TaskNewState` 管理

## Requirements (evolving)

- [ ] 在任务列表页的 AppBar 添加搜索图标入口
- [ ] 点击图标触发 SearchDelegate 搜索界面
- [ ] 搜索覆盖 标题 + 描述 + 检查项标题
- [ ] 通过数据库查询实现搜索（TaskRepository 新增 searchTasks）
- [ ] 搜索结果显示实时（用户输入时带防抖过滤）
- [ ] 搜索应尊重当前已有的筛选条件（项目、状态、日期等）

## Technical Approach

- 在 `TaskRepository` 新增 `searchTasks(keyword, ...)` 方法，使用 SQL LIKE 查询
- 在 `TaskEvent` 新增 `SetSearchQuery` 事件，携带搜索关键词
- 在 `TaskNewState` 新增 `searchKeyword` 字段
- 当 SearchDelegate 中输入关键词时，emit 搜索事件，Bloc 重新筛选任务列表
- 搜索与现有过滤条件叠加（项目、状态、日期等）

## Decision (ADR-lite)

**Context**: 需要确定搜索覆盖哪些字段
**Decision**: 搜索范围覆盖 标题 + 描述 + 检查项标题
**Consequences**: 搜索更全面，但需要额外的数据库查询来搜索检查项（因为检查项不是默认预加载的）

**Context**: 搜索实现方式
**Decision**: 数据库查询搜索，在 TaskRepository 新增 searchTasks 方法
**Consequences**: 搜索全面且可扩展，需要处理查询防抖

**Context**: 搜索入口位置
**Decision**: AppBar 搜索图标 + SearchDelegate 全屏搜索界面
**Consequences**: Flutter 标准模式，用户熟悉，交互流畅

## Out of Scope

- 搜索结果的排序优化（按相关性排序暂不考虑）
- 全文搜索引擎（如 FTS5）

## Technical Notes

### 已检查的文件

| 文件 | 作用 |
|------|------|
| `lib/presentation/pages/tasks/tasks_page.dart` | 主任务页面，包含 AppBar 和各种筛选按钮 |
| `lib/presentation/pages/tasks/widgets/task_list_view.dart` | 任务列表视图（树形） |
| `lib/presentation/pages/tasks/widgets/task_card.dart` | 任务卡片组件 |
| `lib/presentation/blocs/task_new/task_event.dart` | TaskNewBloc 事件定义 |
| `lib/presentation/blocs/task_new/task_state.dart` | TaskNewBloc 状态定义 |
| `lib/presentation/blocs/task_new/task_bloc.dart` | TaskNewBloc 实现 |
| `lib/data/repositories/task_repository.dart` | 任务数据仓库 |
| `lib/data/database/app_database.dart` | 数据库表定义 |

### 数据流

```
TasksPage
  → AppBar 搜索图标 → SearchDelegate
  → SetSearchQuery(keyword) event → TaskNewBloc
  → TaskRepository.searchTasks(keyword, projectId, status, ...)
  → SQLite LIKE 查询（title + description + checklist_items）
  → 返回匹配的 task ids → Bloc 更新 state
  → TasksPage → TaskListView/MindMapView 渲染
```
