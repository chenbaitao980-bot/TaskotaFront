# init-smart-butler

## 为什么
按照 Obsidian 中「智能小管家」最终版方案，搭建 AI 智能日程管家项目的完整骨架。现有 Flutter 骨架（`flutter create` 生成 + 依赖预配）需要补全：
1. 核心目录结构（models / services / blocs / pages / widgets）
2. 数据库模型与 Supabase 集成
3. 路由与主题系统
4. AI 任务拆解核心流程
5. 日历视图与日程 CRUD

## 影响面
- 新增文件：约 15-20 个 Dart 文件
- 修改文件：`main.dart`, `pubspec.yaml`（补充 dev deps）
- 无删除操作
- 不影响现有 `android/`, `ios/`, `windows/` 平台目录

## 改动范围
| 文件 | 操作 |
|------|------|
| `lib/main.dart` | 修改：接入路由 + BlocProvider |
| `lib/core/router/app_router.dart` | 新增：GoRouter 路由配置 |
| `lib/core/constants/app_constants.dart` | 修改：补充常量 |
| `lib/core/theme/app_theme.dart` | 修改：完善主题 |
| `lib/models/*.dart` | 新增：UserProfile, Schedule, TaskBreakdown 等 |
| `lib/services/*.dart` | 新增：SupabaseService, AIService, NotificationService |
| `lib/blocs/*.dart` | 新增：ScheduleBloc, TaskBloc, AuthBloc |
| `lib/pages/*.dart` | 新增：HomePage, CalendarPage, ChatPage, ProfilePage |
| `lib/widgets/*.dart` | 新增：CalendarWidget, TaskCard, ChatBubble |
| `pubspec.yaml` | 修改：补充 go_router, freezed 等 |

## 验收
- [x] `flutter analyze` 无错误
- [x] 项目可在 Windows Desktop 运行
- [x] 目录结构符合方案设计
- [x] 核心模型类可编译通过
