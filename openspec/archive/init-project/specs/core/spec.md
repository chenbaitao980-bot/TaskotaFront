# Delta: init-project

## 与主规范关系
无冲突 - 全新项目初始化

## 变更摘要
| 维度 | 状态 |
|------|------|
| 主规范 Req 命中 | 无（新项目） |
| 其他 active change 撞车 | 无 |
| 归档完整性 | ✅ |

## 改动明细

### 文件：pubspec.yaml
- 位置：全文件重写
- 改前：Flutter默认生成的pubspec.yaml
- 改后：添加智能小管家所需依赖

### 文件：lib/main.dart
- 位置：全文件重写
- 改前：Flutter默认计数器Demo
- 改后：应用入口，初始化Supabase和BlocProvider

### 文件：lib/core/theme/app_theme.dart
- 位置：新建
- 内容：定义AppTheme类，包含亮色/暗色主题配置

### 文件：lib/core/router/app_router.dart
- 位置：新建
- 内容：定义AppRouter类，包含所有路由配置

### 文件：lib/core/constants/app_constants.dart
- 位置：新建
- 内容：定义应用常量（Supabase配置、API配置、优先级等）

### 文件：lib/models/entities/schedule.dart
- 位置：新建
- 内容：Schedule模型定义（freezed）

### 文件：lib/models/entities/task_breakdown.dart
- 位置：新建
- 内容：TaskBreakdown模型定义（freezed）

### 文件：lib/models/entities/user_profile.dart
- 位置：新建
- 内容：UserProfile模型定义（freezed）

### 文件：lib/models/entities/ai_conversation.dart
- 位置：新建
- 内容：AiConversation模型定义（freezed）

### 文件：lib/services/supabase_service.dart
- 位置：新建
- 内容：Supabase服务封装（认证、Schedule、Task操作）
