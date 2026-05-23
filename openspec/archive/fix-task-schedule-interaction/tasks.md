# 任务：fix-task-schedule-interaction

## 实施
- [x] 1. HomePage 新增 `_editSchedule` 方法（复用 CreateScheduleDialog isEditing 模式）
- [x] 2. HomePage 日程列表 `onTap` 改为 `_editSchedule`，添加 PopupMenu 编辑/删除
- [x] 3. 日历默认格式改为 `CalendarFormat.week`
- [x] 4. TaskListPage 新增 FAB 新建任务入口
- [x] 5. TaskListPage 的 `_TaskCard` PopupMenu 新增「编辑」选项
- [x] 6. MODIFIED 主 spec：默认视图周视图

## 验证
- [x] 历史 BugFixSpecs 命中的防复发检查项已执行或确认无命中
- [x] 已维护本 change 的回归测试用例
- [x] `flutter test` 通过
- [x] `flutter build windows --release` 通过
- [x] `gitnexus detect-changes --scope all -r smart-assistant`
