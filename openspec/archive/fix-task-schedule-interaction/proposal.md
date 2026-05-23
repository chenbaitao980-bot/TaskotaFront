# fix-task-schedule-interaction

## 为什么
用户操作入口存在三个交互缺陷：
1. 首页「今日日程」列表点击议程卡直接跳转新建日程对话框，无法编辑已有日程
2. 日历页面默认展示月视图，用户期望默认展示周视图
3. 任务列表页缺少新建任务入口和编辑任务的快捷操作

## 影响面
GitNexus impact（预估）:
- `_buildRecentSchedules` / `_HomeContent`: LOW risk，仅 UI 导航入口变更
- `_CalendarPageState`: LOW risk，仅初始值修改
- `TaskListPage` / `_TaskCard`: LOW risk，新增菜单项和 FAB
- BugFixSpecs: `auth/register-click-no-response.md` 与本 change 无关（认证域），未命中

## 业务规范关系
- 主 spec：`openspec/specs/smart-butler/spec.md`
- 命中的 Requirement：
  - Calendar view → Scenario: 查看月视图/周视图 → **Behavior Override**（默认周视图取代月视图）
  - Calendar view → Scenario: 编辑/删除日程 → **Spec Gap**（首页日程列表缺少编辑入口）
  - AI task breakdown → **Spec Gap**（任务列表缺少新建和编辑入口）
- 处理方式：MODIFIED（日历默认视图）+ 不改 spec 只修代码（任务/日程入口为 spec 未覆盖的 UI 细节）

## 改动范围
| 文件 | 改动类型 |
|------|---------|
| `lib/presentation/pages/home/home_page.dart` | 修改：日程列表 onTap 改为编辑入口，新增 `_editSchedule` 方法 |
| `lib/presentation/pages/calendar/calendar_page.dart` | 修改：默认日历格式改为 `CalendarFormat.week` |
| `lib/presentation/pages/task/task_list_page.dart` | 修改：PopupMenu 新增编辑选项，新增 FAB 新建任务入口 |
| `openspec/specs/smart-butler/spec.md` | MODIFIED：默认视图从月视图改为周视图 |

## 验收
- [x] 首页今日日程列表点击已有日程弹出编辑对话框（可修改标题、时间、优先级）
- [x] 日历 Tab 默认展示周视图
- [x] 任务列表页有新建任务 FAB 按钮
- [x] 任务列表页的 PopupMenu 包含「编辑」选项
- [x] 已维护 `regression-tests/cases/fix-task-schedule-interaction.md`
- [x] `flutter test` 通过
- [x] `flutter build windows --release` 通过
- [x] `gitnexus detect-changes --scope all -r smart-assistant`

## Bug 修复记录

| bug_id | 现象 | 首次发现时间 | bugfix_count | 当前状态 |
|---|---|---|---:|---|
| schedule-edit-no-delete | 编辑日程对话框缺少删除按钮 | 2026-05-23 | 1 | open |

## Bug 触发历史
- 第 1 次：用户反馈编辑对话框只有取消和保存，无删除按钮。根因：`CreateScheduleDialog` actions 区域未根据 `isEditing` 渲染删除按钮。

## 历史 BugFixSpecs 命中
- 命中文件：无
