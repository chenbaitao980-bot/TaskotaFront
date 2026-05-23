# 设计：fix-task-schedule-interaction

## 当前状态

### 问题 1：首页日程列表无编辑入口
`home_page.dart` 的 `_buildRecentSchedules()` 中日程列表项：
```dart
onTap: onCreateSchedule,  // 调用 _createSchedule() → 弹出新建对话框
```
点击已有日程无法编辑，只能新建。HomePage 没有 `_editSchedule` 方法，但 CalendarPage 中已有完整的编辑流程（调用 `CreateScheduleDialog(isEditing: true)` 和 `_storage.updateSchedule()`）。

### 问题 2：日历默认月视图
`calendar_page.dart:26`：`_calendarFormat = CalendarFormat.month`。
主 spec 规定「默认展示月视图」，用户要求改为默认周视图。

### 问题 3：任务列表缺少新建和编辑入口
`task_list_page.dart` 的 `_TaskCard` 中 `PopupMenuButton` 只有：
- 设为待办 / 设为进行中 / 设为已完成 / 删除
缺少「编辑」选项。同时页面没有新建任务按钮。

## 方案

### 修复 1：首页日程列表编辑入口
- 在 HomePage 中新增 `_editSchedule(dynamic schedule)` 方法，复用 `CreateScheduleDialog(isEditing: true)` 模式
- 在 HomePage 中新增 `_deleteSchedule(dynamic schedule)` 方法
- 修改 `_buildRecentSchedules` 中日程列表项的 `onTap`：从 `onCreateSchedule` 改为调用 `_editSchedule`
- 添加 `PopupMenuButton` 在日程卡片 trailing 位置，提供编辑/删除选项

### 修复 2：日历默认周视图
- `_calendarFormat` 初始值改为 `CalendarFormat.week`
- `_didAutoScrollWeek = false`（已有字段，修改初始模式后自动滚动时间线到当前时间）
- MODIFIED 主 spec：日历 view 场景中「默认展示月视图」改为「默认展示周视图」

### 修复 3：任务列表新建和编辑入口
- `TaskListPage` 添加 FAB：`FloatingActionButton(onPressed: _createTask, child: Icon(Icons.add))`
- `_TaskCard` 的 `PopupMenuButton` 中添加「编辑」选项，导航到 `CreateTaskPage(existingTask: task)`
- 新增 `_createTask()` 方法导航到 `CreateTaskPage()`（无 existingTask 即新建模式）
- 新增 `_editTask(TaskBreakdown task)` 方法导航到 `CreateTaskPage(existingTask: task)`

## 业务规则处理
| 问题 | 原 Spec | 处理方式 | 原因 |
|------|---------|---------|------|
| 日历默认视图 | THEN 默认展示月视图 | MODIFIED → 默认展示周视图 | 用户明确要求 |
| 首页日程编辑 | Scenario: 编辑/删除日程（已规定但首页未实现） | 不改 spec，补全 UI | Spec Gap，spec 已覆盖此行为 |
| 任务列表编辑 | 无明确 spec 覆盖 | 不改 spec，补全 UI | UI 细节，不影响业务规则 |

## 历史 BugFixSpecs 命中
- 命中文件：无
- 与 `auth/register-click-no-response.md` 无关（认证域 vs 日程/任务 UI 域）

## 回归测试方案
- 用例文件：`regression-tests/cases/fix-task-schedule-interaction.md`
- 手动验证用例：
  1. 首页今日日程列表点击 → 弹出编辑对话框（标题/时间/优先级可修改）
  2. 切换到日历 Tab → 默认展示周视图
  3. 任务列表页 → 右下角有新建按钮
  4. 任务列表页 → 任务卡片三点菜单含「编辑」选项

## 回滚方案
- 还原 `home_page.dart` 日程列表 `onTap` 为 `onCreateSchedule`
- 还原 `calendar_page.dart` `_calendarFormat` 为 `CalendarFormat.month`
- 还原 `task_list_page.dart` 移除新增的 FAB 和编辑菜单项
- 还原主 spec 日历视图默认值为月视图
- 移除 `CreateScheduleDialog` 删除按钮

## 补漏：编辑对话框缺删除按钮 (bugfix)

### 现象
编辑日程对话框只有「取消」和「保存」，没有删除按钮。

### 根因
`CreateScheduleDialog` 的 `actions` 区域未根据 `isEditing` 渲染删除按钮，且 `showDialog` 泛型为 `Map<String, dynamic>` 不支持返回 'delete' 信号。

### 修复
- `CreateScheduleDialog`: 编辑模式下 `actions` 区域新增红色「删除」按钮，返回 `'delete'` 字符串
- `HomePage._editSchedule`: 泛型改为 `Object?`，处理 `'delete'` 调用 `_deleteSchedule`
- `CalendarPage._editSchedule`: 同上
