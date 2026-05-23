# BugFix Log: fix-task-schedule-interaction

## Bug Index

| bug_id | 现象 | 关联文件/函数 | bugfix_count | 当前状态 | 是否需沉淀 |
|---|---|---|---|---|---:|---|
| schedule-edit-no-delete | 编辑日程对话框缺少删除按钮和状态修改 | `create_schedule_dialog.dart` / `_editSchedule` (HomePage+CalendarPage) | 1 | open | 否 |

## Bug Events

### schedule-edit-no-delete / 第 1 次修复

- 触发时间：2026-05-23
- 用户现象：编辑日程对话框只有取消和保存，没有删除按钮
- 复现路径：首页或日历中点击已有日程→弹出编辑对话框→actions 区域无删除按钮
- 触发条件：`isEditing=true`
- 失败验证：对话框 actions 列表只有 TextButton(取消) + FilledButton(保存)
- 本轮根因假设：`CreateScheduleDialog` 未区分编辑/新建模式的 actions 渲染
- 最终根因：`actions` 区域未根据 `widget.isEditing` 条件渲染删除按钮；`showDialog` 泛型为 `Map<String, dynamic>` 导致无法传递字符串信号 'delete'
- 修复点：
  - `lib/presentation/widgets/create_schedule_dialog.dart`: actions 中新增条件渲染的删除按钮
  - `lib/presentation/pages/home/home_page.dart`: `_editSchedule` 泛型→`Object?`，处理 delete
  - `lib/presentation/pages/calendar/calendar_page.dart`: `_editSchedule` 同上
- 验证结果：`flutter analyze` 0 errors
- 是否同一 bug：是，第 1 次
