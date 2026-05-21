# 设计：init-smart-butler

## 当前状态
- Flutter 3.x 项目骨架已创建（`flutter create smart_assistant`）
- `pubspec.yaml` 已预配核心依赖：flutter_bloc, supabase_flutter, table_calendar, speech_to_text, dio, flutter_local_notifications 等
- 已有空文件：`lib/main.dart`, `lib/core/constants/app_constants.dart`, `lib/core/theme/app_theme.dart`
- 缺少：模型层、服务层、状态管理层、页面层、路由层

## 方案

### 目录结构（Clean Architecture 简化版）
```
lib/
├── main.dart                    # 入口，初始化 Supabase + 通知
├── core/
│   ├── constants/
│   │   └── app_constants.dart   # 常量、枚举
│   ├── theme/
│   │   └── app_theme.dart       # Material 3 主题
│   └── router/
│       └── app_router.dart      # GoRouter 配置
├── models/                      # 数据模型（freezed + json_serializable）
│   ├── user_profile.dart
│   ├── schedule.dart
│   ├── task_breakdown.dart
│   ├── ai_conversation.dart
│   └── reminder.dart
├── services/                    # 业务服务层
│   ├── supabase_service.dart    # Supabase 客户端封装
│   ├── ai_service.dart          # DeepSeek API 调用
│   └── notification_service.dart # 本地通知管理
├── blocs/                       # BLoC 状态管理
│   ├── auth/
│   ├── schedule/
│   ├── task/
│   └── chat/
├── pages/                       # 页面
│   ├── home_page.dart
│   ├── calendar_page.dart
│   ├── chat_page.dart
│   └── profile_page.dart
└── widgets/                     # 可复用组件
    ├── calendar_widget.dart
    ├── task_card.dart
    └── chat_bubble.dart
```

### 技术决策
1. **路由**：`go_router`（声明式，与 Flutter 官方推荐一致）
2. **状态管理**：`flutter_bloc`（已在 pubspec.yaml 中）
3. **模型序列化**：`freezed` + `json_serializable`（已在 dev_dependencies）
4. **依赖注入**：手动 Provider（不引入 get_it，减少复杂度）
5. **AI 调用**：先写 AIService 封装，API Key 从环境变量读取

### 回滚方案
删除 `lib/` 下除 `main.dart` 外的所有新增目录和文件，恢复 `main.dart` 原始内容。
