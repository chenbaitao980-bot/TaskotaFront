# 桌面端提醒 + Android 打包 — 实现说明

## 提醒功能

### Schedule 模型扩展
- `schedule.dart`: 添加 `remindBeforeMinutes` (默认15)、`reminderEnabled` (默认true)、`reminderType` ('once'/'repeat')、`isRepeating`、`repeatInterval`
- `app_database.dart` (Task): 添加 `remindBeforeMinutes` (int, required) 和 `reminderEnabled` (int, required)
- `task_breakdown.dart`: 添加 `remindBeforeMinutes` (默认15) 和 `reminderEnabled` (默认true)

### 通知服务
- `notification_service.dart`: 实现 `scheduleReminderForSchedule()` — 支持一次性提醒、开始提醒和重复提醒
- 使用 `flutter_local_notifications` 调起 OS 级通知
- 同时维护 Timer 回退机制

### 提醒配置 UI
- `create_schedule_dialog.dart`: 创建日程时支持设置提醒（开关 + 提前时间选择）
- `tasks/task_detail/task_detail_page.dart` (新版): 编辑任务时支持设置提醒
- `task/task_detail_page.dart` (旧版): 编辑任务时支持设置提醒（本修复新增）

### 数据同步
- `supabase_service.dart`: `remindBeforeMinutes`、`reminderEnabled`、`reminderType` 字段同步到云端
- `task_event.dart`/`task_bloc.dart`: `UpdateTask` 事件含 `remindBeforeMinutes`、`reminderEnabled` 参数
- `task_repository.dart`: 数据库读写含提醒字段

## Android 打包

### 构建配置
- `build_android.bat`: 一键打包脚本（debug/release APK + AppBundle）
- `AndroidManifest.xml`: 通知权限声明
- `pubspec.yaml`: 添加 `flutter_local_notifications` 依赖

### 数据库迁移
- `database/migration_001_init.sql`: `schedules` 表添加 `remind_before_minutes`、`reminder_enabled`、`reminder_type`、`is_repeating`、`repeat_interval` 列
