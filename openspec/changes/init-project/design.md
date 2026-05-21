# 设计：init-project

## 当前状态
- 全新项目，无现有代码
- Flutter 3.41.9已安装
- 需要从零搭建智能小管家项目骨架

## 方案

### 架构选型
采用Clean Architecture + BLoC状态管理：
```
lib/
├── core/           # 核心配置（主题、路由、常量、错误处理）
├── models/         # 数据模型（entities, dto）
├── data/           # 数据层（repositories, datasources）
├── presentation/   # 表现层（pages, blocs, widgets）
├── services/       # 服务层（Supabase, AI API）
└── utils/          # 工具类（extensions, helpers）
```

### 技术栈
- **状态管理**: flutter_bloc + equatable
- **云端同步**: supabase_flutter
- **日历视图**: table_calendar
- **本地存储**: shared_preferences
- **网络请求**: dio
- **JSON序列化**: freezed + json_serializable
- **语音录入**: speech_to_text
- **通知**: flutter_local_notifications
- **UI适配**: flutter_screenutil

### 数据库Schema（PostgreSQL via Supabase）
1. **user_profiles** - 用户档案
2. **schedules** - 日程表
3. **task_breakdowns** - 任务分解表（树形结构）
4. **ai_conversations** - AI对话历史
5. **progress_logs** - 进度追踪表
6. **rewards** - 奖励记录表
7. **reminders** - 提醒任务表

### 主题设计
- 主色调：#6C63FF（紫色）
- 辅助色：#00BFA6（青绿色）
- 支持亮色/暗色模式
- Material 3设计规范

### 路由设计
- / - 首页
- /calendar - 日历视图
- /ai-chat - AI对话
- /profile - 个人中心
- /login - 登录
- /register - 注册
- /create-task - 创建任务
- /task/:id - 任务详情

## 回滚方案
删除smart_assistant目录重新创建即可
