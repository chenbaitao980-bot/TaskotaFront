# 设计：mvp-core-features

## 当前状态
项目骨架已完成，数据模型、BLoC、页面路由、Supabase Service 封装均已就位。但所有交互逻辑为空实现（`onTap: () {}` 或 `// TODO`），用户在 Windows 上点击按钮无任何响应。

## 方案

### 整体策略
由于 Supabase 后端尚未部署，**本次实现采用"本地优先 + 云端就绪"架构**：
- 所有数据先写入本地存储（SharedPreferences + JSON 文件）
- Supabase 调用包装在 try/catch 中，失败时回退本地
- Supabase URL/Key 配置后即可自动切换到云端同步

### F1: 语音/文字录入日程

**语音录入流程：**
```
用户点击麦克风 → speech_to_text 监听 → 获取识别文本
→ 调用 DeepSeek API 解析（Prompt: "从以下文本提取日程信息..."）
→ 返回结构化 JSON {title, start_time, end_time, priority}
→ 展示确认对话框 → 用户确认 → 写入本地存储
```

**实现细节：**
- `home_page.dart` 的 "语音录入" 卡片 `onTap`：跳转到 AiChatPage 并自动开启语音
- `ai_chat_page.dart` 的麦克风按钮：调用 `speech_to_text` 包进行语音识别
- 文字输入在 AiChatPage 的 TextField 完成，发送后调用 DeepSeek 解析
- 本地存储使用 SharedPreferences 存 JSON 列表

**关于 Windows 语音识别：**
`speech_to_text` 包在 Windows 上支持有限（需要 Windows 10+ 且安装语音语言包）。作为 fallback，当语音不可用时展示提示并引导用户使用文字输入。

### F2: 日历视图（周视图 + 月视图 + CRUD）

**实现细节：**
- 在 CalendarPage 顶部添加 SegmentedButton 切换"月视图"/"周视图"
- 月视图：使用现有 `table_calendar` 的 `CalendarFormat.month`
- 周视图：使用 `table_calendar` 的 `CalendarFormat.week`
- 日程事件从本地存储加载，显示为日历上的标记点
- 点击日期 → 底部弹出该日日程列表
- 长按日期/点击"+" → 弹出 CreateScheduleDialog
- 点击已有日程 → 弹出编辑/删除选项
- 日程修改后刷新日历和本地存储

### F3: AI 任务拆解

**实现细节：**
- 创建 `lib/services/ai_service.dart`，封装 DeepSeek API 调用
- API Key 使用用户提供的 `sk-1923fb07640b45b8a0ab564192810321`
- 在 `ai_chat_page.dart` 中：
  - 用户消息先发送给 DeepSeek
  - 系统 Prompt 设定为"AI 日程管家"角色
  - 支持多轮对话收集信息
  - AI 输出包含结构化任务拆解时，展示"添加到日程"按钮
- AI 响应中的 JSON 任务块可一键导入为 TaskBreakdown

**Prompt 模板：**
```
你是用户的AI日程管家。你的任务是帮助用户拆解大目标为可执行的步骤。

当用户提出目标时：
1. 先询问必要信息（当前水平、可用时间、截止日期等）
2. 然后输出三层拆解：
   - 战略层：季度里程碑
   - 战术层：每月关键交付
   - 执行层：每周具体任务

如果用户只是描述一个日程（如"明天下午3点开会"），直接解析为结构化日程：
{"title": "...", "start_time": "...", "end_time": "...", "priority": "P2"}
```

### F4: 云端同步

**方案研究结论：**

| 方案 | 免费额度 | 适用性 |
|------|---------|--------|
| **Supabase** (方案推荐) | 500MB DB, 2GB 存储, 50k MAU | 已在依赖中，PostgreSQL + Auth + Realtime |
| Firebase | Spark 计划免费 | Google 服务，国内访问受限 |
| Appwrite | 自托管免费 | 需要自己部署服务器 |
| 腾讯云开发 | 免费额度有限 | 国内访问好，但需要实名认证 |

**推荐：Supabase**，原因：
1. 已在项目依赖中（supabase_flutter）
2. 免费额度充足（500MB 数据库对个人日程管理完全够用）
3. 内置 Auth（免去自己实现认证系统）
4. Realtime 支持实时同步
5. 国内访问可通过 Cloudflare Workers 代理加速

**当前实现：**
- Supabase 代码已就绪（SupabaseService 完整封装）
- 本地优先策略确保无网络时也能使用
- Supabase URL/Key 配置后即可启用云端同步

### F6: 用户注册与登录

**实现细节：**
- `login_page.dart`：调用 `SupabaseService.signIn()` → 成功后跳转首页
- `register_page.dart`：调用 `SupabaseService.signUp()` → 创建 user_profile → 跳转首页
- `auth_bloc.dart`：管理认证状态（已登录/未登录/加载中）
- 在 `main.dart` 中根据 AuthBloc 状态决定展示登录页或首页
- Supabase 未配置时：使用本地模拟认证（任意邮箱+密码>=6位即可登录）

### F7: 打包 Win10 桌面应用
已在 `windows-desktop-build` change 完成。本 change 实现功能后重新构建即可。

## 业务规则处理
- 主 spec 的 Requirement：全部命中 smart-butler spec
- 本次处理方式：ADDED（首次实现业务功能）
- 所有新增功能与 smart-butler spec 中定义的 Scenario 一致

## 历史 BugFixSpecs 命中
- 命中文件：无（BugFixSpecs 目录为空，无历史沉淀）

## 回归测试方案
- 用例文件：`regression-tests/cases/mvp-core-features.md`
- 批量测试命令：`flutter analyze` + `flutter build windows --release`
- 入参来源：Flutter 项目编译
- 期望出参：analyze 无 error，build 成功
- 断言规则：exit_code=0

## 回滚方案
通过 git revert 回退本次提交，代码无破坏性改动。
