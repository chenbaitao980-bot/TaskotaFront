# 设计：task-management-redesign

## 一、数据库设计（drift）

### 1.1 数据库模块结构

```
lib/
  data/
    database/
      app_database.dart         -- drift Database 定义（含 Schema 和 Migration）
      database_config.dart      -- 数据库配置（路径、版本、初始化）
    repositories/
      project_repository.dart   -- Project CRUD
      task_repository.dart      -- Task CRUD + 筛选/排序
      checklist_repository.dart -- ChecklistItem CRUD
    models/
      project.dart              -- Project 数据类（drift companion）
      task.dart                 -- Task 数据类
      checklist_item.dart       -- ChecklistItem 数据类
```

### 1.2 projects 表

```sql
CREATE TABLE projects (
  id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#4772FA',
  sort_order INTEGER NOT NULL DEFAULT 0,
  archived INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
```

### 1.3 tasks 表

```sql
CREATE TABLE tasks (
  id TEXT NOT NULL PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id),
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  priority INTEGER NOT NULL DEFAULT 0,  -- 0: 无, 1: 低, 3: 中, 5: 高（滴答兼容）
  status INTEGER NOT NULL DEFAULT 0,    -- 0: 未完成, 2: 已完成（滴答兼容）
  start_date INTEGER,                   -- 毫秒时间戳
  due_date INTEGER,                     -- 毫秒时间戳
  is_all_day INTEGER NOT NULL DEFAULT 0,
  completed_time INTEGER,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_tasks_project_id ON tasks(project_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);
```

### 1.4 checklist_items 表

```sql
CREATE TABLE checklist_items (
  id TEXT NOT NULL PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id),
  title TEXT NOT NULL,
  status INTEGER NOT NULL DEFAULT 0,  -- 0: 未完成, 1: 已完成
  sort_order INTEGER NOT NULL DEFAULT 0,
  completed_time INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_checklist_items_task_id ON checklist_items(task_id);
```

### 1.5 drift 注解示例（参考）

```dart
// lib/data/database/app_database.dart
import 'package:drift/drift.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get color => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get archived => integer()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

---

## 二、Repository 设计

### 2.1 ProjectRepository

```
createProject({name, color, sortOrder}) → Project
updateProject(id, {name, color, sortOrder}) → void
deleteProject(id) → void
getProject(id) → Project?
getAllProjects() → List<Project>
getArchivedProjects() → List<Project>
```

### 2.2 TaskRepository

```
createTask({projectId, title, description, priority, startDate, dueDate}) → Task
updateTask(id, fields) → void
deleteTask(id) → void
getTask(id) → Task?
getTasks({projectId, status, priority, dateRange, search}) → List<Task>
toggleTaskStatus(id) → void
getTodayTasks() → List<Task>
getImportantTasks() → List<Task>  // priority == 5
reorderTasks(projectId, orderedIds) → void
```

### 2.3 ChecklistRepository

```
createItem({taskId, title}) → ChecklistItem
updateItem(id, {title}) → void
deleteItem(id) → void
getItems(taskId) → List<ChecklistItem>
toggleItem(id) → void
getCompletedCount(taskId) → int
```

### 2.4 类型映射（滴答兼容）

| 滴答字段 | 本系统字段 | 说明 |
|----------|-----------|------|
| projectId | projectId | 直接映射 |
| priority 0/1/3/5 | priority 0/1/3/5 | 兼容滴答优先级枚举 |
| status 0/2 | status 0/2 | 兼容滴答状态枚举 |
| items[] | checklist_items | 独立表，通过 taskId 关联 |
| tags | 无（一期不做） | 后续迭代 |
| reminders | 无（一期不做） | 后续迭代 |
| repeatFlag | 无（一期不做） | 后续迭代 |

---

## 三、UI 架构

### 3.1 导航结构

```
底部导航栏（5项）
├── 首页 (index 0)
├── 任务 (index 1)  ← NEW 独立模块
├── 日历 (index 2)  ← 不变，仍使用旧系统
├── AI助手 (index 3) ← 不变，仍使用旧系统
└── 我的 (index 4)

任务模块内部（TasksPage）
├── 左侧 Drawer：ProjectSidebar
│   ├── 快捷筛选：所有任务 / 今天 / 重要
│   └── 项目列表（动态）
└── 右侧主体：TaskListView
    ├── 未完成任务区（按 sort_order 排序）
    ├── 已完成任务区（默认折叠）
    └── FAB → 创建任务
```

### 3.2 页面文件结构

```
lib/presentation/pages/tasks/             ← 全新模块目录
  tasks_page.dart                          -- 任务主页（含 Drawer + 列表主体）
  widgets/
    project_sidebar.dart                   -- 项目侧边栏（Drawer）
    task_list_view.dart                    -- 任务列表主体
    task_card.dart                         -- 任务卡片（含滑动操作）
    task_create_sheet.dart                 -- 创建任务底部弹窗
    task_edit_page.dart                    -- 编辑任务全屏页
  task_detail/
    task_detail_page.dart                  -- 任务详情页
    widgets/
      checklist_section.dart               -- 检查项区域（展开/折叠）
      task_info_section.dart               -- 任务信息展示区

lib/presentation/blocs/
  task_new/                                ← 新版 TaskBloc（区别于旧版 task/）
    task_bloc.dart
    task_event.dart
    task_state.dart
```

### 3.3 交互设计要点

**任务列表页**
- 默认显示「所有任务」，按 `sort_order` 升序排列
- Drawer 切换项目筛选，选中项目高亮
- 未完成与已完成分区展示，已完成默认折叠收起
- 左滑卡片：显示「完成」和「删除」操作按钮
- 点击卡片：NavigatePush 进入任务详情页
- FAB 右下角：弹出创建任务 BottomSheet

**创建任务（BottomSheet）**
- 标题（必填，TextField 自动聚焦）
- 所属项目（Dropdown，默认当前选中项目）
- 优先级（芯片选择：无/低/中/高）
- 开始日期 + 截止日期（日期选择器）
- 描述（多行文本，选填）
- 底部「保存」按钮

**任务详情页**
- AppBar：任务标题 + 编辑/删除操作按钮
- 信息卡片：项目标签、优先级、日期范围、描述
- 检查项区域：标题「检查项」+ 进度 (N/M)
  - 新增输入框：输入后按回车添加
  - 列表项：复选框 + 标题文本 + 左滑删除
  - 点击文本可编辑
- 底部：完整编辑按钮（跳转编辑页）

**编辑任务页（全屏）**
- 与创建表单结构一致，预填当前值
- 底部「保存更改」按钮

### 3.4 滑动操作实现方案

使用 `flutter_slidable` 或自实现 `Dismissible`：
- 左滑：右侧出现「完成」(绿色) + 「删除」(红色) 按钮
- 点击完成：`TaskBloc.add(ToggleTaskStatus(taskId))`
- 点击删除：`TaskBloc.add(DeleteTask(taskId))`

### 3.5 BLoC 状态管理

```dart
// 事件
class LoadProjects extends TaskEvent {}
class CreateProject extends TaskEvent { final String name; ... }
class UpdateProject extends TaskEvent { final Project project; }
class DeleteProject extends TaskEvent { final String id; }

class LoadTasks extends TaskEvent { final String? projectId; }
class CreateTask extends TaskEvent { final ... }
class UpdateTask extends TaskEvent { final ... }
class DeleteTask extends TaskEvent { final String id; }
class ToggleTaskStatus extends TaskEvent { final String id; }
class ReorderTasks extends TaskEvent { final String projectId; final List<String> orderedIds; }

class CreateChecklistItem extends TaskEvent { final String taskId; final String title; }
class ToggleChecklistItem extends TaskEvent { final String id; }
class DeleteChecklistItem extends TaskEvent { final String id; }

// 状态
class TaskNewInitial extends TaskNewState {}
class TaskNewLoading extends TaskNewState {}
class TaskNewLoaded extends TaskNewState {
  final List<Project> projects;
  final List<Task> tasks;
  final String? selectedProjectId;
  final String? selectedFilter; // 'all' | 'today' | 'important'
}
class TaskNewError extends TaskNewState { final String message; }
```

---

## 四、底部导航改造

### 4.1 HomePage 调整

```dart
// 原有 4 项 → 扩展为 5 项
final _pages = [
  _HomeContent(),       // index 0: 首页
  TasksPage(),          // index 1: 任务（NEW）
  CalendarPage(),       // index 2: 日历
  AiChatPage(),         // index 3: AI助手
  ProfilePage(),        // index 4: 我的
];

final _navItems = [
  BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
  BottomNavigationBarItem(icon: Icon(Icons.checklist), label: '任务'),  // NEW
  BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '日历'),
  BottomNavigationBarItem(icon: Icon(Icons.smart_toy), label: 'AI助手'),
  BottomNavigationBarItem(icon: Icon(Icons.person), label: '我的'),
];
```

### 4.2 IndexedStack 兼容

HomePage 当前使用 `IndexedStack` 缓存页面状态，4→5 扩展只需增加一个索引。

---

## 五、依赖变更

```yaml
# pubspec.yaml 新增
dependencies:
  drift: ^2.x
  sqlite3_flutter_libs: ^0.x
  path_provider: ^2.x
  path: ^1.x
  flutter_slidable: ^3.x  # 滑动操作

dev_dependencies:
  drift_dev: ^2.x
  build_runner: ^2.x
```

---

## 六、不涉及的部分

本次改造**不涉及**以下模块，这些模块仍使用旧的 `TaskBreakdown` 和 `LocalStorageService`：

- `lib/presentation/pages/calendar/calendar_page.dart`
- `lib/presentation/pages/ai_chat/ai_chat_page.dart`
- `lib/presentation/pages/task/task_list_page.dart`（旧）
- `lib/presentation/pages/task/task_detail_page.dart`（旧）
- `lib/presentation/pages/task/create_task_page.dart`（旧）
- `lib/presentation/blocs/task/task_bloc.dart`（旧）
- `lib/services/local_storage_service.dart`（任务相关方法保留）
- `lib/services/supabase_service.dart`（任务相关方法保留）

---

## 七、回归测试方案

### 7.1 测试用例

1. 创建项目 → 项目出现在侧边栏
2. 创建任务（含标题/项目/优先级/日期）→ 任务出现在列表中
3. 编辑任务 → 保存后正确显示
4. 左滑删除任务 → 任务从列表消失
5. 勾选任务完成 → 任务移到已完成区
6. 添加检查项 → 出现在任务详情
7. 勾选检查项 → 显示已完成状态
8. 切换项目筛选 → 只显示该项目任务
9. 底部导航切换 → 任务Tab正常显示
10. 旧系统功能不受影响 → 日历/AI聊天/旧任务页正常运行

### 7.2 批量测试

```bash
# 新建模块的 drift 数据库测试
flutter test test/data/database_test.dart

# 确认旧功能不受影响
flutter test test/local_storage_service_test.dart
```
