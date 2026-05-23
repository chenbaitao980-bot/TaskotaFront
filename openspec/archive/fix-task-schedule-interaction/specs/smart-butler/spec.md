# Delta: fix-task-schedule-interaction

## 与主规范关系
- 日历默认视图：Behavior Override → MODIFIED
- 首页日程编辑入口：Spec Gap → 不改 spec，补全 UI
- 任务列表新建/编辑：Spec Gap → 不改 spec，补全 UI

## 命中的主规范
- Capability: `smart-butler`
- Requirement: Calendar view
- Scenario: 查看月视图 → 查看周视图

## 变更类型
MODIFIED: 日历视图 Scene 默认行为

## 业务冲突检查
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | Calendar view |
| 关系判断 | Behavior Override（日历默认视图） + Spec Gap（日程/任务编辑入口） |
| 其他 active change 撞车 | task-status-and-week-timeline（已完成，本 change 在其基础上修改） |
| 冲突状态 | 无冲突 |
| 是否允许 ADDED | 否（MODIFIED，非新能力） |
| 归档完整性 | Pending |

## 原规则
```markdown
#### Scenario: 查看月视图
- WHEN 用户切换到日历Tab
- THEN 默认展示月视图
```

## 新规则
```markdown
#### Scenario: 查看周视图
- WHEN 用户切换到日历Tab
- THEN 默认展示周视图
- AND 显示该周每天的时间格子
- AND 日程以时间块形式展示
- AND 自动滚动到当前时间位置

#### Scenario: 切换到月视图
- WHEN 用户点击月视图切换按钮
- THEN 日历切换为月视图
- AND 有日程的日期显示圆点标记
- AND 点击日期展示当日日程列表
```

## 改动明细
- 文件：`lib/presentation/pages/calendar/calendar_page.dart`
  - 位置：第 26 行
  - 改前：`_calendarFormat = CalendarFormat.month`
  - 改后：`_calendarFormat = CalendarFormat.week`

- 文件：`lib/presentation/pages/home/home_page.dart`
  - 位置：`_buildRecentSchedules()` 方法
  - 改前：日程列表 `onTap` 直接调用 `_createSchedule`（新建）
  - 改后：日程列表 `onTap` 调用 `_editSchedule`（编辑），新增 PopupMenu 编辑/删除

- 文件：`lib/presentation/pages/task/task_list_page.dart`
  - 改前：无新建任务入口，PopupMenu 无编辑选项
  - 改后：新增 FAB 新建任务，PopupMenu 新增编辑选项

- 文件：`openspec/specs/smart-butler/spec.md`
  - MODIFIED：日历默认视图从月视图改为周视图
