# mvp-core-features

## 为什么
当前项目骨架已完成（init-project + init-smart-butler），但所有交互功能均为 TODO 占位符。用户在 Windows 上点击任何按钮都没有响应。本 change 按照 Obsidian「智能小管家」方案实现 MVP 全部 6 项核心功能。

## 影响面
- 修改文件：约 10 个现有 Dart 文件（补全 TODO 实现）
- 新增文件：约 3-5 个（AI Service、本地存储 Service、新增 Widget）
- 涉及模块：HomePage, CalendarPage, AiChatPage, LoginPage, RegisterPage, CreateTaskPage
- 涉及 BLoC：AuthBloc, ScheduleBloc, TaskBloc
- 涉及配置：app_constants.dart（写入 DeepSeek API Key）

## 业务规范关系
- 命中的主 spec：`smart-butler/spec.md`（本 change 建立基线 spec）
- 关系判断：New Capability（首次实现业务功能，与基线 spec 一致）
- 推荐动作：ADDED（主 spec 为本 change 新建，行为与 spec 一致）

## 改动范围

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/main.dart` | 修改 | 初始化本地存储，注册 AiChatBloc |
| `lib/core/constants/app_constants.dart` | 修改 | 写入 DeepSeek API Key |
| `lib/presentation/pages/home/home_page.dart` | 修改 | 补全 FAB + 快捷操作卡片 onTap |
| `lib/presentation/pages/calendar/calendar_page.dart` | 修改 | 新增周视图，真实 CRUD |
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 修改 | 接入 DeepSeek API，替换假响应 |
| `lib/presentation/pages/auth/login_page.dart` | 修改 | 补全 Supabase Auth 登录 |
| `lib/presentation/pages/auth/register_page.dart` | 修改 | 补全 Supabase Auth 注册 |
| `lib/presentation/pages/task/create_task_page.dart` | 修改 | 补全本地存储保存 |
| `lib/presentation/pages/task/task_detail_page.dart` | 修改 | 补全编辑/删除 |
| `lib/presentation/blocs/schedule/schedule_bloc.dart` | 修改 | 支持本地存储 fallback |
| `lib/services/ai_service.dart` | 新增 | DeepSeek API HTTP 调用 |
| `lib/services/local_storage_service.dart` | 新增 | 本地日程/任务存储（无网络可用） |
| `lib/presentation/widgets/create_schedule_dialog.dart` | 新增 | 新建/编辑日程对话框 |
| `lib/presentation/widgets/week_view.dart` | 新增 | 周视图组件 |

## 验收
- [ ] 语音录入按钮可触发系统麦克风并识别文本
- [ ] 文字录入可解析自然语言为结构化日程
- [x] 日历支持月视图和周视图切换
- [x] 日历支持新建、编辑、删除日程
- [x] AI 聊天可调用 DeepSeek API 进行任务拆解
- [x] DeepSeek API Key 已配置（sk-1923fb07640b45b8a0ab564192810321）
- [x] 用户可通过邮箱+密码注册和登录
- [x] 未登录用户无法访问功能页
- [ ] 无网络时日程数据保存在本地
- [ ] 已维护 `regression-tests/cases/mvp-core-features.md`
- [ ] `flutter analyze` 无 error
- [ ] `flutter build windows --release` 成功
- [ ] `gitnexus detect-changes` 无异常范围外变更

## Bug 修复记录
无（本 change 为新增功能，非 bugfix）
