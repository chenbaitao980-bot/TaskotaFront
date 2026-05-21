# Delta: init-smart-butler

## 与主规范关系
无冲突。本 change 为项目初始化，建立与 Obsidian 方案一致的代码骨架。

## 变更摘要
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无（初始化） |
| 其他 active change 撞车 | 无 |
| 归档完整性 | ✅ |

## 改动明细

### 1. lib/main.dart
- 位置：全文件重写
- 改前：`flutter create` 生成的默认 Counter App
- 改后：初始化 Supabase + NotificationService + MaterialApp.router

### 2. lib/core/router/app_router.dart（新增）
- 配置 4 个路由：/home, /calendar, /chat, /profile
- 底部导航栏 ShellRoute

### 3. lib/models/*.dart（新增 5 个文件）
- `user_profile.dart`：显式画像 + 隐式画像
- `schedule.dart`：日程表模型
- `task_breakdown.dart`：任务拆解树形结构
- `ai_conversation.dart`：AI 对话历史
- `reminder.dart`：提醒任务

### 4. lib/services/*.dart（新增 3 个文件）
- `supabase_service.dart`：Supabase 客户端单例
- `ai_service.dart`：DeepSeek API HTTP 调用
- `notification_service.dart`：flutter_local_notifications 初始化

### 5. lib/blocs/*/*.dart（新增 4 个 BLoC）
- `auth_bloc.dart`：登录/注册状态
- `schedule_bloc.dart`：日程 CRUD
- `task_bloc.dart`：任务拆解状态
- `chat_bloc.dart`：AI 对话状态

### 6. lib/pages/*.dart（新增 4 个页面）
- `home_page.dart`：仪表盘（今日任务概览）
- `calendar_page.dart`：日历视图（table_calendar）
- `chat_page.dart`：AI 对话界面
- `profile_page.dart`：用户画像设置

### 7. pubspec.yaml
- 补充 `go_router` 依赖
