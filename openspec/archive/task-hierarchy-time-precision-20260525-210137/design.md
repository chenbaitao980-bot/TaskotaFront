# 设计：task-hierarchy-time-precision

## 一、数据库变更

### 1.1 schema 版本 2 迁移

```sql
-- tasks 表新增 parent_id 列
ALTER TABLE tasks ADD COLUMN parent_id TEXT REFERENCES tasks(id);
CREATE INDEX idx_tasks_parent_id ON tasks(parent_id);
```

### 1.2 drift 表定义变更

```dart
// app_database.dart 在 Tasks 表中新增
IntColumn? get parentId => integer().nullable()();  // 注意：drift 不支持自引用外键，用 integer 手动管理
```

> 注意：因 drift 不支持自引用 `REFERENCES` 约束，`parent_id` 使用 `integer().nullable()` 存储任务 ID（Text）。TODO 使用多个索引类型，但这里都用 TEXT 存储 UUID。

### 1.3 迁移实现

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration {
  return MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // 创建默认项目
      await into(projects).insert(ProjectsCompanion(...));
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tasks, tasks.parentId);
      }
    },
  );
}
```

---

## 二、Repository 变更

### 2.1 TaskRepository 新增方法

```dart
// 获取直接子任务
Future<List<Task>> getSubTasks(String parentId);

// 递归获取所有后代（扁平列表）
Future<List<Task>> getDescendants(String taskId);

// 构建层级映射：{parentId: [child, child, ...]}
Future<Map<String?, List<Task>>> getTreeMap(String rootTaskId);

// 移动任务到新父节点
Future<void> moveTask(String taskId, String? newParentId);

// 同级重排序
Future<void> reorderSubTasks(String parentId, List<String> orderedIds);
```

### 2.2 递归查询实现

```dart
Future<List<Task>> getDescendants(String taskId) async {
  final result = <Task>[];
  var currentLevel = await getSubTasks(taskId);
  while (currentLevel.isNotEmpty) {
    result.addAll(currentLevel);
    final nextLevel = <Task>[];
    for (final task in currentLevel) {
      nextLevel.addAll(await getSubTasks(task.id));
    }
    currentLevel = nextLevel;
  }
  return result;
}
```

---

## 三、BLoC 变更

### 3.1 新增事件

```dart
class LoadSubTree extends TaskEvent { final String rootTaskId; }

class AddSubTask extends TaskEvent { 
  final String parentId; 
  final String title; 
}

class MoveSubTask extends TaskEvent {
  final String taskId;
  final String? newParentId;
}

class ToggleSubTask extends TaskEvent { final String id; }
```

### 3.2 新增状态字段

```dart
class TaskNewLoaded extends TaskNewState {
  // ...原有字段
  final Map<String, List<Task>> subTrees; // rootTaskId -> flattened tree list
  final Map<String, Set<String>> expandedNodes; // rootTaskId -> expanded node ids
}
```

---

## 四、UI 设计

### 4.1 时间精度

**创建任务 BottomSheet**（task_create_sheet.dart）
- 「开始日期」按钮 → DatePicker → 选完后 → TimePicker
- 「截止日期」按钮 → DatePicker → 选完后 → TimePicker

**编辑任务页**（task_edit_page.dart）同上。

**任务卡片**（task_card.dart）
```dart
// 原：_formatDate(timestamp) → "今天" / "MM/dd"
// 改为：_formatDateTime(timestamp) → "今天 14:30" / "05/25 14:30"
```

**详情页信息区**（task_info_section.dart）
```dart
// 原：_formatDateRange(start, end) → "2026-05-25 → 2026-05-26"
// 改为：_formatDateTimeRange(start, end) → "2026-05-25 09:00 → 2026-05-26 18:00"
```

### 4.2 子任务树（详情页内嵌）

在 `task_detail_page.dart` 新增子任务区域，位于检查项区域上方或下方：

```
┌─ 任务详情页 ─────────────────────────────────┐
│  标题  [已完成]                                │
│  任务信息（项目/优先级/日期/描述）               │
│                                                │
│  ── 子任务 ── [+]                             │
│  📁 子任务A  [▾] ☐                            │
│  │   📄 A-1  [✓]  ↕                          │
│  │   📄 A-2  [☐]  ↕                          │
│  📁 子任务B  [▾] ☑                            │
│  │   📄 B-1  [☐]  ↕                          │
│  │   📄 B-2  [☐]  ↕                          │
│  📝 输入子任务名称... →                         │
│                                                │
│  ── 检查项 ── 2/5                             │
│  ☐ 检查项1                                     │
│  ☑ 检查项2                                     │
└────────────────────────────────────────────────┘
```

### 4.3 树组件实现方案

使用自定义 `SubTaskTreeSection` 组件：

```dart
class SubTaskTreeSection extends StatelessWidget {
  // 扁平的任务列表
  final List<Task> tasks;
  // 层级映射
  final Map<String?, List<Task>> treeMap;
  // 展开状态
  final Set<String> expandedIds;
  // 根任务ID
  final String rootTaskId;
}
```

每个节点渲染逻辑：
1. 根据 `parentId` 确定层级深度，计算左边距缩进
2. 如果有子节点 → 显示展开/折叠箭头（▾/▸）
3. 显示拖拽手柄（↕），长按启动拖拽
4. 显示标题 + 完成复选框

### 4.4 拖拽排序实现

使用 `LongPressDraggable` + `DragTarget`：

1. 每个任务行的拖拽手柄触发 `LongPressDraggable`
2. 每个任务行也是 `DragTarget`，接收拖入
3. 拖入位置判断：
   - 拖到目标**上方** → 成为同级的上一个
   - 拖到目标**内部**（缩进区域）→ 成为子任务
   - 拖到目标**下方** → 成为同级的下一个
4. 释放后调用 `MoveSubTask(taskId, newParentId)`

---

## 五、文件变更清单

### 修改文件

| 文件 | 变更 |
|------|------|
| `lib/data/database/app_database.dart` | Tasks 表加 parent_id 列，schema v1→v2 迁移 |
| `lib/data/repositories/task_repository.dart` | 新增 getSubTasks/getDescendants/moveTask/reorder |
| `lib/presentation/blocs/task_new/task_event.dart` | 新增 LoadSubTree/AddSubTask/MoveSubTask/ToggleSubTask |
| `lib/presentation/blocs/task_new/task_bloc.dart` | 新增对应 handler，state 加 subTrees/expandedNodes |
| `lib/presentation/blocs/task_new/task_state.dart` | 新增 subTrees/expandedNodes 字段 |
| `lib/presentation/pages/tasks/widgets/task_create_sheet.dart` | 日期选择后加时间选择 |
| `lib/presentation/pages/tasks/widgets/task_edit_page.dart` | 日期选择后加时间选择 |
| `lib/presentation/pages/tasks/widgets/task_card.dart` | 日期显示改为包含时间 |
| `lib/presentation/pages/tasks/task_detail/widgets/task_info_section.dart` | 日期显示改为含时间 |
| `lib/presentation/pages/tasks/task_detail/task_detail_page.dart` | 新增子任务树区域 |

### 新增文件

| 文件 | 说明 |
|------|------|
| `lib/presentation/pages/tasks/task_detail/widgets/subtask_tree_section.dart` | 子任务树组件 |

---

## 六、回归测试方案

### 测试用例

1. 创建任务时选择日期+时间 → 保存后显示正确
2. 编辑任务修改时间 → 卡片和详情页时间更新
3. 在详情页添加子任务 → 出现在树中
4. 添加多层子任务（A→B→C）→ 树形正确展开
5. 展开/折叠子任务 → 子节点显示/隐藏
6. 拖拽移动子任务到其他父节点 → 层级更新
7. 勾选子任务完成 → 状态更新
8. 检查项功能不受影响 → 正常勾选/删除
