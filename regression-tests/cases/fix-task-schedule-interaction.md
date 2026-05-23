# Regression Cases: fix-task-schedule-interaction

## Batch Test Endpoint
- command_or_url: flutter test + flutter build windows --release
- auth: N/A
- env: local

## Cases
| case_id | 目标 | 入参摘要 | 期望出参关键字段 | 断言 | 来源 | 状态 |
|---|---|---|---|---|---|---|
| home-schedule-edit-tap | 首页今日日程列表点击弹出编辑对话框 | 已有日程数据 | 编辑对话框弹出，初始值为日程当前值 | equals | user | pending |
| calendar-default-week | 切换到日历Tab默认展示周视图 | 打开日历Tab | CalendarFormat.week | equals | spec | pending |
| tasklist-fab-create | 任务列表页有新建任务FAB按钮 | 进入任意状态的任务列表 | 显示+按钮 | exists | user | pending |
| tasklist-popup-edit | 任务列表卡片弹出菜单含编辑选项 | 点击任务卡片三点菜单 | 菜单显示「编辑」选项 | exists | user | pending |

## Notes
- 手动验证路径：启动 app → 首页日程列表点击 → 应弹出编辑对话框
- 日历Tab → 默认展示周视图（时间格子）
- 点击首页待办/进行中/已完成 → 进入任务列表 → 右下角有 + 按钮
- 任务列表三点菜单 → 含编辑选项
