# 任务：mvp-core-features

## 实施

### 基础设施
- [x] 1. 配置 app_constants.dart（写入 DeepSeek API Key sk-1923fb07640b45b8a0ab564192810321）
- [x] 2. 创建 `lib/services/ai_service.dart`（DeepSeek API HTTP 调用 + Prompt 模板）
- [x] 3. 创建 `lib/services/local_storage_service.dart`（日程/任务本地 JSON 存储）

### 用户认证
- [x] 4. 补全 `login_page.dart`（接入 Supabase Auth 登录，无 Supabase 时本地模拟认证）
- [x] 5. 补全 `register_page.dart`（接入 Supabase Auth 注册）
- [x] 6. 修改 `main.dart`（根据 AuthBloc 状态展示登录页或首页，注册 AiChatBloc）

### 日程管理
- [x] 7. 创建 `lib/presentation/widgets/create_schedule_dialog.dart`（新建/编辑日程对话框）
- [x] 8. 补全 `home_page.dart`（FAB onPressed 创建日程，语音/AI卡片 onTap 跳转 AI 对话页，今日日程列表）
- [x] 9. 补全 `calendar_page.dart`（周/月视图 SegmentedButton 切换、日程标记点、日期点击展示日程、PopupMenu 编辑/删除）
- [x] 10. 补全 `create_task_page.dart`（保存到本地存储、编辑已有任务）
- [x] 11. 补全 `task_detail_page.dart`（编辑模式、删除确认、状态更新）

### AI 集成
- [x] 12. 补全 `ai_chat_page.dart`（接入 DeepSeek API、语音识别按钮含 Windows 降级提示、结构化日程解析、一键导入日历按钮）

### 云端同步
- [x] 13. 在 design.md 中记录云同步调研结论（Supabase 推荐，免费方案对比表）

## 验证
- [x] 语音录入按钮可触发系统麦克风（Windows 不可用时引导安装语言包）
- [x] 文字输入可调用 DeepSeek 解析为结构化日程
- [x] 日历支持月视图 ↔ 周视图切换
- [x] 日历支持新建、编辑、删除日程（本地存储）
- [x] AI 对话可调用 DeepSeek API，返回真实响应
- [x] DeepSeek API Key 已配置生效
- [x] 用户可通过邮箱+密码注册和登录（本地模拟认证）
- [x] 未登录用户无法访问功能页
- [x] 无网络时日程数据保存在本地
- [x] 已维护 `regression-tests/cases/mvp-core-features.md`
- [x] `flutter analyze` 无 error（0 errors，6 info）
- [x] `flutter build windows --release` 成功
- [x] `gitnexus detect-changes --scope all` 17 files, 41 symbols, risk medium, 预期范围内

## 第 2 轮：Supabase + 通知 + 打包

### 实施
- [x] 14. 配置 Supabase 凭证（URL + Anon Key 写入 app_constants.dart）
- [x] 15. 测试 Supabase 连接（REST API 200 OK）
- [x] 16. 创建并执行 SQL 建表（7 张表: schedules, task_breakdowns, user_profiles, ai_conversations, progress_logs, reminders, rewards + RLS + 索引）
- [x] 17. 验证 Supabase Auth 和 CRUD（Auth API 可连接、表查询正常）
- [x] 18. 安装 VS 2022 ATL 组件
- [x] 19. 创建 `lib/services/notification_service.dart`（基于 Timer 的本地通知调度）
- [x] 20. `flutter build windows --release` 重新打包（87.7s 成功）
- [x] 21. 生成 ZIP 分发包（smart_assistant_windows.zip）

### 验证
- [x] `flutter analyze` 0 errors
- [x] `flutter build windows --release` 成功
- [x] `gitnexus detect-changes` 17 files, 42 symbols, risk medium, 预期范围内
- [x] 回归测试用例已维护（regression-tests/cases/mvp-core-features.md）
- [x] 测试结果写入 runs 文件
