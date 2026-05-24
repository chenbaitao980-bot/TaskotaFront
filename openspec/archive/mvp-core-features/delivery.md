# 交付：mvp-core-features

## 完成内容

### 归档（前置）
- ✅ init-project → archive
- ✅ init-smart-butler → archive
- ✅ windows-desktop-build → archive

### MVP 核心功能实现

#### 用户认证（F6）
- ✅ 登录/注册页接入 AuthBloc
- ✅ Supabase Auth 就绪（配置 URL 后自动切换）
- ✅ 本地模拟认证（Supabase 未配置时可用）
- ✅ `main.dart` 根据认证状态展示登录页或首页

#### 日程管理（F1 + F2）
- ✅ 首页 FAB "新建" 按钮 → 弹出 CreateScheduleDialog
- ✅ 首页快捷操作卡片 → 跳转 AI 对话页
- ✅ 首页展示今日日程列表（从本地存储加载）
- ✅ 日历页 SegmentedButton 切换周视图/月视图
- ✅ 日历事件标记点（eventLoader）
- ✅ 日历日期点击展示当日日程
- ✅ 日程 PopupMenu 编辑/删除
- ✅ 本地存储服务（SharedPreferences + JSON）

#### AI 集成（F3）
- ✅ AIService 封装 DeepSeek API（chat + parseSchedule）
- ✅ DeepSeek API Key 已配置：sk-1923fb07640b45b8a0ab564192810321
- ✅ AI 对话页接入真实 API，系统 Prompt 为"日程管家"角色
- ✅ 日程解析：输入自然语言 → DeepSeek 解析 → JSON → 一键导入日历
- ✅ 语音识别集成（speech_to_text），Windows 无语言包时引导文字输入

#### 任务管理
- ✅ create_task_page 保存到本地存储
- ✅ task_detail_page 编辑/删除/状态更新

#### 云端同步调研（F4）
- ✅ 方案对比：Supabase / Firebase / Appwrite / 腾讯云开发
- ✅ 推荐 Supabase（免费额度充足、已在依赖中）

### 基线规范
- ✅ `openspec/project.md`（项目全局约束）
- ✅ `openspec/specs/smart-butler/spec.md`（业务规范）

## 构建验证
- ✅ `flutter analyze`：0 errors（6 info，全部为已有 deprecation 提示）
- ✅ `flutter build windows --release`：成功（65.7s）
- ✅ `gitnexus detect-changes`：17 files, 41 symbols, risk medium，预期范围内

## 新增/修改文件
| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/services/ai_service.dart` | 新增 | DeepSeek API + Prompt 模板 |
| `lib/services/local_storage_service.dart` | 新增 | 本地日程/任务/认证存储 |
| `lib/presentation/widgets/create_schedule_dialog.dart` | 新增 | 新建/编辑日程对话框 |
| `lib/core/constants/app_constants.dart` | 修改 | DeepSeek API Key 配置 |
| `lib/main.dart` | 修改 | AuthBloc 路由 + AiChatBloc |
| `lib/presentation/blocs/auth/*.dart` | 修改 | LocalLogin 事件/状态 |
| `lib/presentation/pages/home/home_page.dart` | 修改 | 完整交互实现 |
| `lib/presentation/pages/calendar/calendar_page.dart` | 修改 | 周/月视图 + CRUD |
| `lib/presentation/pages/ai_chat/ai_chat_page.dart` | 修改 | DeepSeek + 语音 + 解析 |
| `lib/presentation/pages/auth/login_page.dart` | 修改 | 本地认证 |
| `lib/presentation/pages/auth/register_page.dart` | 修改 | 本地认证 |
| `lib/presentation/pages/task/create_task_page.dart` | 修改 | 本地存储 |
| `lib/presentation/pages/task/task_detail_page.dart` | 修改 | 真实数据 |
| `openspec/project.md` | 新增 | 项目基线 |
| `openspec/specs/smart-butler/spec.md` | 新增 | 业务规范基线 |
